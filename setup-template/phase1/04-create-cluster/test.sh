#!/bin/bash
################################################################################
# 🧪 Block 5: Test kind Cluster
#
# Purpose: Validates kind cluster is running and accessible
# ROADMAP: Block 5 (Test)
# Runtime: ~10 seconds
#
# Tests:
#   - Cluster "agent-k8s-local" exists
#   - kubectl can connect to cluster
#   - All nodes are Ready
#   - System pods are running
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase1/04-create-cluster/test.sh
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
echo -e "${CYAN}║  🧪 Block 5: Testing kind Cluster                     ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test cluster exists
log_test "Cluster Existence"
if kind get clusters 2>/dev/null | grep -q "agent-k8s-local"; then
  log_pass "Cluster 'agent-k8s-local' exists"
else
  log_fail "Cluster 'agent-k8s-local' not found"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "Test Results:"
  echo -e "  ${GREEN}Passed: $test_passed${RESET}"
  echo -e "  ${RED}Failed: $test_failed${RESET}"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Cluster Not Found!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 1
fi

# Test kubectl connection
log_test "kubectl Connection"
if kubectl cluster-info >/dev/null 2>&1; then
  log_pass "kubectl can connect to cluster"
else
  log_fail "kubectl cannot connect to cluster"
fi

# Test nodes are ready
log_test "Node Status"
ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready " | wc -l)
total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

if [ "$ready_nodes" -gt 0 ] && [ "$ready_nodes" -eq "$total_nodes" ]; then
  log_pass "All nodes are Ready ($ready_nodes/$total_nodes)"
else
  log_fail "Not all nodes are Ready ($ready_nodes/$total_nodes)"
fi

# Test system pods
log_test "System Pods"
pending_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)

if [ "$pending_pods" -eq 0 ]; then
  running_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep "Running" | wc -l)
  log_pass "All system pods running ($running_pods pods)"
else
  log_fail "$pending_pods system pod(s) not running"
fi

# Test Kubernetes version
log_test "Kubernetes Version"
k8s_version=$(kubectl version 2>/dev/null | grep -oP 'Server Version: \K[^,}]+' | head -1 || kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null || echo "unknown")
if [ "$k8s_version" != "unknown" ]; then
  log_pass "Kubernetes version: $k8s_version"
else
  log_fail "Could not determine Kubernetes version"
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
  echo "  Continue with Block 6:"
  echo "  ./setup-template/phase1/05-deploy-ingress/deploy.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Check cluster status: kubectl get nodes"
  echo "  3. Check pod status: kubectl get pods -A"
  echo "  4. Re-run: ./setup-template/phase1/04-create-cluster/create.sh"
  echo "  5. Re-run this test"
  echo ""
  exit 1
fi
