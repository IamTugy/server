variable "cluster_name" {
  description = "Name of the k3d cluster. The kubectl context will be k3d-<name>."
  type        = string
  default     = "local"
}

variable "k3s_image" {
  description = "k3s container image. Pinned for reproducibility."
  type        = string
  default     = "rancher/k3s:v1.33.6-k3s1"
}

variable "server_count" {
  description = "Number of k3s server (control-plane) nodes."
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "Number of k3s agent (worker) nodes."
  type        = number
  default     = 2
}

variable "tailscale_hostname" {
  description = "Tailscale hostname of this machine (e.g. my-host.tailXXXXX.ts.net). Written into the remote kubeconfig."
  type        = string
}

variable "k8s_api_port" {
  description = "Host port for the k8s API server. Must be open on the Tailscale interface."
  type        = number
  default     = 6443
}

variable "http_host_port" {
  description = "Host port mapped to the cluster's port 80 (HTTP). Must be free on the host."
  type        = number
  default     = 8080
}

variable "https_host_port" {
  description = "Host port mapped to the cluster's port 443 (HTTPS). Must be free on the host."
  type        = number
  default     = 8443
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version."
  type        = string
  default     = "1.20.1"
}

variable "sealed_secrets_chart_version" {
  description = "Sealed Secrets Helm chart version."
  type        = string
  default     = "2.18.4"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "82.15.1"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Set via terraform.tfvars (gitignored) or TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
}
