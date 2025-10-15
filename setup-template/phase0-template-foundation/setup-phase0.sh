#!/bin/bash
################################################################################
# 🚀 MASTER SCRIPT: Phase 0 - Template Foundation Setup
#
# Purpose: Complete Kubernetes platform with all dependencies for local development
# ROADMAP: Phase 0 (Foundation Layer - Blocks 1-8)
# Runtime: ~8-10 minutes total
#
# Blocks Overview:
# 01: Install Tools (Docker, kind, kubectl, Helm, Argo CD CLI, Task)
# 02: Create Project Structure (apps/, clusters/, infrastructure/, policies/)
# 03: Clone Template Manifests (podinfo demo application)
# 04: Create kind Cluster (agent-k8s-local)
# 05: Deploy Ingress-Nginx (Helm)
# 06: Deploy Databases (PostgreSQL + Redis via Helm)
# 07: Deploy Argo CD (GitOps)
# 08: Deploy podinfo Demo (Helm, connected to Redis)
#
# Result:
#   ✅ Complete K8s platform ready for your applications
#   ✅ http://demo.localhost (podinfo demo app)
#   ✅ http://argocd.local (Argo CD UI)
#   ✅ PostgreSQL + Redis ready for Hot-Reload pattern
#
# Exit behavior:
#   - Stops on first test failure
#   - Shows progress with block numbers
#   - Final result: ✅ or ❌
#
# Usage:
#   ./setup-template/phase0-template-foundation/setup-phase0.sh
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
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Start
START_TIME=$(date +%s)

log_header "🚀 Phase 0: Complete Template Foundation Setup          "

echo -e "${CYAN}This will:${RESET}"
echo "  1. Install required tools (Docker, kind, kubectl, Helm)"
echo "  2. Create GitOps project structure"
echo "  3. Clone podinfo template manifests"
echo "  4. Create local kind cluster"
echo "  5. Deploy ingress-nginx controller"
echo "  6. Deploy PostgreSQL + Redis databases"
echo "  7. Deploy Argo CD (GitOps)"
echo "  8. Deploy podinfo demo application (connected to Redis)"
echo ""
echo -e "${YELLOW}Runtime: ~8-10 minutes${RESET}"
echo ""
echo -e "${CYAN}Result:${RESET}"
echo "  ✅ http://demo.localhost (podinfo)"
echo "  ✅ http://argocd.local (Argo CD UI)"
echo "  ✅ PostgreSQL + Redis ready for Hot-Reload"
echo ""
read -p "Continue? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Aborted by user"
  exit 0
fi

# Block 01: Install Tools
log_block "Block 1: Installing Tools"
if ./setup-template/phase0-template-foundation/01-install-tools/install.sh; then
  log_success "Tools installed"
  
  if ./setup-template/phase0-template-foundation/01-install-tools/test.sh; then
    log_success "Tools validated"
  else
    log_error "Tool validation failed"
    exit 1
  fi
else
  log_error "Tool installation failed"
  exit 1
fi

# Block 02: Create Structure
log_block "Block 2: Creating Project Structure"
if ./setup-template/phase0-template-foundation/02-create-structure/create.sh; then
  log_success "Structure created"
  
  if ./setup-template/phase0-template-foundation/02-create-structure/test.sh; then
    log_success "Structure validated"
  else
    log_error "Structure validation failed"
    exit 1
  fi
else
  log_error "Structure creation failed"
  exit 1
fi

# Block 03: Clone Templates
log_block "Block 3: Cloning Template Manifests"
if ./setup-template/phase0-template-foundation/03-clone-templates/clone.sh; then
  log_success "Manifests cloned"
  
  if ./setup-template/phase0-template-foundation/03-clone-templates/test.sh; then
    log_success "Manifests validated"
  else
    log_error "Manifests validation failed"
    exit 1
  fi
else
  log_error "Manifests cloning failed"
  exit 1
fi

# Block 04: Create Cluster
log_block "Block 4: Creating kind Cluster"
if ./setup-template/phase0-template-foundation/04-create-cluster/create.sh; then
  log_success "Cluster created"
  
  if ./setup-template/phase0-template-foundation/04-create-cluster/test.sh; then
    log_success "Cluster validated"
  else
    log_error "Cluster validation failed"
    exit 1
  fi
else
  log_error "Cluster creation failed"
  exit 1
fi

# Block 05: Deploy Ingress
log_block "Block 5: Deploying Ingress-Nginx"
if ./setup-template/phase0-template-foundation/05-deploy-ingress/deploy.sh; then
  log_success "Ingress deployed"
  
  if ./setup-template/phase0-template-foundation/05-deploy-ingress/test.sh; then
    log_success "Ingress validated"
  else
    log_error "Ingress validation failed"
    exit 1
  fi
