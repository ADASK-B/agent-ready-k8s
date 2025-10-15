#!/bin/bash
################################################################################
# 📦 Block 4: Clone Template Manifests
#
# Purpose: Clones podinfo demo manifests for local deployment
# ROADMAP: Block 4
# Runtime: ~15 seconds
#
# Actions:
#   - Clones podinfo example repository (temporary)
#   - Copies podinfo manifests to apps/podinfo/
#   - Cleans up temporary clone
#
# Usage:
#   ./setup-template/phase1/03-clone-templates/clone.sh
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
echo -e "${CYAN}║  📦 Block 4: Cloning Template Manifests               ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Check if apps/podinfo already has manifests
if [ -f "apps/podinfo/base/kustomization.yaml" ]; then
  log_warning "Manifests already exist in apps/podinfo/base/"
  echo ""
  read -p "Overwrite existing manifests? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Skipping clone (keeping existing manifests)"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Manifests                          ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}📝 Next Steps:${RESET}"
    echo "  Test: ./setup-template/phase1/03-clone-templates/test.sh"
    echo ""
    exit 0
  fi
fi

# Clone podinfo repository (for manifests examples)
log_info "Cloning podinfo repository for Kubernetes manifests..."
TEMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/stefanprodan/podinfo.git "$TEMP_DIR" 2>&1 | grep -v "Cloning into" || true
log_success "Cloned to temporary directory"

# Copy podinfo manifests
log_info "Copying podinfo Kubernetes manifests..."

# Check if kustomize directory exists in podinfo repo
if [ -d "$TEMP_DIR/kustomize" ]; then
  cp -r "$TEMP_DIR/kustomize/"* "apps/podinfo/base/" 2>/dev/null || true
  log_success "Copied base manifests to apps/podinfo/base/"
else
  log_warning "No kustomize directory found, creating minimal manifests"
fi

# Create tenant overlay (demo namespace)
log_info "Creating tenant overlay for demo namespace..."

# Create minimal tenant kustomization
cat > apps/podinfo/tenants/demo/kustomization.yaml << 'TENANT_EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tenant-demo
resources:
  - ../../base
patchesStrategicMerge:
  - patch.yaml
TENANT_EOF

# Create tenant patch (standard Kubernetes, not Flux-specific)
cat > apps/podinfo/tenants/demo/patch.yaml << 'PATCH_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: tenant-demo
spec:
  ingressClassName: nginx
  rules:
  - host: demo.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: podinfo
            port:
              number: 9898
PATCH_EOF

log_success "Created tenant manifests"
fi

# Cleanup
rm -rf "$TEMP_DIR"
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 64Mi
PATCH_EOF

  log_success "Created tenant manifests in apps/podinfo/tenants/demo/"
fi

# Cleanup
log_info "Cleaning up temporary clone..."
rm -rf "$TEMP_DIR"
log_success "Temporary files removed"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Template Manifests Cloned!                        ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase1/03-clone-templates/test.sh"
echo ""
