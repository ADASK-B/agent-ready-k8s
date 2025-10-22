#!/bin/bash
################################################################################
# 🚀 Block 8: Deploy podinfo Demo
#
# Purpose: Deploys podinfo application via Helm (connected to Redis)
# ROADMAP: Phase 0 - Block 8
# Runtime: ~30 seconds
#
# Actions:
#   - Creates tenant-demo namespace
#   - Adds podinfo Helm repository
#   - Deploys podinfo v6.9.2 (2 replicas)
#   - Connects to Redis (demo-platform namespace)
#   - Creates Ingress for http://demo.localhost
#
# Usage:
#   ./setup-template/phase0-template-foundation/08-deploy-podinfo/deploy.sh
################################################################################

set -euo pipefail

# Color codes
RESET='\033[0m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

log_info() {
  echo -e "${CYAN}➜ $1${RESET}"
}

log_success() {
  echo -e "${GREEN}✓ $1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}⚠ $1${RESET}"
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  🚀 Block 8: Deploying podinfo Demo                   ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check if already deployed
if kubectl get namespace tenant-demo >/dev/null 2>&1; then
  log_warning "Namespace 'tenant-demo' already exists"
  echo ""
  read -p "Redeploy podinfo? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Using existing podinfo deployment"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Deployment                         ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}📝 Next Steps:${RESET}"
    echo "  Test: ./setup-template/phase1/06-deploy-podinfo/test.sh"
    echo ""
    exit 0
  fi

  log_info "Uninstalling existing podinfo..."
  helm uninstall podinfo -n tenant-demo || true
  kubectl delete namespace tenant-demo --timeout=60s || true
  log_success "Existing deployment removed"
fi

# Vendor podinfo Helm chart (no external dependencies!)
log_info "Vendoring podinfo Helm chart v6.9.2..."
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHART_DIR="${PROJECT_ROOT}/helm-charts/infrastructure/podinfo"

if [ ! -d "$CHART_DIR" ]; then
  log_info "Downloading podinfo chart from stefanprodan/podinfo..."

  # Add repo temporarily (only for download)
  helm repo add podinfo https://stefanprodan.github.io/podinfo 2>&1 | grep -v "already exists" || true
  helm repo update 2>&1 | grep -v "Hang tight" || true

  # Download and extract chart
  mkdir -p "${PROJECT_ROOT}/helm-charts/infrastructure"
  cd "${PROJECT_ROOT}/helm-charts/infrastructure"
  helm pull podinfo/podinfo --version 6.9.2 --untar

  log_success "podinfo chart vendored to helm-charts/infrastructure/podinfo/"
  log_info "Chart is now part of our repository (no external dependency!)"
else
  log_success "Using vendored podinfo chart from helm-charts/infrastructure/podinfo/"
fi

# Create namespace
log_info "Creating namespace 'tenant-demo'..."
kubectl create namespace tenant-demo
kubectl label namespace tenant-demo tenant=demo
log_success "Namespace created with label 'tenant=demo'"

# Deploy podinfo from LOCAL chart
log_info "Deploying podinfo v6.9.2 from LOCAL chart (2 replicas, connected to Redis)..."
cd "$PROJECT_ROOT"
helm install podinfo ./helm-charts/infrastructure/podinfo/ \
  --namespace tenant-demo \
  --set replicaCount=2 \
  --set redis.enabled=false \
  --set cache="redis-master.demo-platform:6379" \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=demo.localhost \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --wait \
  --timeout 3m
log_success "podinfo deployed from LOCAL chart (no external dependency!)"

# Wait for pods to be ready
log_info "Waiting for podinfo pods to be ready..."
kubectl wait --namespace tenant-demo \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=podinfo \
  --timeout=120s
log_success "podinfo pods are ready"

# Show deployment status
log_info "Deployment status:"
echo ""
kubectl get pods -n tenant-demo
echo ""
kubectl get svc -n tenant-demo
echo ""
kubectl get ingress -n tenant-demo
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ podinfo Deployed!                                 ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Configure /etc/hosts
echo -e "${YELLOW}⚠️  Configuring /etc/hosts for demo.localhost...${RESET}"
if ! grep -q "demo.localhost" /etc/hosts 2>/dev/null; then
  echo ""
  echo "  ℹ️  This requires sudo access to modify /etc/hosts"
  echo "  ℹ️  Adding: 127.0.0.1 demo.localhost"
  echo ""

  if sudo bash -c 'echo "127.0.0.1 demo.localhost" >> /etc/hosts'; then
    echo -e "${GREEN}✓ Added demo.localhost to /etc/hosts${RESET}"
  else
    echo -e "${RED}✗ Failed to add demo.localhost to /etc/hosts${RESET}"
    echo "  You can add it manually: sudo bash -c 'echo \"127.0.0.1 demo.localhost\" >> /etc/hosts'"
  fi
else
  echo -e "${GREEN}✓ demo.localhost already in /etc/hosts${RESET}"
fi
echo ""

echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase0-template-foundation/08-deploy-podinfo/test.sh"
echo ""
echo -e "${CYAN}🌐 Access:${RESET}"
echo "  http://demo.localhost"
echo ""
echo -e "${CYAN}🔍 Test Redis Connection:${RESET}"
echo "  curl http://demo.localhost/cache/test"
echo ""
