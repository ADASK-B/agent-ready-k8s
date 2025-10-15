#!/bin/bash
################################################################################
# 🧪 Block 6: Test Databases
#
# Purpose: Validates PostgreSQL and Redis are deployed and accessible
# ROADMAP: Phase 0 - Block 6 (Test)
# Runtime: ~30 seconds
#
# Tests:
#   - Namespace 'demo-platform' exists
#   - Helm releases deployed
#   - PostgreSQL pod Running and Ready
#   - Redis pod Running and Ready
#   - PostgreSQL connection test
#   - Redis connection test
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase0-template-foundation/06-deploy-databases/test.sh
################################################################################

set -uo pipefail

# Color codes
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'

test_passed=0
test_failed=0

log_test() {
  echo -e "${CYAN}🧪 Testing: $1${RESET}"
}

log_pass() {
  echo -e "${GREEN}  ✓ $1${RESET}"
  ((test_passed++))
}

log_fail() {
  echo -e "${RED}  ✗ $1${RESET}"
  ((test_failed++))
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  🧪 Block 6: Testing Databases                        ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test namespace
log_test "Namespace"
if kubectl get namespace demo-platform >/dev/null 2>&1; then
  log_pass "Namespace 'demo-platform' exists"
else
  log_fail "Namespace 'demo-platform' not found"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo -e "${RED}❌ Databases Not Deployed!${RESET}"
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi

# Test Helm releases
log_test "Helm Releases"
if helm list -n demo-platform 2>/dev/null | grep -q "postgresql"; then
  log_pass "PostgreSQL Helm release deployed"
else
  log_fail "PostgreSQL Helm release not found"
fi

if helm list -n demo-platform 2>/dev/null | grep -q "redis"; then
  log_pass "Redis Helm release deployed"
else
  log_fail "Redis Helm release not found"
fi

# Test PostgreSQL pod
log_test "PostgreSQL Pod"
pg_pod=$(kubectl get pods -n demo-platform -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | head -n1)
if [ -n "$pg_pod" ]; then
  pg_status=$(echo "$pg_pod" | awk '{print $3}')
  pg_ready=$(echo "$pg_pod" | awk '{print $2}')
  
  if [ "$pg_status" = "Running" ]; then
    log_pass "PostgreSQL pod is Running"
  else
    log_fail "PostgreSQL pod status: $pg_status (expected: Running)"
  fi
  
  if echo "$pg_ready" | grep -q "1/1"; then
    log_pass "PostgreSQL pod is Ready"
  else
    log_fail "PostgreSQL pod readiness: $pg_ready (expected: 1/1)"
  fi
else
  log_fail "PostgreSQL pod not found"
fi

# Test Redis pod
log_test "Redis Pod"
redis_pod=$(kubectl get pods -n demo-platform -l app.kubernetes.io/name=redis --no-headers 2>/dev/null | head -n1)
if [ -n "$redis_pod" ]; then
  redis_status=$(echo "$redis_pod" | awk '{print $3}')
  redis_ready=$(echo "$redis_pod" | awk '{print $2}')
  
  if [ "$redis_status" = "Running" ]; then
    log_pass "Redis pod is Running"
  else
    log_fail "Redis pod status: $redis_status (expected: Running)"
  fi
  
  if echo "$redis_ready" | grep -q "1/1"; then
    log_pass "Redis pod is Ready"
  else
    log_fail "Redis pod readiness: $redis_ready (expected: 1/1)"
  fi
else
  log_fail "Redis pod not found"
fi

# Test PostgreSQL connection
log_test "PostgreSQL Connection"
pg_test=$(kubectl run postgresql-test-$$  -n demo-platform \
  --rm --attach --restart=Never \
  --image=docker.io/bitnami/postgresql:17 \
  --env PGPASSWORD=demopass \
  --command -- psql --host postgresql.demo-platform -U demouser -d demodb -c 'SELECT 1;' 2>&1 || true)

if echo "$pg_test" | grep -q "1 row"; then
  log_pass "PostgreSQL connection successful"
else
  log_fail "PostgreSQL connection failed"
fi

# Test Redis connection
log_test "Redis Connection"
redis_test=$(kubectl run redis-test-$$ -n demo-platform \
  --rm --attach --restart=Never \
  --image=docker.io/bitnami/redis:7.4 \
  --command -- redis-cli -h redis-master.demo-platform -a redispass ping 2>&1 || true)

if echo "$redis_test" | grep -q "PONG"; then
  log_pass "Redis connection successful"
else
  log_fail "Redis connection failed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Test Results:"
echo -e "  ${GREEN}Passed: $test_passed${RESET}"
echo -e "  ${RED}Failed: $test_failed${RESET}"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $test_failed -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║  ✅ All Database Tests Passed!                        ║${RESET}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Database Tests Failed!                       ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Debug Commands:${RESET}"
  echo "  kubectl get pods -n demo-platform"
  echo "  kubectl logs -n demo-platform -l app.kubernetes.io/name=postgresql"
  echo "  kubectl logs -n demo-platform -l app.kubernetes.io/name=redis"
  echo ""
  exit 1
fi
