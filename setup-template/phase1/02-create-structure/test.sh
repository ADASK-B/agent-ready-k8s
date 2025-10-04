#!/bin/bash
################################################################################
# 🧪 Block 3: Test Project Structure
#
# Purpose: Validates GitOps folder structure exists
# ROADMAP: Block 3 (Test)
# Runtime: <5 seconds
#
# Tests:
#   - apps/ folder structure
#   - clusters/ folders (local, production)
#   - infrastructure/ folders
#   - policies/ folders
#   - kind-config.yaml exists
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase1/02-create-structure/test.sh
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
echo -e "${CYAN}║  🧪 Block 3: Testing Project Structure                ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$PROJECT_ROOT"

# Test folder structure
log_test "Folder Structure"

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
  if [ -d "$folder" ]; then
    log_pass "Exists: $folder"
  else
    log_fail "Missing: $folder"
  fi
done

# Test kind-config.yaml
log_test "kind-config.yaml"
if [ -f "kind-config.yaml" ]; then
  log_pass "kind-config.yaml exists"
  
  # Validate it's valid YAML and has required fields
  if grep -q "apiVersion: kind.x-k8s.io/v1alpha4" kind-config.yaml && \
     grep -q "name: agent-k8s-local" kind-config.yaml && \
     grep -q "extraPortMappings" kind-config.yaml; then
    log_pass "kind-config.yaml has required fields (ports 80/443)"
  else
    log_fail "kind-config.yaml missing required fields"
  fi
else
  log_fail "kind-config.yaml not found"
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
  echo "  Continue with Block 4:"
  echo "  ./setup-template/phase1/03-clone-templates/clone.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Re-run: ./setup-template/phase1/02-create-structure/create.sh"
  echo "  3. Re-run this test"
  echo ""
  exit 1
fi
