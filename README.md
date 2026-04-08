# server — Local Kubernetes IaC

Fully reproducible local Kubernetes cluster managed with **Terraform + k3d**.
All tool versions are pinned via **mise**.

## Stack

| Component | Version | Notes |
|-----------|---------|-------|
| k3s | v1.33.6-k3s1 | Pinned image |
| Traefik | built-in k3s | Ingress controller |
| cert-manager | 1.20.1 | TLS certificate management |
| Sealed Secrets | 2.18.4 | GitOps-safe secret encryption |
| kube-prometheus-stack | 82.15.1 | Prometheus + Grafana |

## Prerequisites

- Docker Desktop or OrbStack running
- [mise](https://mise.jdx.dev) — `brew install mise`
- kubeseal — `brew install kubeseal`
- k3d — `brew install k3d` (or already installed)
- kubectl

## Quick Start

```bash
# 1. Install pinned tools (terraform, helm)
mise install

# 2. Create your tfvars from the example
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars — at minimum set grafana_admin_password

# 3. Create cluster + install all services (~10-15 min first run)
make apply

# 4. Set KUBECONFIG in your shell
eval "$(make kubeconfig)"

# 5. Verify everything is healthy
make verify
```

## Teardown and Re-creation

```bash
# Backup the sealed-secrets master key before destroying
make backup-sealing-key
# Store /tmp/sealed-secrets-master-key-BACKUP.yaml in 1Password

make destroy
make apply

# Restore the key so existing SealedSecrets still work
make restore-sealing-key KEY_FILE=/tmp/sealed-secrets-master-key-BACKUP.yaml
```

## Sealing a Secret

```bash
# Create a plain secret (never commit this)
kubectl create secret generic my-secret \
  --from-literal=password=hunter2 \
  --dry-run=client -o yaml > /tmp/plain.yaml

# Seal it (cluster must be running)
make seal-secret NS=default NAME=my-secret FILE=/tmp/plain.yaml

# k8s/sealed-secrets/my-secret-sealed.yaml is safe to commit
git add k8s/sealed-secrets/my-secret-sealed.yaml
```

## Accessing Services

**Grafana**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000
# Login: admin / <your grafana_admin_password>
```

Or via Traefik ingress (add `127.0.0.1 grafana.local.dev` to `/etc/hosts`):
```
http://grafana.local.dev:8080
```

**Prometheus**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
open http://localhost:9090
```

## Ports

| Host Port | Service |
|-----------|---------|
| 8080 | HTTP (Traefik) |
| 8443 | HTTPS (Traefik) |

## Make Targets

```
make help          # list all targets
make prereqs       # check tools
make init          # terraform init
make plan          # terraform plan
make apply         # create cluster + install services
make destroy       # full teardown
make kubeconfig    # print KUBECONFIG export
make verify        # health checks
make seal-secret   # seal a secret for git
make backup-sealing-key   # export sealed-secrets master key
make restore-sealing-key  # restore sealed-secrets master key
```

## Security Notes

- `terraform.tfvars` and `terraform.tfstate` are gitignored — never committed
- `terraform/kubeconfig/local.yaml` is gitignored — written with `chmod 600`
- Only encrypted `SealedSecret` CRs are committed to `k8s/sealed-secrets/`
- NetworkPolicies in `k8s/network-policies/` apply default-deny per namespace
- RBAC is enabled by default in k3s
