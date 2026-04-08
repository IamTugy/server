resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 900 # Large chart with many CRDs — give it time

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      grafana_admin_password = var.grafana_admin_password
      namespace              = var.namespace
    })
  ]
}
