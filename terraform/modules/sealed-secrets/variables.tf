variable "chart_version" {
  description = "Sealed Secrets Helm chart version."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install sealed-secrets into."
  type        = string
}
