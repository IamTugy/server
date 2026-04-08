variable "chart_version" {
  description = "cert-manager Helm chart version."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install cert-manager into."
  type        = string
}
