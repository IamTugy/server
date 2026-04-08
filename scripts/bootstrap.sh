#!/usr/bin/env bash
# Idempotent bootstrap: installs tools, checks config, then runs Terraform.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Checking mise..."
if command -v mise &>/dev/null; then
  echo "    Running: mise install"
  mise install
else
  echo "    WARNING: mise not found. Install it from https://mise.jdx.dev"
  echo "    Continuing with whatever versions are in PATH..."
fi

echo "==> Checking kubeseal..."
if ! command -v kubeseal &>/dev/null; then
  if command -v brew &>/dev/null; then
    echo "    Installing kubeseal via brew..."
    brew install kubeseal
  else
    echo "    ERROR: kubeseal not found and brew is unavailable."
    echo "    Install kubeseal manually: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
  fi
fi

echo "==> Checking terraform.tfvars..."
if [ ! -f "$REPO_ROOT/terraform/terraform.tfvars" ]; then
  echo "    Creating terraform/terraform.tfvars from example..."
  cp "$REPO_ROOT/terraform/terraform.tfvars.example" \
     "$REPO_ROOT/terraform/terraform.tfvars"
  echo ""
  echo "    ACTION REQUIRED: Edit terraform/terraform.tfvars and set grafana_admin_password"
  echo "    Then re-run this script."
  exit 1
fi

if grep -q "CHANGE_ME" "$REPO_ROOT/terraform/terraform.tfvars"; then
  echo "    ERROR: grafana_admin_password is still set to CHANGE_ME in terraform/terraform.tfvars"
  echo "    Edit the file and set a real password."
  exit 1
fi

echo "==> Running make apply..."
cd "$REPO_ROOT"
make apply

echo ""
echo "==> Setting KUBECONFIG for this shell session..."
export_cmd=$(make kubeconfig)
eval "$export_cmd"
echo "    KUBECONFIG=$KUBECONFIG"

echo ""
echo "==> Running health checks..."
make verify

echo ""
echo "==> Bootstrap complete!"
echo ""
echo "    IMPORTANT: Backup your sealed-secrets master key:"
echo "      make backup-sealing-key"
echo "    Store the resulting file in a password manager (NOT git)."
