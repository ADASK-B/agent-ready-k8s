#!/bin/bash
################################################################################
# 🚀 MASTER SCRIPT: Phase 1 Complete Setup
#
# Purpose: Orchestrates all Phase 1 blocks (1-7)
# ROADMAP: Phase 1 (Blocks 1-7)
# Runtime: ~4-5 minutes total
#
# Blocks Overview:
# 01: Install Tools (Docker, kind, kubectl, Helm, Argo CD, Task)
# 02: Create Project Structure (apps/, clusters/, infrastructure/, policies/)
# 03: Clone Template Manifests (podinfo demo application)
# 04: Create kind Cluster (agent-k8s-local)
#   05: Deploy Ingress-Nginx (Helm)
#   06: Deploy podinfo Demo (Helm)
#
# Exit behavior:
#   - Stops on first test failure
#   - Shows progress with block numbers
#   - Final result: ✅ or ❌
#
# Usage:
#   ./setup-template/setup-phase1.sh
################################################################################

set -euo pipefail

# Color codes
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

log_header() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BLUE}║  $1${RESET}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

log_block() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
  echo -e "${CYAN}  $1${RESET}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
  echo ""
}

log_success() {
  echo -e "${GREEN}✓ $1${RESET}"
}

log_error() {
  echo -e "${RED}✗ $1${RESET}"
}

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Start
START_TIME=$(date +%s)

log_header "🚀 Phase 1: Complete Template Setup                   "

echo -e "${CYAN}This will:${RESET}"
echo "  1. Install required tools"
echo "  2. Create GitOps project structure"
echo "  3. Clone podinfo manifests from demo template"
echo "  4. Create local kind cluster"
echo "  5. Deploy ingress-nginx controller"
echo "  6. Deploy podinfo demo application"
echo ""
echo -e "${YELLOW}Runtime: ~4-5 minutes${RESET}"
echo ""
read -p "Continue? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Aborted by user"
  exit 0
fi

# Block 01-02: Install Tools
log_block "Block 1-2: Installing Tools"
if ./setup-template/phase1/01-install-tools/install.sh; then
  log_success "Tools installed"
  
  if ./setup-template/phase1/01-install-tools/test.sh; then
    log_success "Tools validated"
  else
    log_error "Tool validation failed"
    exit 1
  fi
else
  log_error "Tool installation failed"
  exit 1
fi

# Block 03: Create Structure
log_block "Block 3: Creating Project Structure"
if ./setup-template/phase1/02-create-structure/create.sh; then
  log_success "Structure created"
  
  if ./setup-template/phase1/02-create-structure/test.sh; then
    log_success "Structure validated"
  else
    log_error "Structure validation failed"
    exit 1
  fi
else
  log_error "Structure creation failed"
  exit 1
fi

# Block 04: Clone Templates
log_block "Block 4: Cloning Template Manifests"
if ./setup-template/phase1/03-clone-templates/clone.sh; then
  log_success "Manifests cloned"
  
  if ./setup-template/phase1/03-clone-templates/test.sh; then
    log_success "Manifests validated"
  else
    log_error "Manifests validation failed"
    exit 1
  fi
else
  log_error "Manifests cloning failed"
  exit 1
fi

# Block 05: Create Cluster
log_block "Block 5: Creating kind Cluster"
if ./setup-template/phase1/04-create-cluster/create.sh; then
  log_success "Cluster created"
  
  if ./setup-template/phase1/04-create-cluster/test.sh; then
    log_success "Cluster validated"
  else
    log_error "Cluster validation failed"
    exit 1
  fi
else
  log_error "Cluster creation failed"
  exit 1
fi

# Block 06: Deploy Ingress
log_block "Block 6: Deploying Ingress-Nginx"
if ./setup-template/phase1/05-deploy-ingress/deploy.sh; then
  log_success "Ingress deployed"
  
  if ./setup-template/phase1/05-deploy-ingress/test.sh; then
    log_success "Ingress validated"
  else
    log_error "Ingress validation failed"
    exit 1
  fi
else
  log_error "Ingress deployment failed"
  exit 1
fi

# Block 07: Deploy podinfo
log_block "Block 7: Deploying podinfo Demo"
if ./setup-template/phase1/06-deploy-podinfo/deploy.sh; then
  log_success "podinfo deployed"
  
  if ./setup-template/phase1/06-deploy-podinfo/test.sh; then
    log_success "podinfo validated"
  else
    log_error "podinfo validation failed"
    exit 1
  fi
else
  log_error "podinfo deployment failed"
  exit 1
fi

# Success!
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
RUNTIME_MIN=$((RUNTIME / 60))
RUNTIME_SEC=$((RUNTIME % 60))

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                                                        ║${RESET}"
echo -e "${GREEN}║  🎉 PHASE 1 COMPLETE!                                 ║${RESET}"
echo -e "${GREEN}║                                                        ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📊 Summary:${RESET}"
echo "  ✅ All 6 blocks completed successfully"
echo "  ⏱️  Runtime: ${RUNTIME_MIN}m ${RUNTIME_SEC}s"
echo ""
echo -e "${CYAN}🌐 Demo Application:${RESET}"
echo "  http://demo.localhost"
echo ""
echo -e "${CYAN}🧪 Quick Tests:${RESET}"
echo "  curl http://demo.localhost"
echo "  curl http://demo.localhost/api/info"
echo "  curl http://demo.localhost/healthz"
echo ""
echo -e "${CYAN}🔍 Cluster Info:${RESET}"
echo "  kubectl get pods -A"
echo "  kubectl get ingress -A"
echo "  helm list -A"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  - Explore the template structure in apps/, clusters/, infrastructure/"
echo "  - Review ROADMAP.md for Phase 2 (Cloud deployment)"
echo "  - Customize manifests for your use case"
echo "  - Check LICENSE-3RD-PARTY.md for attributions"
echo ""
echo -e "${GREEN}Ready for production scaling! 🚀${RESET}"
echo ""
