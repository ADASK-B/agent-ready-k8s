#!/bin/bash
################################################################################
# 🔄 Block 7: Deploy Argo CD
#
# Purpose: Deploys Argo CD for GitOps continuous delivery
# ROADMAP: Phase 0 - Block 7
# Runtime: ~3-4 minutes
#
# Actions:
#   - Creates argocd namespace
#   - Installs Argo CD v2.12.3
#   - Enables insecure mode for HTTP access
#   - Creates Ingress for argocd.local
#   - Configures /etc/hosts entry
#   - Retrieves admin password
#   - Waits for all components to be ready
#
# Access:
#   URL:      http://argocd.local
#   Username: admin
#   Password: (retrieved from secret and displayed)
#
# Usage:
#   ./setup-template/phase0-template-foundation/07-deploy-argocd/deploy.sh
################################################################################

set -euo pipefail

# Color codes
RESET='\033[0m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

ARGOCD_VERSION="v2.12.3"

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
echo -e "${CYAN}║  🔄 Block 7: Deploying Argo CD                        ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check if already deployed
if kubectl get namespace argocd >/dev/null 2>&1; then
  log_warning "Namespace 'argocd' already exists"
  echo ""
  read -p "Redeploy Argo CD? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Using existing Argo CD deployment"
    
    # Get password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Argo CD                            ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}📝 Access:${RESET}"
    echo "  URL:      http://argocd.local"
    echo "  Username: admin"
    echo "  Password: ${ARGOCD_PASSWORD}"
    echo ""
    exit 0
  fi
  
  log_info "Uninstalling existing Argo CD..."
  kubectl delete namespace argocd --timeout=60s || true
  sleep 5
  log_success "Existing deployment removed"
fi

# Create namespace
log_info "Creating namespace 'argocd'..."
kubectl create namespace argocd
log_success "Namespace created"

# Install Argo CD
log_info "Installing Argo CD ${ARGOCD_VERSION}..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
log_success "Argo CD manifests applied"

# Wait for Argo CD server to be created
log_info "Waiting for Argo CD components to initialize..."
sleep 10

# Patch Argo CD server service to ClusterIP (for Ingress)
log_info "Configuring Argo CD server for Ingress..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
log_success "Service patched"

# Enable insecure mode for HTTP access
log_info "Enabling Argo CD insecure mode for HTTP..."
kubectl set env deployment/argocd-server -n argocd ARGOCD_SERVER_INSECURE=true
log_success "Insecure mode enabled"

# Create Ingress
log_info "Creating Ingress for argocd.local..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-passthrough: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
log_success "Ingress created"

# Wait for Argo CD server to be ready
log_info "Waiting for Argo CD server to be ready (this may take 2-3 minutes)..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s
log_success "Argo CD server is ready"

# Get admin password
log_info "Retrieving admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
log_success "Password retrieved"

# Show deployment status
echo ""
log_info "Deployment status:"
echo ""
kubectl get pods -n argocd
echo ""
kubectl get svc -n argocd
echo ""
kubectl get ingress -n argocd
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Argo CD Deployed!                                 ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Access Details:${RESET}"
echo ""
echo "  URL:      http://argocd.local"
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"
echo ""

# Configure /etc/hosts
echo -e "${YELLOW}⚠️  Configuring /etc/hosts for argocd.local...${RESET}"
if ! grep -q "argocd.local" /etc/hosts 2>/dev/null; then
  echo ""
  echo "  ℹ️  This requires sudo access to modify /etc/hosts"
  echo "  ℹ️  Adding: 127.0.0.1 argocd.local"
  echo ""
  
  if sudo bash -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'; then
    echo -e "${GREEN}✓ Added argocd.local to /etc/hosts${RESET}"
  else
    echo -e "${RED}✗ Failed to add argocd.local to /etc/hosts${RESET}"
    echo "  You can add it manually: sudo bash -c 'echo \"127.0.0.1 argocd.local\" >> /etc/hosts'"
  fi
else
  echo -e "${GREEN}✓ argocd.local already in /etc/hosts${RESET}"
fi
echo ""

echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  1. Open http://argocd.local in browser"
echo "  2. Login with admin / ${ARGOCD_PASSWORD}"
echo "  3. Test: ./setup-template/phase0-template-foundation/07-deploy-argocd/test.sh"
echo ""
