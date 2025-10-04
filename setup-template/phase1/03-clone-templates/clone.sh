#!/bin/bash
################################################################################
# 📦 Block 4: Clone Template Manifests
#
# Purpose: Clones FluxCD example and copies podinfo manifests
# ROADMAP: Block 4
# Runtime: ~15 seconds
#
# Actions:
#   - Clones flux2-kustomize-helm-example (temporary)
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

# Clone Flux Example (temporary)
log_info "Cloning FluxCD flux2-kustomize-helm-example..."
TEMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/fluxcd/flux2-kustomize-helm-example.git "$TEMP_DIR" 2>&1 | grep -v "Cloning into" || true
log_success "Cloned to temporary directory"

# Copy podinfo manifests
log_info "Copying podinfo manifests..."

# Base manifests
if [ -d "$TEMP_DIR/apps/base/podinfo" ]; then
  cp -r "$TEMP_DIR/apps/base/podinfo/"* "apps/podinfo/base/"
  log_success "Copied base manifests to apps/podinfo/base/"
else
  log_warning "No base manifests found in clone (path changed?)"
fi

# Tenant manifests (staging as demo)
if [ -d "$TEMP_DIR/apps/staging/podinfo" ]; then
  cp -r "$TEMP_DIR/apps/staging/podinfo/"* "apps/podinfo/tenants/demo/"
  log_success "Copied tenant manifests to apps/podinfo/tenants/demo/"
else
  log_warning "No staging manifests found in clone (creating minimal tenant overlay)"
  
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

  # Create tenant patch
  cat > apps/podinfo/tenants/demo/patch.yaml << 'PATCH_EOF'
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: tenant-demo
spec:
  values:
    replicaCount: 2
    resources:
      limits:
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
