variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install monitoring into."
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  type        = string
  sensitive   = true
}
