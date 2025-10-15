#!/bin/bash
################################################################################
# 🗄️ Block 6: Deploy Databases (PostgreSQL + Redis)
#
# Purpose: Deploys PostgreSQL and Redis for application data and Hot-Reload
# ROADMAP: Phase 0 - Block 6
# Runtime: ~2-3 minutes
#
# Actions:
#   - Creates demo-platform namespace
#   - Deploys PostgreSQL via Bitnami Helm Chart
#   - Deploys Redis via Bitnami Helm Chart
#   - Waits for both to be ready
#
# Credentials:
#   PostgreSQL:
#     - Host: postgresql.demo-platform:5432
#     - User: demouser
#     - Pass: demopass
#     - DB:   demodb
#   Redis:
#     - Host: redis-master.demo-platform:6379
#     - Pass: redispass
#
# Usage:
#   ./setup-template/phase0-template-foundation/06-deploy-databases/deploy.sh
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
echo -e "${CYAN}║  🗄️  Block 6: Deploying Databases                     ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check if namespace already exists
if kubectl get namespace demo-platform >/dev/null 2>&1; then
  log_warning "Namespace 'demo-platform' already exists"
  echo ""
  read -p "Redeploy databases? This will DELETE existing data! (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Using existing database deployments"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║  ✅ Using Existing Databases                          ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
  fi
  
  log_info "Uninstalling existing databases..."
  helm uninstall postgresql -n demo-platform 2>/dev/null || true
  helm uninstall redis -n demo-platform 2>/dev/null || true
  kubectl delete namespace demo-platform --timeout=60s || true
  sleep 5
  log_success "Existing deployments removed"
fi

# Create namespace
log_info "Creating namespace 'demo-platform'..."
kubectl create namespace demo-platform
kubectl label namespace demo-platform platform=demo
log_success "Namespace created"

# Add Bitnami Helm repository
log_info "Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>&1 | grep -v "already exists" || true
helm repo update 2>&1 | grep -v "Hang tight" || true
log_success "Helm repository ready"

# Deploy PostgreSQL
log_info "Deploying PostgreSQL..."
helm install postgresql bitnami/postgresql \
  --namespace demo-platform \
  --set auth.username=demouser \
  --set auth.password=demopass \
  --set auth.database=demodb \
  --set primary.persistence.size=2Gi \
  --set primary.resources.requests.cpu=100m \
  --set primary.resources.requests.memory=256Mi \
  --set primary.resources.limits.cpu=500m \
  --set primary.resources.limits.memory=512Mi \
  --wait \
  --timeout=5m

log_success "PostgreSQL deployed"

# Deploy Redis
log_info "Deploying Redis..."
helm install redis bitnami/redis \
  --namespace demo-platform \
  --set auth.password=redispass \
  --set master.persistence.size=1Gi \
  --set replica.replicaCount=0 \
  --set master.resources.requests.cpu=100m \
  --set master.resources.requests.memory=128Mi \
  --set master.resources.limits.cpu=200m \
  --set master.resources.limits.memory=256Mi \
  --wait \
  --timeout=5m

log_success "Redis deployed"

# Wait for pods to be fully ready
log_info "Waiting for database pods to be ready..."
kubectl wait --namespace demo-platform \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=postgresql \
  --timeout=180s

kubectl wait --namespace demo-platform \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=redis \
  --timeout=180s

log_success "All database pods are ready"

# Show deployment status
echo ""
log_info "Deployment status:"
echo ""
kubectl get pods -n demo-platform
echo ""
kubectl get svc -n demo-platform
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✅ Databases Deployed!                               ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📝 Connection Details:${RESET}"
echo ""
echo "  PostgreSQL:"
echo "    Host:     postgresql.demo-platform:5432"
echo "    User:     demouser"
echo "    Password: demopass"
echo "    Database: demodb"
echo ""
echo "  Redis:"
echo "    Host:     redis-master.demo-platform:6379"
echo "    Password: redispass"
echo ""
echo -e "${CYAN}🧪 Test Connections:${RESET}"
echo "  # PostgreSQL"
echo "  kubectl run -n demo-platform postgresql-client --rm --tty -i --restart='Never' --image docker.io/bitnami/postgresql:17 --env PGPASSWORD=demopass --command -- psql --host postgresql.demo-platform -U demouser -d demodb -c 'SELECT version();'"
echo ""
echo "  # Redis"
echo "  kubectl run -n demo-platform redis-client --rm --tty -i --restart='Never' --image docker.io/bitnami/redis:7.4 --command -- redis-cli -h redis-master.demo-platform -a redispass ping"
echo ""
echo -e "${CYAN}📝 Next Steps:${RESET}"
echo "  Test: ./setup-template/phase0-template-foundation/06-deploy-databases/test.sh"
echo ""
