variable "cluster_name" {
  description = "k3d cluster name."
  type        = string
}

variable "k3s_image" {
  description = "k3s container image tag."
  type        = string
}

variable "server_count" {
  description = "Number of server (control-plane) nodes."
  type        = number
}

variable "agent_count" {
  description = "Number of agent (worker) nodes."
  type        = number
}

variable "http_host_port" {
  description = "Host port mapped to container port 80."
  type        = number
}

variable "https_host_port" {
  description = "Host port mapped to container port 443."
  type        = number
}

variable "api_host" {
  description = "Hostname written into the kubeconfig server URL. Use Tailscale hostname for remote access."
  type        = string
  default     = "localhost"
}

variable "api_port" {
  description = "Host port for the k8s API server."
  type        = number
  default     = 6443
}
