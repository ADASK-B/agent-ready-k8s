#!/bin/bash
################################################################################
# 🧪 Block 4: Test Template Manifests
#
# Purpose: Validates podinfo manifests were copied correctly
# ROADMAP: Block 4 (Test)
# Runtime: <5 seconds
#
# Tests:
#   - apps/podinfo/base/ has kustomization.yaml
#   - apps/podinfo/tenants/demo/ has kustomization.yaml
#   - Manifests contain required Kubernetes resources
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase1/03-clone-templates/test.sh
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
echo -e "${CYAN}║  🧪 Block 4: Testing Template Manifests               ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Test base manifests
log_test "Base Manifests (apps/podinfo/base/)"

if [ -f "apps/podinfo/base/kustomization.yaml" ]; then
  log_pass "kustomization.yaml exists"
  
  # Check for HelmRelease or Deployment
  if ls apps/podinfo/base/*.yaml | xargs grep -l "kind: HelmRelease" >/dev/null 2>&1 || \
     ls apps/podinfo/base/*.yaml | xargs grep -l "kind: Deployment" >/dev/null 2>&1; then
    log_pass "Contains Kubernetes resources (HelmRelease or Deployment)"
  else
    log_fail "No HelmRelease or Deployment found in manifests"
  fi
else
  log_fail "kustomization.yaml not found"
fi

# Count manifest files
manifest_count=$(find apps/podinfo/base -name "*.yaml" -type f | wc -l)
if [ "$manifest_count" -ge 1 ]; then
  log_pass "Found $manifest_count manifest file(s)"
else
  log_fail "No manifest files found"
fi

# Test tenant manifests
log_test "Tenant Manifests (apps/podinfo/tenants/demo/)"

if [ -f "apps/podinfo/tenants/demo/kustomization.yaml" ]; then
  log_pass "kustomization.yaml exists"
  
  # Check for namespace or patch
  if grep -q "namespace:" apps/podinfo/tenants/demo/kustomization.yaml || \
     grep -q "patchesStrategicMerge:" apps/podinfo/tenants/demo/kustomization.yaml; then
    log_pass "Contains tenant-specific configuration"
  else
    log_fail "No tenant-specific configuration found"
  fi
else
  log_fail "kustomization.yaml not found"
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
  echo "  Continue with Block 5:"
  echo "  ./setup-template/phase1/04-create-cluster/create.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Re-run: ./setup-template/phase1/03-clone-templates/clone.sh"
  echo "  3. Re-run this test"
  echo ""
  exit 1
fi
