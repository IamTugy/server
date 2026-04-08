resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_version
  namespace  = var.namespace

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "prometheus.enabled"
      value = "true"
    },
    {
      name  = "prometheus.servicemonitor.enabled"
      value = "true"
    },
    {
      name  = "prometheus.servicemonitor.namespace"
      value = "monitoring"
    },
    {
      name  = "global.leaderElection.namespace"
      value = var.namespace
    },
  ]
}
