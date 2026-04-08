resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = var.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 300

  set = [
    {
      name  = "fullnameOverride"
      value = "sealed-secrets-controller"
    },
    {
      name  = "rbac.create"
      value = "true"
    },
    {
      name  = "metrics.serviceMonitor.enabled"
      value = "true"
    },
    {
      name  = "metrics.serviceMonitor.namespace"
      value = "monitoring"
    },
  ]
}
