output "kubeconfig_path" {
  description = "Absolute path to the written kubeconfig file."
  value       = abspath("${path.module}/kubeconfig/local.yaml")
}

output "cluster_name" {
  description = "k3d cluster name."
  value       = module.cluster.cluster_name
}

output "kubectl_context" {
  description = "kubectl context name for --context flag."
  value       = "k3d-${var.cluster_name}"
}

output "traefik_http_port" {
  description = "Host port for HTTP traffic into the cluster via Traefik."
  value       = var.http_host_port
}

output "traefik_https_port" {
  description = "Host port for HTTPS traffic into the cluster via Traefik."
  value       = var.https_host_port
}

output "grafana_ingress_url" {
  description = "Grafana URL via Traefik ingress (add 'grafana.local.dev' to /etc/hosts first)."
  value       = "http://grafana.local.dev:${var.http_host_port}"
}

output "k8s_api_url" {
  description = "Remote k8s API server URL (reachable via Tailscale)."
  value       = "https://${var.tailscale_hostname}:${var.k8s_api_port}"
}
