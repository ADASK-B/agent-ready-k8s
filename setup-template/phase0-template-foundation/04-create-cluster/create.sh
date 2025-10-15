#!/bin/bash
################################################################################
# 🚀 Block 5: Create kind Cluster
#
# Purpose: Creates local Kubernetes cluster with kind
# ROADMAP: Block 5
# Runtime: ~60 seconds
#
# Actions:
#   - Creates kind cluster "agent-k8s-local"
#   - Uses kind-config.yaml (ports 80/443 mapped)
#   - Waits for cluster to be ready
#
# Usage:
#   ./setup-template/phase1/04-create-cluster/create.sh
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
echo -e "${CYAN}║  🚀 Block 5: Creating kind Cluster                    ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "agent-k8s-local"; then
  log_warning "Cluster 'agent-k8s-local' already exists"
  echo ""
  read -p "Delete and recreate? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deleting existing cluster..."
    kind delete cluster --name agent-k8s-local
    log_success "Existing cluster deleted"
  else
    echo ""
    log_info "Using existing cluster"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Cluster                            ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${CYAN}📝 Next Steps:${RESET}"
    echo "  Test: ./setup-template/phase1/04-create-cluster/test.sh"
    echo ""
    exit 0
  fi
fi

# Create cluster
log_info "Creating kind cluster (this takes ~60 seconds)..."
if [ -f "kind-config.yaml" ]; then
  kind create cluster --config kind-config.yaml
  log_success "Cluster created with custom config"
else
  log_warning "kind-config.yaml not found, creating default cluster"
  kind create cluster --name agent-k8s-local
  log_success "Default cluster created"
fi

# Wait for cluster to be ready
log_info "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s
log_success "Cluster is ready"

# Show cluster info
log_info "Cluster information:"
echo ""
kubectl cluster-info
echo ""
kubectl get nodes
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ kind Cluster Created!                             ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase1/04-create-cluster/test.sh"
echo ""
