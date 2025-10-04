#!/bin/bash
# =============================================================================
# Script: 02-setup-template-structure.sh
# Description: Übernimmt Best-Practice-Struktur von Flux Example + podinfo
# Phase: 1 (Lokale Template-Setup)
# Dependencies: git, curl
# =============================================================================

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktionen
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║   Template Structure Setup                                ║
║   Flux Example + podinfo + License Compliance             ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Root-Verzeichnis des Projekts
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log_info "Working directory: $PROJECT_ROOT"

# =============================================================================
# Step 1: Flux Example-Repo clonen
# =============================================================================

log_info "Cloning FluxCD flux2-kustomize-helm-example..."

TEMP_DIR="/tmp/agent-k8s-setup-$$"
mkdir -p "$TEMP_DIR"

if git clone --depth 1 https://github.com/fluxcd/flux2-kustomize-helm-example.git "$TEMP_DIR/flux-example" 2>/dev/null; then
    log_success "Flux Example repository cloned"
else
    log_error "Failed to clone Flux Example repo"
    log_warning "Continuing with manual setup..."
fi

# =============================================================================
# Step 2: podinfo-Struktur übernehmen (falls vorhanden)
# =============================================================================

log_info "Setting up podinfo structure..."

if [ -d "$TEMP_DIR/flux-example/apps/base/podinfo" ]; then
    log_info "Found podinfo in Flux Example, copying..."
    mkdir -p apps/podinfo/base
    cp -r "$TEMP_DIR/flux-example/apps/base/podinfo"/* apps/podinfo/base/ 2>/dev/null || true
    log_success "podinfo files copied from Flux Example"
else
    log_warning "podinfo not found in Flux Example, creating minimal structure..."
    
    # Erstelle minimale podinfo HelmRelease
    mkdir -p apps/podinfo/base
    
    cat > apps/podinfo/base/helmrelease.yaml << 'EOF'
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: tenant-demo
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: '>=6.5.0'
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
  values:
    replicaCount: 2
    ingress:
      enabled: true
      className: nginx
      hosts:
        - host: demo.localhost
          paths:
            - path: /
              pathType: Prefix
EOF
    
    cat > apps/podinfo/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tenant-demo
resources:
  - helmrelease.yaml
EOF
    
    log_success "Minimal podinfo structure created"
fi

# =============================================================================
# Step 3: Tenant-Overlay erstellen
# =============================================================================

log_info "Creating tenant overlay for demo..."

mkdir -p apps/podinfo/tenants/demo

cat > apps/podinfo/tenants/demo/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tenant-demo
resources:
  - ../../base
patches:
  - patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: podinfo
        namespace: tenant-demo
      spec:
        values:
          ui:
            message: "Demo Tenant - Powered by agent-ready-k8s"
    target:
      kind: HelmRelease
      name: podinfo
EOF

log_success "Tenant overlay created"

# =============================================================================
# Step 4: Pfade anpassen (staging → local)
# =============================================================================

log_info "Adjusting paths (staging → local)..."

if command -v sed &> /dev/null; then
    find apps/podinfo clusters/local -type f -name "*.yaml" -exec sed -i 's/staging/local/g' {} \; 2>/dev/null || true
    log_success "Paths adjusted"
else
    log_warning "sed not found, skipping path adjustment"
fi

# =============================================================================
# Step 5: Lizenz-Hinweise erstellen
# =============================================================================

log_info "Creating LICENSE-3RD-PARTY.md..."

cat > LICENSE-3RD-PARTY.md << 'EOF'
# Third-Party Licenses & Attributions

This project uses code and patterns from the following open-source projects:

## FluxCD flux2-kustomize-helm-example
- **Source:** https://github.com/fluxcd/flux2-kustomize-helm-example
- **License:** Apache-2.0
- **Copyright:** Cloud Native Computing Foundation (CNCF)
- **Usage:** Repository structure, GitOps patterns, Kustomize layouts
- **Changes:** Adapted for local development with kind, simplified structure

## podinfo (Demo Application)
- **Source:** https://github.com/stefanprodan/podinfo
- **License:** Apache-2.0
- **Copyright:** Stefan Prodan
- **Usage:** Demo workload for testing Kubernetes deployments, Helm charts
- **Changes:** Custom Ingress configuration, tenant overlays

## AKS Baseline Automation (Phase 2 - Future)
- **Source:** https://github.com/Azure/aks-baseline-automation
- **License:** MIT
- **Copyright:** Microsoft Corporation
- **Usage:** Azure Kubernetes Service best practices (Phase 2 only)
- **Changes:** Will be integrated in Phase 2 for AKS deployment

## helm/kind-action (Phase 2 - Future)
- **Source:** https://github.com/helm/kind-action
- **License:** Apache-2.0
- **Copyright:** The Helm Authors
- **Usage:** CI/CD testing with ephemeral kind clusters (Phase 2 only)
- **Changes:** Will be used in GitHub Actions workflows

---

## License Compliance

All third-party components retain their original licenses as listed above.

**This project (agent-ready-k8s-stack) is licensed under MIT.**

See [LICENSE](LICENSE) for the main project license.

---

## Attributions in Source Files

Where applicable, source files contain header comments with attribution:
```
# Based on: https://github.com/fluxcd/flux2-kustomize-helm-example
# License: Apache-2.0
# Modifications: [Description of changes]
```

---

**Last Updated:** $(date +%Y-%m-%d)
EOF

log_success "LICENSE-3RD-PARTY.md created"

# =============================================================================
# Step 6: README Credits hinzufügen
# =============================================================================

log_info "Adding credits to README.md..."

if ! grep -q "Credits & Attributions" README.md; then
    cat >> README.md << 'EOF'

---

## 🙏 Credits & Attributions

This template is built upon best practices from:
- **[FluxCD flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)** (Apache-2.0) - GitOps structure
- **[podinfo](https://github.com/stefanprodan/podinfo)** by Stefan Prodan (Apache-2.0) - Demo application
- **[AKS Baseline](https://github.com/Azure/aks-baseline-automation)** by Microsoft (MIT) - Azure best practices

See [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) for full attribution details.
EOF
    log_success "Credits added to README.md"
else
    log_warning "Credits already exist in README.md, skipping..."
fi

# =============================================================================
# Step 7: Cleanup
# =============================================================================

log_info "Cleaning up temporary files..."

rm -rf "$TEMP_DIR"
log_success "Temporary files removed"

# =============================================================================
# Summary
# =============================================================================

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✓ Template Structure Setup Complete                    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

log_info "What was created:"
echo "  ✓ apps/podinfo/base/         - Base HelmRelease + Kustomization"
echo "  ✓ apps/podinfo/tenants/demo/ - Demo tenant overlay"
echo "  ✓ LICENSE-3RD-PARTY.md        - Third-party attributions"
echo "  ✓ README.md                   - Credits section added"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  1. Review: cat LICENSE-3RD-PARTY.md"
echo "  2. Continue with ROADMAP Block 5 (kind cluster setup)"
echo "  3. Or run: tree -L 3 apps/podinfo"

exit 0
