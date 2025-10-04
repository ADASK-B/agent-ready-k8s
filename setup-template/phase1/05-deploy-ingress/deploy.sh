#!/bin/bash
################################################################################
# 🌐 Block 6: Deploy Ingress-Nginx
#
# Purpose: Deploys ingress-nginx controller via Helm
# ROADMAP: Block 6
# Runtime: ~90 seconds
#
# Actions:
#   - Adds ingress-nginx Helm repository
#   - Deploys ingress-nginx with NodePort (kind compatibility)
#   - Waits for ingress controller to be ready
#
# Usage:
#   ./setup-template/phase1/05-deploy-ingress/deploy.sh
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
echo -e "${CYAN}║  🌐 Block 6: Deploying Ingress-Nginx                  ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check if already deployed
if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  log_warning "Namespace 'ingress-nginx' already exists"
  echo ""
  read -p "Redeploy ingress-nginx? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Using existing ingress-nginx deployment"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Ingress                            ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}📝 Next Steps:${RESET}"
    echo "  Test: ./setup-template/phase1/05-deploy-ingress/test.sh"
    echo ""
    exit 0
  fi
  
  log_info "Uninstalling existing ingress-nginx..."
  helm uninstall ingress-nginx -n ingress-nginx || true
  kubectl delete namespace ingress-nginx --timeout=60s || true
  log_success "Existing deployment removed"
fi

# Add Helm repository
log_info "Adding ingress-nginx Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>&1 | grep -v "already exists" || true
helm repo update 2>&1 | grep -v "Hang tight" || true
log_success "Helm repository added"

# Create namespace
log_info "Creating namespace..."
kubectl create namespace ingress-nginx
log_success "Namespace created"

# Deploy ingress-nginx (kind-compatible with hostPort)
log_info "Deploying ingress-nginx (this takes ~90 seconds)..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set controller.service.type=NodePort \
  --set controller.updateStrategy.type=RollingUpdate \
  --set controller.updateStrategy.rollingUpdate.maxUnavailable=1 \
  --wait \
  --timeout 5m
log_success "ingress-nginx deployed"

# Wait for ingress controller to be ready
log_info "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
log_success "Ingress controller is ready"

# Show deployment status
log_info "Ingress controller status:"
echo ""
kubectl get pods -n ingress-nginx
echo ""
kubectl get svc -n ingress-nginx
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Ingress-Nginx Deployed!                           ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase1/05-deploy-ingress/test.sh"
echo ""
