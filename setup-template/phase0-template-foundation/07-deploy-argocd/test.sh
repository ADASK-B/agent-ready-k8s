#!/bin/bash
################################################################################
# 🧪 Block 7: Test Argo CD
#
# Purpose: Validates Argo CD is deployed and accessible
# ROADMAP: Phase 0 - Block 7 (Test)
# Runtime: ~20 seconds
#
# Tests:
#   - Namespace 'argocd' exists
#   - All Argo CD pods are Running
#   - Argo CD server is Ready
#   - Service is available
#   - Ingress is configured
#   - http://argocd.local is reachable
#   - Admin password is retrievable
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase0-template-foundation/07-deploy-argocd/test.sh
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
echo -e "${CYAN}║  🧪 Block 7: Testing Argo CD                          ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test namespace
log_test "Namespace"
if kubectl get namespace argocd >/dev/null 2>&1; then
  log_pass "Namespace 'argocd' exists"
else
  log_fail "Namespace 'argocd' not found"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo -e "${RED}❌ Argo CD Not Deployed!${RESET}"
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi

# Test pods with wait loop
log_test "Argo CD Pods"

# Wait up to 3 minutes for all pods to be Running
max_wait=180
waited=0
all_running=false

while [ $waited -lt $max_wait ]; do
  pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null)
  running_pods=$(echo "$pods" | grep "Running" | wc -l)
  total_pods=$(echo "$pods" | wc -l)
  
  if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
    all_running=true
    break
  fi
  
  sleep 5
  waited=$((waited + 5))
done

if [ "$all_running" = "true" ]; then
  log_pass "All Argo CD pods Running ($running_pods/$total_pods)"
else
  log_fail "Some pods not Running ($running_pods/$total_pods) after ${waited}s"
fi

# Check specific components
components=("argocd-server" "argocd-repo-server" "argocd-application-controller")
for component in "${components[@]}"; do
  pod=$(kubectl get pods -n argocd -l "app.kubernetes.io/name=$component" --no-headers 2>/dev/null | head -n1)
  if [ -n "$pod" ]; then
    status=$(echo "$pod" | awk '{print $3}')
    if [ "$status" = "Running" ]; then
      log_pass "$component is Running"
    else
      log_fail "$component status: $status"
    fi
  else
    log_fail "$component pod not found"
  fi
done

# Test Argo CD server readiness
log_test "Argo CD Server Readiness"
if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
  log_pass "Argo CD server is Ready"
else
  log_fail "Argo CD server not Ready"
fi

# Test service
log_test "Argo CD Service"
if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
  log_pass "Service 'argocd-server' exists"
  
  svc_type=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}')
  if [ "$svc_type" = "ClusterIP" ]; then
    log_pass "Service type is ClusterIP (correct for Ingress)"
  else
    log_fail "Service type is $svc_type (expected: ClusterIP)"
  fi
else
  log_fail "Service 'argocd-server' not found"
fi

# Test ingress
log_test "Ingress"
if kubectl get ingress argocd-server-ingress -n argocd >/dev/null 2>&1; then
  log_pass "Ingress 'argocd-server-ingress' exists"
  
  if kubectl get ingress argocd-server-ingress -n argocd -o yaml | grep -q "argocd.local"; then
    log_pass "Ingress configured for argocd.local"
  else
    log_fail "Ingress not configured for argocd.local"
  fi
else
  log_fail "Ingress 'argocd-server-ingress' not found"
fi

# Test admin password
log_test "Admin Password"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
if [ -n "$ARGOCD_PASSWORD" ]; then
  log_pass "Admin password retrievable"
else
  log_fail "Admin password not found"
fi

# Test HTTP endpoint
log_test "HTTP Endpoint (http://argocd.local)"
if ! grep -q "argocd.local" /etc/hosts 2>/dev/null; then
  log_fail "argocd.local not in /etc/hosts (should have been added by deploy script)"
elif command -v curl >/dev/null 2>&1; then
  max_retries=3
  retry=0
  success=false
  while [ $retry -lt $max_retries ]; do
    http_response=$(curl -s -o /dev/null -w "%{http_code}" http://argocd.local --max-time 10 || echo "000")
    # Argo CD returns 200 or 301/302 (redirect to /applications)
    if [ "$http_response" = "200" ] || [ "$http_response" = "301" ] || [ "$http_response" = "302" ]; then
      log_pass "http://argocd.local returns HTTP $http_response"
      success=true
      break
    fi
    ((retry++))
    if [ $retry -lt $max_retries ]; then
      sleep 3
    fi
  done
  if [ "$success" = "false" ]; then
    log_fail "http://argocd.local returns HTTP $http_response (waited ${max_retries} attempts)"
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
  echo -e "${GREEN}║  ✅ All Argo CD Tests Passed!                        ║${RESET}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}🎉 Argo CD Ready!${RESET}"
  echo ""
  echo -e "${CYAN}📝 Access:${RESET}"
  echo "  URL:      http://argocd.local"
  echo "  Username: admin"
  echo "  Password: ${ARGOCD_PASSWORD}"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Argo CD Tests Failed!                       ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Debug Commands:${RESET}"
  echo "  kubectl get pods -n argocd"
  echo "  kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server"
  echo "  kubectl describe ingress argocd-server-ingress -n argocd"
  echo ""
  exit 1
fi
