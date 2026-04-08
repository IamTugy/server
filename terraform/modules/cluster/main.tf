resource "terraform_data" "cluster" {
  input = {
    cluster_name    = var.cluster_name
    k3s_image       = var.k3s_image
    server_count    = var.server_count
    agent_count     = var.agent_count
    http_host_port  = var.http_host_port
    https_host_port = var.https_host_port
    api_host        = var.api_host
    api_port        = var.api_port
  }

  provisioner "local-exec" {
    command = <<-EOT
      k3d cluster create ${var.cluster_name} \
        --servers ${var.server_count} \
        --agents ${var.agent_count} \
        --image ${var.k3s_image} \
        --port "${var.http_host_port}:80@loadbalancer" \
        --port "${var.https_host_port}:443@loadbalancer" \
        --api-port 0.0.0.0:${var.api_port} \
        --k3s-arg "--tls-san=${var.api_host}@server:*" \
        --kubeconfig-update-default=false \
        --kubeconfig-switch-context=false
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.input.cluster_name}"
  }
}
