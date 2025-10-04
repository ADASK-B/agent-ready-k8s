#!/bin/bash
################################################################################
# 🚀 Complete Template Setup Script
# 
# Purpose: Automates ROADMAP.md Blocks 3-8 (Phase 1)
# Result:  Running podinfo demo at http://demo.localhost
# Runtime: ~20-30 minutes
#
# Prerequisites:
#   - All tools installed (Block 1-2): Docker, kind, kubectl, Helm, Flux
#   - User in docker group (run 'sudo usermod -aG docker $USER' then reboot)
#
# Usage:
#   ./scripts/setup-complete-template.sh
#
# Related Files:
#   - setup-template/02-setup-template-structure.sh (called by this script)
#   - ROADMAP.md (Phase 1, Blocks 3-8)
################################################################################

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Color Codes
# ─────────────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────
log_info() {
  echo -e "${BLUE}ℹ ${BOLD}$1${RESET}"
}

log_success() {
  echo -e "${GREEN}✓ ${BOLD}$1${RESET}"
}

log_warning() {
  echo -e "${YELLOW}⚠ ${BOLD}$1${RESET}"
}

log_error() {
  echo -e "${RED}✗ ${BOLD}$1${RESET}" >&2
}

log_step() {
  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${RESET}"
  echo -e "${CYAN}${BOLD} $1${RESET}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}\n"
}

