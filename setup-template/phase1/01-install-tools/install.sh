#!/bin/bash
################################################################################
# 📦 Block 1-2: Tool Installation
#
# Purpose: Installs all required tools for Phase 1
# ROADMAP: Block 1-2
# Runtime: ~30 minutes
#
# Tools installed:
#   - Docker Engine CE
#   - kind (Kubernetes in Docker)
#   - kubectl
#   - Helm
#   - Flux CLI
#   - Task (optional)
#
# Usage:
#   ./setup-template/phase1/01-install-tools/install.sh
#
# Test:
#   ./setup-template/phase1/01-install-tools/test.sh
################################################################################

set -euo pipefail

# Color codes
RESET='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

log_info() { echo -e "${BLUE}ℹ $1${RESET}"; }
log_success() { echo -e "${GREEN}✓ $1${RESET}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  📦 Block 1-2: Installing Tools                       ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Do not run as root! Run as normal user."
  exit 1
fi

# Install Docker Engine CE
log_info "Installing Docker Engine CE..."
if ! command -v docker &> /dev/null; then
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  log_success "Docker installed"
  log_warning "⚠️  REBOOT REQUIRED! Run: sudo reboot"
  log_warning "    Then re-run this script after reboot."
else
  log_success "Docker already installed: $(docker --version)"
fi

# Install kind
log_info "Installing kind..."
if ! command -v kind &> /dev/null; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  log_success "kind installed: $(kind version)"
else
  log_success "kind already installed: $(kind version)"
fi

# Install kubectl
log_info "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  log_success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# Install Helm
log_info "Installing Helm..."
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log_success "Helm installed: $(helm version --short)"
else
  log_success "Helm already installed: $(helm version --short)"
fi

# Install Flux CLI
log_info "Installing Flux CLI..."
if ! command -v flux &> /dev/null; then
  curl -s https://fluxcd.io/install.sh | sudo bash
  log_success "Flux installed: $(flux version --client)"
else
  log_success "Flux already installed: $(flux version --client)"
fi

# Install Task (optional)
log_info "Installing Task (optional)..."
if ! command -v task &> /dev/null; then
  if command -v snap &> /dev/null; then
    sudo snap install task --classic
    log_success "Task installed: $(task --version)"
  else
    log_warning "Snap not available, skipping Task installation"
  fi
else
  log_success "Task already installed: $(task --version)"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Block 1-2: Tool Installation Complete            ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  1. Run test: ./setup-template/phase1/01-install-tools/test.sh"
echo "  2. If Docker was installed, REBOOT: sudo reboot"
echo "  3. Continue with Block 3: ./setup-template/phase1/02-create-structure/create.sh"
echo ""
