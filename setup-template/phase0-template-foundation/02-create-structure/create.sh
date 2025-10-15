#!/bin/bash
################################################################################
# 📁 Block 3: Create Project Structure
#
# Purpose: Creates GitOps folder structure for the template
# ROADMAP: Block 3
# Runtime: <5 seconds
#
# Creates:
#   - apps/         (Application manifests)
#   - clusters/     (Cluster configs: local, production)
#   - infrastructure/ (Shared infrastructure: ingress, monitoring, etc.)
#   - policies/     (OPA policies, namespace templates)
#
# Usage:
#   ./setup-template/phase1/02-create-structure/create.sh
################################################################################

set -euo pipefail

# Color codes
RESET='\033[0m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'

log_info() {
  echo -e "${CYAN}➜ $1${RESET}"
}

log_success() {
  echo -e "${GREEN}✓ $1${RESET}"
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  📁 Block 3: Creating Project Structure               ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Create main folders
log_info "Creating GitOps folder structure..."

folders=(
  "apps/podinfo/base"
  "apps/podinfo/tenants/demo"
  "clusters/local"
  "clusters/production"
  "infrastructure/sources"
  "infrastructure/controllers"
  "policies/namespace-template"
  "policies/conftest"
)

for folder in "${folders[@]}"; do
  mkdir -p "$folder"
  log_success "Created: $folder"
done

# Create .gitkeep files to preserve empty dirs
log_info "Adding .gitkeep files..."
find apps clusters infrastructure policies -type d -empty -exec touch {}/.gitkeep \;
log_success ".gitkeep files added"

# Create kind config
log_info "Creating kind cluster config..."
cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: agent-k8s-local
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
log_success "kind-config.yaml created"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Project Structure Created!                        ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase1/02-create-structure/test.sh"
echo ""