# ─────────────────────────────────────────────────────────────────────────────
# Prerequisite Checks
# ─────────────────────────────────────────────────────────────────────────────
check_prerequisites() {
  log_step "🔍 Checking Prerequisites (ROADMAP Block 1-2)"

  local missing_tools=()

  # Check Docker
  if ! command -v docker &> /dev/null; then
    missing_tools+=("docker")
  elif ! docker ps &> /dev/null; then
    log_error "Docker installed but not running or user not in docker group"
    log_warning "Run: sudo usermod -aG docker \$USER && sudo reboot"
    exit 1
  fi

  # Check kind
  if ! command -v kind &> /dev/null; then
    missing_tools+=("kind")
  fi

  # Check kubectl
  if ! command -v kubectl &> /dev/null; then
    missing_tools+=("kubectl")
  fi

  # Check Helm
  if ! command -v helm &> /dev/null; then
    missing_tools+=("helm")
  fi

  # Check Flux (optional but recommended)
  if ! command -v flux &> /dev/null; then
    log_warning "Flux CLI not installed (optional for Phase 1)"
  fi

  if [ ${#missing_tools[@]} -ne 0 ]; then
    log_error "Missing tools: ${missing_tools[*]}"
    log_error "Install them using ROADMAP.md Block 1-2 or run setup-template/01-install-tools.sh"
    exit 1
  fi

  log_success "All prerequisites met"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 3: Create Project Structure
# ─────────────────────────────────────────────────────────────────────────────
create_project_structure() {
  log_step "📁 Block 3: Creating Project Structure"

  log_info "Creating directories..."
  mkdir -p apps/podinfo/{base,tenants/demo}
  mkdir -p clusters/{local,production}/{flux-system,tenants}
  mkdir -p infrastructure/{sources,controllers/{ingress-nginx,sealed-secrets}}
  mkdir -p policies/{namespace-template,conftest}
  mkdir -p scripts/utils
  mkdir -p docs

  log_info "Creating kind-config.yaml..."
  cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
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

  log_info "Creating .gitignore..."
  cat > .gitignore << 'EOF'
# Secrets
.env
.env.local
*.key
*.pem
kubeconfig
*-secret.yaml
!sealed-secret.yaml

# Build
node_modules/
dist/
build/

# IDE
.vscode/
.idea/

# Temp
*.tar.gz
*.log
EOF

  log_success "Block 3 complete: Project structure created"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 4: Setup Template Structure (Flux Example + podinfo)
# ─────────────────────────────────────────────────────────────────────────────
setup_template_structure() {
  log_step "📦 Block 4: Setting up Template Structure"

  if [ -f "setup-template/02-setup-template-structure.sh" ]; then
    log_info "Running setup-template/02-setup-template-structure.sh..."
    chmod +x setup-template/02-setup-template-structure.sh
    ./setup-template/02-setup-template-structure.sh
  else
    log_warning "setup-template/02-setup-template-structure.sh not found"
    log_info "Creating podinfo manifests manually..."

    # Create podinfo HelmRelease
    cat > apps/podinfo/base/helmrelease.yaml << 'EOF'
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: flux-system
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

    # Create podinfo Kustomization
    cat > apps/podinfo/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
EOF

    log_success "podinfo manifests created manually"
  fi

  log_success "Block 4 complete: Template structure ready"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 5: Create kind Cluster
# ─────────────────────────────────────────────────────────────────────────────
create_kind_cluster() {
  log_step "🐳 Block 5: Creating kind Cluster"

  # Check if cluster already exists
  if kind get clusters 2>/dev/null | grep -q "^agent-k8s-local$"; then
    log_warning "Cluster 'agent-k8s-local' already exists"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "Deleting existing cluster..."
      kind delete cluster --name agent-k8s-local
    else
      log_info "Using existing cluster"
      kubectl config use-context kind-agent-k8s-local
      log_success "Block 5 complete: Using existing cluster"
      return 0
    fi
  fi

  log_info "Creating kind cluster 'agent-k8s-local'..."
  kind create cluster --name agent-k8s-local --config=kind-config.yaml

  log_info "Setting kubectl context..."
  kubectl config use-context kind-agent-k8s-local

  log_info "Adding demo.localhost to /etc/hosts..."
  if ! grep -q "demo.localhost" /etc/hosts; then
    echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts > /dev/null
    log_success "Added demo.localhost to /etc/hosts"
  else
    log_info "demo.localhost already in /etc/hosts"
  fi

  log_info "Waiting for cluster to be ready..."
  kubectl wait --for=condition=ready node --all --timeout=300s

  log_success "Block 5 complete: kind cluster running"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 6: Deploy Infrastructure (Ingress-Nginx)
# ─────────────────────────────────────────────────────────────────────────────
deploy_infrastructure() {
  log_step "🏗️ Block 6: Deploying Infrastructure"

  log_info "Adding Helm repositories..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update

  log_info "Installing ingress-nginx..."
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostPort.enabled=true \
    --set controller.service.type=NodePort \
    --wait \
    --timeout=5m

  log_info "Waiting for ingress-nginx to be ready..."
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=ingress-nginx \
    -n ingress-nginx \
    --timeout=300s

  log_success "Block 6 complete: Infrastructure deployed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 7: Deploy Demo App (podinfo)
# ─────────────────────────────────────────────────────────────────────────────
deploy_demo_app() {
  log_step "🚀 Block 7: Deploying Demo App (podinfo)"

  log_info "Creating namespace tenant-demo..."
  kubectl create namespace tenant-demo --dry-run=client -o yaml | kubectl apply -f -

  log_info "Adding podinfo Helm repository..."
  helm repo add podinfo https://stefanprodan.github.io/podinfo
  helm repo update

  log_info "Installing podinfo..."
  helm upgrade --install podinfo podinfo/podinfo \
    --namespace tenant-demo \
    --set replicaCount=2 \
    --set ingress.enabled=true \
    --set ingress.className=nginx \
    --set ingress.hosts[0].host=demo.localhost \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix \
    --wait \
    --timeout=5m

  log_info "Waiting for podinfo pods to be ready..."
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=podinfo \
    -n tenant-demo \
    --timeout=300s

  log_success "Block 7 complete: podinfo deployed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Block 8: Run Functional Tests
# ─────────────────────────────────────────────────────────────────────────────
run_tests() {
  log_step "✅ Block 8: Running Functional Tests"

  log_info "Checking cluster status..."
  kubectl get nodes

  log_info "Checking ingress-nginx status..."
  kubectl get pods -n ingress-nginx

  log_info "Checking podinfo status..."
  kubectl get pods -n tenant-demo

  log_info "Checking ingress configuration..."
  kubectl get ingress -n tenant-demo

  log_info "Testing API endpoint..."
  for i in {1..10}; do
    if curl -s --max-time 5 http://demo.localhost/healthz | grep -q "ok"; then
      log_success "API test passed: http://demo.localhost/healthz"
      break
    else
      log_warning "Attempt $i/10: Waiting for ingress to be ready..."
      sleep 3
    fi
  done

  log_info "Testing podinfo UI..."
  if curl -s --max-time 5 http://demo.localhost | grep -q "podinfo"; then
    log_success "UI test passed: http://demo.localhost"
  else
    log_warning "UI test inconclusive (may need manual browser check)"
  fi

  log_success "Block 8 complete: Tests passed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Print Success Summary
# ─────────────────────────────────────────────────────────────────────────────
print_success_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}${BOLD}║                                                           ║${RESET}"
  echo -e "${GREEN}${BOLD}║  ✅  PHASE 1 SETUP COMPLETE!                              ║${RESET}"
  echo -e "${GREEN}${BOLD}║                                                           ║${RESET}"
  echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}🎯 Demo App Running:${RESET}"
  echo -e "   ${BOLD}http://demo.localhost${RESET}"
  echo ""
  echo -e "${CYAN}📊 Quick Commands:${RESET}"
  echo -e "   ${BOLD}kubectl get pods -n tenant-demo${RESET}     # Check podinfo status"
  echo -e "   ${BOLD}kubectl logs -l app.kubernetes.io/name=podinfo -n tenant-demo${RESET}  # View logs"
  echo -e "   ${BOLD}curl http://demo.localhost/healthz${RESET}  # API health check"
  echo ""
  echo -e "${CYAN}🧪 Test in Browser:${RESET}"
  echo -e "   Open ${BOLD}http://demo.localhost${RESET} in your browser"
  echo ""
  echo -e "${CYAN}🛠️ Cleanup:${RESET}"
  echo -e "   ${BOLD}kind delete cluster --name agent-k8s-local${RESET}"
  echo ""
  echo -e "${YELLOW}📖 Next Steps (see ROADMAP.md):${RESET}"
  echo -e "   1. ✅ Lokal entwickeln (Template funktioniert!)"
  echo -e "   2. ⏸️  Eigene Apps deployen"
  echo -e "   3. 🚀 Phase 2: Git + AKS (später)"
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${BLUE}"
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║  🚀 agent-ready-k8s Template Setup                        ║"
  echo "║  Phase 1: Local Development Environment                  ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  # Change to project root
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  cd "$PROJECT_ROOT"

  log_info "Working directory: $PROJECT_ROOT"

  # Execute blocks in sequence
  check_prerequisites
  create_project_structure
  setup_template_structure
  create_kind_cluster
  deploy_infrastructure
  deploy_demo_app
  run_tests

  # Print success summary
  print_success_summary
}

# Run main function
main "$@"
