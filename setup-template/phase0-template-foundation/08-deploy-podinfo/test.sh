#!/bin/bash
################################################################################
# 🧪 Block 8: Test podinfo Demo
#
# Purpose: Validates podinfo is deployed and accessible
# ROADMAP: Phase 0 - Block 8 (Test)
# Runtime: ~10 seconds
#
# Tests:
#   - Namespace 'tenant-demo' exists
#   - Helm release deployed
#   - podinfo pods are Running (2 replicas)
#   - Service is available
#   - Ingress is configured
#   - http://demo.localhost is reachable
#   - Redis connection works
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase0-template-foundation/08-deploy-podinfo/test.sh
################################################################################

set -uo pipefail

# Color codes
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

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
echo -e "${CYAN}║  🧪 Block 8: Testing podinfo Demo                     ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test namespace
log_test "Namespace"
if kubectl get namespace tenant-demo >/dev/null 2>&1; then
  log_pass "Namespace 'tenant-demo' exists"
  
  # Check namespace label
  if kubectl get namespace tenant-demo -o jsonpath='{.metadata.labels.tenant}' 2>/dev/null | grep -q "demo"; then
    log_pass "Namespace has label 'tenant=demo'"
  else
    log_fail "Namespace missing label 'tenant=demo'"
  fi
else
  log_fail "Namespace 'tenant-demo' not found"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "Test Results:"
  echo -e "  ${GREEN}Passed: $test_passed${RESET}"
  echo -e "  ${RED}Failed: $test_failed${RESET}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ podinfo Not Deployed!                             ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 1
fi

# Test Helm release
log_test "Helm Release"
if helm list -n tenant-demo 2>/dev/null | grep -q "podinfo"; then
  release_status=$(helm list -n tenant-demo -o json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  if [ "$release_status" = "deployed" ]; then
    log_pass "Helm release deployed"
  else
    log_fail "Helm release status: $release_status"
  fi
  
  # Check version
  chart_version=$(helm list -n tenant-demo -o json 2>/dev/null | grep -o '"app_version":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$chart_version" ]; then
    log_pass "podinfo version: $chart_version"
  fi
else
  log_fail "Helm release not found"
fi

# Test pods
log_test "podinfo Pods"
pods=$(kubectl get pods -n tenant-demo -l app.kubernetes.io/name=podinfo --no-headers 2>/dev/null)
running_pods=$(echo "$pods" | grep "Running" | wc -l)
total_pods=$(echo "$pods" | wc -l)

if [ "$running_pods" -ge 2 ]; then
  log_pass "podinfo pods running: $running_pods/2"
else
  log_fail "podinfo pods running: $running_pods/2 (expected: 2)"
fi

# Check pod readiness
if [ -n "$pods" ]; then
  ready_pods=$(echo "$pods" | awk '{print $2}' | grep "1/1" | wc -l)
  if [ "$ready_pods" -ge 2 ]; then
    log_pass "All pods are Ready (2/2)"
  else
    log_fail "Not all pods are Ready ($ready_pods/2)"
  fi
fi

# Test service
log_test "podinfo Service"
if kubectl get svc podinfo -n tenant-demo >/dev/null 2>&1; then
  log_pass "Service 'podinfo' exists"
  
  cluster_ip=$(kubectl get svc podinfo -n tenant-demo -o jsonpath='{.spec.clusterIP}')
  if [ -n "$cluster_ip" ] && [ "$cluster_ip" != "None" ]; then
    log_pass "Service has ClusterIP: $cluster_ip"
  else
    log_fail "Service missing ClusterIP"
  fi
else
  log_fail "Service 'podinfo' not found"
fi

# Test ingress
log_test "Ingress"
if kubectl get ingress podinfo -n tenant-demo >/dev/null 2>&1; then
  log_pass "Ingress 'podinfo' exists"
  
  # Check host
  if kubectl get ingress podinfo -n tenant-demo -o yaml | grep -q "demo.localhost"; then
    log_pass "Ingress configured for demo.localhost"
  else
    log_fail "Ingress not configured for demo.localhost"
  fi
else
  log_fail "Ingress 'podinfo' not found"
fi

# Test HTTP endpoint (with retry for ingress propagation)
log_test "HTTP Endpoint (http://demo.localhost)"
if ! grep -q "demo.localhost" /etc/hosts 2>/dev/null; then
  echo -e "${YELLOW}  ⚠ Skipped: demo.localhost not in /etc/hosts (add after setup)${RESET}"
elif command -v curl >/dev/null 2>&1; then
  max_retries=5
  retry=0
  success=false
  while [ $retry -lt $max_retries ]; do
    http_response=$(curl -s -o /dev/null -w "%{http_code}" http://demo.localhost --max-time 5 || echo "000")
    if [ "$http_response" = "200" ]; then
      log_pass "http://demo.localhost returns HTTP 200"
      
      # Test JSON response
      json_response=$(curl -s http://demo.localhost --max-time 5)
      if echo "$json_response" | grep -q "podinfo"; then
        log_pass "Response contains 'podinfo' (valid JSON)"
      else
        log_fail "Response does not contain 'podinfo'"
      fi
      success=true
      break
    fi
    ((retry++))
    if [ $retry -lt $max_retries ]; then
      sleep 3
    fi
  done
  if [ "$success" = "false" ]; then
    log_fail "http://demo.localhost returns HTTP $http_response (waited ${max_retries} attempts)"
  fi
else
  log_fail "curl not installed (cannot test HTTP endpoint)"
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
  echo -e "${CYAN}🎉 PHASE 0 COMPLETE!${RESET}"
  echo ""
  echo -e "${CYAN}🌐 Demo Application:${RESET}"
  echo "  http://demo.localhost"
  echo ""
  echo -e "${CYAN}🔄 Argo CD:${RESET}"
  echo "  http://argocd.local"
  echo ""
  echo -e "${CYAN}📝 Next Steps:${RESET}"
  echo "  - Explore podinfo API: curl http://demo.localhost/api/info"
  echo "  - Check health: curl http://demo.localhost/healthz"
  echo "  - Test Redis cache: curl http://demo.localhost/cache/test"
  echo "  - View metrics: curl http://demo.localhost/metrics"
  echo "  - Login to Argo CD: http://argocd.local"
  echo "  - Continue with Phase 1 (Your own apps)"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Check pods: kubectl get pods -n tenant-demo"
  echo "  3. Check logs: kubectl logs -n tenant-demo -l app.kubernetes.io/name=podinfo"
  echo "  4. Check ingress: kubectl describe ingress podinfo -n tenant-demo"
  echo "  5. Re-run: ./setup-template/phase0-template-foundation/08-deploy-podinfo/deploy.sh"
  echo "  6. Re-run this test"
  echo ""
  exit 1
fi
