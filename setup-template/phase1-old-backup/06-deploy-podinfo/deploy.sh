#!/bin/bash
################################################################################
# 🚀 Block 7: Deploy podinfo Demo
#
# Purpose: Deploys podinfo application via Helm
# ROADMAP: Block 7
# Runtime: ~30 seconds
#
# Actions:
#   - Creates tenant-demo namespace
#   - Adds podinfo Helm repository
#   - Deploys podinfo v6.9.2 (2 replicas)
#   - Creates Ingress for http://demo.localhost
#
# Usage:
#   ./setup-template/phase1/06-deploy-podinfo/deploy.sh
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
echo -e "${CYAN}║  🚀 Block 7: Deploying podinfo Demo                   ║${RESET}"
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

# Create namespace
log_info "Creating namespace 'tenant-demo'..."
kubectl create namespace tenant-demo
kubectl label namespace tenant-demo tenant=demo
log_success "Namespace created with label 'tenant=demo'"

# Add Helm repository
log_info "Adding podinfo Helm repository..."
helm repo add podinfo https://stefanprodan.github.io/podinfo 2>&1 | grep -v "already exists" || true
helm repo update 2>&1 | grep -v "Hang tight" || true
log_success "Helm repository added"

# Deploy podinfo
log_info "Deploying podinfo v6.9.2 (2 replicas)..."
helm install podinfo podinfo/podinfo \
  --namespace tenant-demo \
  --version 6.9.2 \
  --set replicaCount=2 \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=demo.localhost \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --wait \
  --timeout 3m
log_success "podinfo deployed"

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
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase1/06-deploy-podinfo/test.sh"
echo ""
echo -e "${CYAN}🌐 Access:${RESET}"
echo "  http://demo.localhost"
echo ""
