terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.7.0"
    }
  }
}

# Helm and Kubernetes providers read the kubeconfig written by terraform_data.export_kubeconfig.
# The two-phase apply in the Makefile ensures this file exists before these providers are used.
provider "helm" {
  kubernetes = {
    config_path    = "./kubeconfig/local.yaml"
    config_context = "k3d-${var.cluster_name}"
  }
}

provider "kubernetes" {
  config_path    = "./kubeconfig/local.yaml"
  config_context = "k3d-${var.cluster_name}"
}

provider "local" {}
