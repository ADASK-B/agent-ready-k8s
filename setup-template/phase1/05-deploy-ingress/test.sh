#!/bin/bash
################################################################################
# 🧪 Block 6: Test Ingress-Nginx
#
# Purpose: Validates ingress-nginx controller is running
# ROADMAP: Block 6 (Test)
# Runtime: ~10 seconds
#
# Tests:
#   - Namespace 'ingress-nginx' exists
#   - Helm release deployed
#   - Ingress controller pod is Running
#   - Service is available
#   - Controller is ready to handle traffic
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase1/05-deploy-ingress/test.sh
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
echo -e "${CYAN}║  🧪 Block 6: Testing Ingress-Nginx                    ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test namespace
log_test "Namespace"
if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  log_pass "Namespace 'ingress-nginx' exists"
else
  log_fail "Namespace 'ingress-nginx' not found"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "Test Results:"
  echo -e "  ${GREEN}Passed: $test_passed${RESET}"
  echo -e "  ${RED}Failed: $test_failed${RESET}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Ingress Not Deployed!                             ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 1
fi

# Test Helm release
log_test "Helm Release"
if helm list -n ingress-nginx 2>/dev/null | grep -q "ingress-nginx"; then
  release_status=$(helm list -n ingress-nginx -o json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  if [ "$release_status" = "deployed" ]; then
    log_pass "Helm release deployed"
  else
    log_fail "Helm release status: $release_status (expected: deployed)"
  fi
else
  log_fail "Helm release not found"
fi

# Test ingress controller pod
log_test "Ingress Controller Pod"
controller_pod=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | head -1)

if [ -n "$controller_pod" ]; then
  pod_status=$(echo "$controller_pod" | awk '{print $3}')
  if [ "$pod_status" = "Running" ]; then
    log_pass "Controller pod is Running"
  else
    log_fail "Controller pod status: $pod_status (expected: Running)"
  fi
  
  # Check pod readiness
  ready_status=$(echo "$controller_pod" | awk '{print $2}')
  if echo "$ready_status" | grep -q "1/1"; then
    log_pass "Controller pod is Ready (1/1)"
  else
    log_fail "Controller pod not ready: $ready_status"
  fi
else
  log_fail "Controller pod not found"
fi

# Test service
log_test "Ingress Service"
if kubectl get svc ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  log_pass "Service 'ingress-nginx-controller' exists"
  
  service_type=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.type}')
  if [ "$service_type" = "NodePort" ]; then
    log_pass "Service type: NodePort (kind-compatible)"
  else
    log_fail "Service type: $service_type (expected: NodePort for kind)"
  fi
else
  log_fail "Service 'ingress-nginx-controller' not found"
fi

# Test controller readiness (admission webhook)
log_test "Controller Readiness"
if kubectl get validatingwebhookconfigurations ingress-nginx-admission >/dev/null 2>&1; then
  log_pass "Admission webhook configured"
else
  log_fail "Admission webhook not found (controller may not be fully ready)"
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
  echo -e "${GREEN}║  ✅ All Tests Passed!                                 ║${RESET}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Next Steps:${RESET}"
  echo "  Continue with Block 7:"
  echo "  ./setup-template/phase1/06-deploy-podinfo/deploy.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Check pods: kubectl get pods -n ingress-nginx"
  echo "  3. Check logs: kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
  echo "  4. Re-run: ./setup-template/phase1/05-deploy-ingress/deploy.sh"
  echo "  5. Re-run this test"
  echo ""
  exit 1
fi
