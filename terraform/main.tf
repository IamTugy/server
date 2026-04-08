# ── Cluster ──────────────────────────────────────────────────────────────────

module "cluster" {
  source = "./modules/cluster"

  cluster_name    = var.cluster_name
  k3s_image       = var.k3s_image
  server_count    = var.server_count
  agent_count     = var.agent_count
  http_host_port  = var.http_host_port
  https_host_port = var.https_host_port
  api_host        = var.tailscale_hostname
  api_port        = var.k8s_api_port
}

# Export kubeconfig to disk after the cluster is created.
# The Helm and Kubernetes providers read from this fixed path.
# File permissions are set to 0600 (owner-read-only).
resource "terraform_data" "export_kubeconfig" {
  triggers_replace = [module.cluster.cluster_name]

  provisioner "local-exec" {
    command = <<-EOT
      k3d kubeconfig get ${module.cluster.cluster_name} > ${path.module}/kubeconfig/local.yaml
      chmod 600 ${path.module}/kubeconfig/local.yaml
      sed "s|https://0.0.0.0:${var.k8s_api_port}|https://${var.tailscale_hostname}:${var.k8s_api_port}|g" \
        ${path.module}/kubeconfig/local.yaml > ${path.module}/kubeconfig/remote.yaml
      chmod 600 ${path.module}/kubeconfig/remote.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/kubeconfig/local.yaml ${path.module}/kubeconfig/remote.yaml"
  }

  depends_on = [module.cluster]
}

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  depends_on = [terraform_data.export_kubeconfig]
}

resource "kubernetes_namespace_v1" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  depends_on = [terraform_data.export_kubeconfig]
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  depends_on = [terraform_data.export_kubeconfig]
}

# ── Helm Releases (ordered via depends_on) ───────────────────────────────────

# Monitoring installs the ServiceMonitor CRD — must come before cert-manager and sealed-secrets
module "monitoring" {
  source = "./modules/monitoring"

  chart_version          = var.kube_prometheus_stack_chart_version
  namespace              = kubernetes_namespace_v1.monitoring.metadata[0].name
  grafana_admin_password = var.grafana_admin_password

  depends_on = [kubernetes_namespace_v1.monitoring]
}

module "cert_manager" {
  source = "./modules/cert-manager"

  chart_version = var.cert_manager_chart_version
  namespace     = kubernetes_namespace_v1.cert_manager.metadata[0].name

  depends_on = [
    kubernetes_namespace_v1.cert_manager,
    module.monitoring,
  ]
}

module "sealed_secrets" {
  source = "./modules/sealed-secrets"

  chart_version = var.sealed_secrets_chart_version
  namespace     = kubernetes_namespace_v1.sealed_secrets.metadata[0].name

  depends_on = [
    kubernetes_namespace_v1.sealed_secrets,
    module.monitoring,
  ]
}