else
  log_error "Ingress deployment failed"
  exit 1
fi

# Block 06: Deploy Databases
log_block "Block 6: Deploying Databases (PostgreSQL + Redis)"
if ./setup-template/phase0-template-foundation/06-deploy-databases/deploy.sh; then
  log_success "Databases deployed"
  
  if ./setup-template/phase0-template-foundation/06-deploy-databases/test.sh; then
    log_success "Databases validated"
  else
    log_error "Database validation failed"
    exit 1
  fi
else
  log_error "Database deployment failed"
  exit 1
fi

# Block 07: Deploy Argo CD
log_block "Block 7: Deploying Argo CD"
if ./setup-template/phase0-template-foundation/07-deploy-argocd/deploy.sh; then
  log_success "Argo CD deployed"
  
  if ./setup-template/phase0-template-foundation/07-deploy-argocd/test.sh; then
    log_success "Argo CD validated"
  else
    log_error "Argo CD validation failed"
    exit 1
  fi
else
  log_error "Argo CD deployment failed"
  exit 1
fi

# Block 08: Deploy podinfo
log_block "Block 8: Deploying podinfo Demo"
if ./setup-template/phase0-template-foundation/08-deploy-podinfo/deploy.sh; then
  log_success "podinfo deployed"
  
  if ./setup-template/phase0-template-foundation/08-deploy-podinfo/test.sh; then
    log_success "podinfo validated"
  else
    log_error "podinfo validation failed"
    exit 1
  fi
else
  log_error "podinfo deployment failed"
  exit 1
fi

# Get Argo CD password for final output
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")

# Success!
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
RUNTIME_MIN=$((RUNTIME / 60))
RUNTIME_SEC=$((RUNTIME % 60))

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                                                        ║${RESET}"
echo -e "${GREEN}║  🎉 PHASE 0 COMPLETE - TEMPLATE FOUNDATION READY!    ║${RESET}"
echo -e "${GREEN}║                                                        ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📊 Summary:${RESET}"
echo "  ✅ All 8 blocks completed successfully"
echo "  ⏱️  Runtime: ${RUNTIME_MIN}m ${RUNTIME_SEC}s"
echo ""
echo -e "${CYAN}🌐 Access Points:${RESET}"
echo ""
echo "  📱 Demo Application:"
echo "     URL: http://demo.localhost"
echo ""
echo "  🔄 Argo CD (GitOps):"
echo "     URL:      http://argocd.local"
echo "     Username: admin"
echo "     Password: ${ARGOCD_PASSWORD}"
echo ""
echo -e "${YELLOW}⚠️  Important - Add to /etc/hosts:${RESET}"
echo "     sudo bash -c 'echo \"127.0.0.1 demo.localhost argocd.local\" >> /etc/hosts'"
echo ""
echo -e "${CYAN}🗄️  Database Credentials:${RESET}"
echo ""
echo "  PostgreSQL:"
echo "     Host:     postgresql.demo-platform:5432"
echo "     User:     demouser"
echo "     Password: demopass"
echo "     Database: demodb"
echo ""
echo "  Redis:"
echo "     Host:     redis-master.demo-platform:6379"
echo "     Password: redispass"
echo ""
echo -e "${CYAN}🧪 Quick Tests:${RESET}"
echo "  # podinfo"
echo "  curl http://demo.localhost"
echo "  curl http://demo.localhost/api/info"
echo "  curl http://demo.localhost/healthz"
echo ""
echo "  # Argo CD"
echo "  curl http://argocd.local"
echo ""
echo -e "${CYAN}🔍 Cluster Info:${RESET}"
echo "  kubectl get pods -A"
echo "  kubectl get ingress -A"
echo "  helm list -A"
echo ""
echo -e "${CYAN}📝 What You Have Now:${RESET}"
echo "  ✅ Local Kubernetes cluster (kind)"
echo "  ✅ Ingress NGINX (http://demo.localhost, http://argocd.local)"
echo "  ✅ PostgreSQL (persistent config storage)"
echo "  ✅ Redis (Hot-Reload Pub/Sub ready)"
echo "  ✅ Argo CD (GitOps continuous delivery)"
echo "  ✅ podinfo (reference app connected to Redis)"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  1. Add domains to /etc/hosts (command above)"
echo "  2. Open http://demo.localhost in browser"
echo "  3. Login to Argo CD: http://argocd.local"
echo "  4. Explore the template structure in apps/, clusters/, infrastructure/"
echo "  5. Build your own app using podinfo as reference"
echo "  6. Implement Hot-Reload pattern with PostgreSQL + Redis"
echo "  7. Continue with Phase 1 (Deploy your own applications)"
echo ""
echo -e "${GREEN}🚀 Template Foundation Ready - Start Building! 🚀${RESET}"
echo ""
