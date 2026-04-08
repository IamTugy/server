SHELL  := /bin/bash
TF_DIR := terraform

.PHONY: help prereqs init plan apply destroy kubeconfig verify deploy \
        seal-secret backup-sealing-key restore-sealing-key clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

prereqs: ## Check all required tools are installed and Docker is running
	@command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform not found — run: mise install"; exit 1; }
	@command -v helm      >/dev/null 2>&1 || { echo "ERROR: helm not found — run: mise install"; exit 1; }
	@command -v k3d       >/dev/null 2>&1 || { echo "ERROR: k3d not found — run: brew install k3d"; exit 1; }
	@command -v kubectl   >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
	@command -v kubeseal  >/dev/null 2>&1 || { echo "ERROR: kubeseal not found — run: brew install kubeseal"; exit 1; }
	@docker info >/dev/null 2>&1          || { echo "ERROR: Docker daemon not running"; exit 1; }
	@[ -f $(TF_DIR)/terraform.tfvars ] || { \
	  echo "ERROR: terraform/terraform.tfvars not found."; \
	  echo "       Run: cp terraform/terraform.tfvars.example terraform/terraform.tfvars"; \
	  echo "       Then edit it and set grafana_admin_password."; \
	  exit 1; \
	}
	@echo "All prerequisites satisfied."

init: prereqs ## terraform init — download providers and modules
	cd $(TF_DIR) && terraform init -upgrade

plan: init ## terraform plan — preview changes
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: init ## Create/update cluster and install all services (two-phase apply)
	@echo "==> Phase 1: create k3d cluster and export kubeconfig..."
	cd $(TF_DIR) && terraform apply \
	  -target=module.cluster \
	  -target=terraform_data.export_kubeconfig \
	  -auto-approve
	@echo "==> Phase 2: install Helm charts..."
	cd $(TF_DIR) && terraform apply -auto-approve
	@echo ""
	@echo "==> Done. Run 'make kubeconfig' to print the KUBECONFIG export command."

destroy: ## Tear down all resources and remove kubeconfig
	cd $(TF_DIR) && terraform destroy -auto-approve
	rm -f $(TF_DIR)/kubeconfig/local.yaml
	@echo "Cluster destroyed and kubeconfig removed."

kubeconfig: ## Print the KUBECONFIG export command
	@KUBE_PATH=$$(cd $(TF_DIR) && terraform output -raw kubeconfig_path 2>/dev/null); \
	if [ -z "$$KUBE_PATH" ]; then \
	  echo "WARNING: cluster not yet applied — kubeconfig_path unavailable."; \
	else \
	  echo "export KUBECONFIG=$$KUBE_PATH"; \
	fi

verify: ## Run post-apply health checks
	@bash scripts/verify.sh

deploy: ## Apply all k8s manifests (namespaces, network-policies, infra, apps)
	@KUBE_PATH=$$(cd $(TF_DIR) && terraform output -raw kubeconfig_path 2>/dev/null); \
	[ -n "$$KUBE_PATH" ] || { echo "ERROR: cluster not running — run: make apply"; exit 1; }; \
	KUBECONFIG=$$KUBE_PATH kubectl apply -f k8s/namespaces/ && \
	KUBECONFIG=$$KUBE_PATH kubectl apply -f k8s/network-policies/ && \
	KUBECONFIG=$$KUBE_PATH kubectl apply -f k8s/infra/ --recursive && \
	KUBECONFIG=$$KUBE_PATH kubectl apply -f k8s/apps/ --recursive
	@echo "Deploy complete."

seal-secret: ## Seal a secret: make seal-secret NS=<ns> NAME=<name> FILE=<plain-secret.yaml>
	@[ -n "$(NS)" ] && [ -n "$(NAME)" ] && [ -n "$(FILE)" ] || { \
	  echo "Usage: make seal-secret NS=<namespace> NAME=<name> FILE=<plain-secret.yaml>"; \
	  exit 1; \
	}
	kubeseal \
	  --controller-namespace sealed-secrets \
	  --controller-name   sealed-secrets-controller \
	  --format yaml \
	  < $(FILE) > k8s/sealed-secrets/$(NAME)-sealed.yaml
	@echo "Sealed secret written to k8s/sealed-secrets/$(NAME)-sealed.yaml"
	@echo "This file is safe to commit."

backup-sealing-key: ## Export the sealed-secrets master key to /tmp (store in a password manager, NOT git)
	kubectl get secret -n sealed-secrets \
	  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
	  -o yaml > /tmp/sealed-secrets-master-key-BACKUP.yaml
	@echo "Key written to /tmp/sealed-secrets-master-key-BACKUP.yaml"
	@echo "IMPORTANT: Store this in 1Password or a vault. Never commit it."

restore-sealing-key: ## Restore sealing key after cluster recreation: make restore-sealing-key KEY_FILE=<path>
	@[ -n "$(KEY_FILE)" ] || { echo "Usage: make restore-sealing-key KEY_FILE=<path>"; exit 1; }
	kubectl apply -f $(KEY_FILE) -n sealed-secrets
	kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets
	@echo "Sealing key restored. Existing SealedSecrets can be decrypted again."

clean: ## Remove local Terraform cache (does not destroy the cluster)
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/tfplan
