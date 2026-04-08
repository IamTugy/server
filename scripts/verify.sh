#!/usr/bin/env bash
# Post-apply health checks. Run after `make apply`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve kubeconfig path
KUBE_FILE="$REPO_ROOT/terraform/kubeconfig/local.yaml"
if [ ! -f "$KUBE_FILE" ]; then
  echo "ERROR: Kubeconfig not found at $KUBE_FILE"
  echo "       Has the cluster been created? Run: make apply"
  exit 1
fi
export KUBECONFIG="$KUBE_FILE"

pass() { echo "  [OK] $*"; }
fail() { echo "  [FAIL] $*"; FAILURES=$((FAILURES + 1)); }

FAILURES=0

echo "========================================"
echo "  Cluster Health Verification"
echo "========================================"

echo ""
echo "--- Nodes ---"
kubectl get nodes -o wide

echo ""
echo "--- All Pods (non-Running) ---"
NOT_RUNNING=$(kubectl get pods -A --field-selector='status.phase!=Running,status.phase!=Succeeded' \
  --no-headers 2>/dev/null | grep -v "Completed" || true)
if [ -z "$NOT_RUNNING" ]; then
  pass "All pods are Running or Succeeded"
else
  echo "$NOT_RUNNING"
  fail "Some pods are not Running"
fi

echo ""
echo "--- Helm Releases ---"
helm list -A

echo ""
echo "--- cert-manager ---"
CM_PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$CM_PODS" -ge 3 ]; then
  pass "cert-manager: $CM_PODS pods found"
else
  fail "cert-manager: expected >= 3 pods, found $CM_PODS"
fi
kubectl get pods -n cert-manager

echo ""
echo "--- cert-manager CRDs ---"
if kubectl get crd certificates.cert-manager.io &>/dev/null; then
  pass "cert-manager CRDs installed"
else
  fail "cert-manager CRDs missing"
fi

echo ""
echo "--- Sealed Secrets ---"
SS_PODS=$(kubectl get pods -n sealed-secrets --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$SS_PODS" -ge 1 ]; then
  pass "sealed-secrets: $SS_PODS pod(s) found"
else
  fail "sealed-secrets: no pods found"
fi
kubectl get pods -n sealed-secrets

echo ""
echo "--- Sealed Secrets CRD ---"
if kubectl get crd sealedsecrets.bitnami.com &>/dev/null; then
  pass "SealedSecrets CRD installed"
else
  fail "SealedSecrets CRD missing"
fi

echo ""
echo "--- Monitoring ---"
MON_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$MON_PODS" -ge 3 ]; then
  pass "monitoring: $MON_PODS Running pods found"
else
  fail "monitoring: expected >= 3 Running pods, found $MON_PODS"
fi
kubectl get pods -n monitoring

echo ""
echo "--- Traefik (built-in k3s) ---"
TRAEFIK_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRAEFIK_PODS" -ge 1 ]; then
  pass "Traefik: $TRAEFIK_PODS pod(s) found in kube-system"
else
  fail "Traefik pods not found in kube-system"
fi

echo ""
echo "--- HTTP connectivity (Traefik) ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HTTP_PORT:-8080}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "200" ]; then
  pass "Traefik responding on port ${HTTP_PORT:-8080} (HTTP $HTTP_CODE)"
else
  fail "Traefik not responding on port ${HTTP_PORT:-8080} (got HTTP $HTTP_CODE)"
fi

echo ""
echo "--- Quick seal test ---"
if command -v kubeseal &>/dev/null; then
  TEST_OUTPUT=$(kubectl create secret generic verify-test \
    --from-literal=key=value \
    --dry-run=client -o yaml 2>/dev/null | \
    kubeseal \
      --controller-namespace sealed-secrets \
      --controller-name sealed-secrets-controller \
      --format yaml 2>/dev/null || echo "FAILED")
  if echo "$TEST_OUTPUT" | grep -q "encryptedData"; then
    pass "kubeseal can communicate with sealed-secrets controller"
  else
    fail "kubeseal seal test failed (controller may still be starting)"
  fi
else
  echo "  [SKIP] kubeseal not installed — skipping seal test"
fi

echo ""
echo "========================================"
if [ "$FAILURES" -eq 0 ]; then
  echo "  All checks passed."
  echo ""
  echo "  Grafana:    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
  echo "  Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
else
  echo "  $FAILURES check(s) failed. Review the output above."
  exit 1
fi
echo "========================================"
