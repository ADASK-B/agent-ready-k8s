#!/bin/bash
################################################################################
# 🧪 Block 1-2: Test Tool Installation
#
# Purpose: Validates that all required tools are installed and working
# ROADMAP: Block 1-2 (Test)
# Runtime: ~10 seconds
#
# Tests:
#   - Docker (running + user in group)
#   - kind
#   - kubectl
#   - Helm
#   - Flux CLI
#   - k9s
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
#
# Usage:
#   ./setup-template/phase1/01-install-tools/test.sh
################################################################################

set -uo pipefail

# Color codes
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

test_passed=0
test_failed=0

log_test() {
  echo -e "${BLUE}🧪 Testing: $1${RESET}"
}

log_pass() {
  echo -e "${GREEN}  ✓ $1${RESET}"
  ((test_passed++))
}

log_fail() {
  echo -e "${RED}  ✗ $1${RESET}"
  ((test_failed++))
}

log_warning() {
  echo -e "${YELLOW}  ⚠ $1${RESET}"
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║  🧪 Block 1-2: Testing Tool Installation             ║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Test Docker
log_test "Docker"
if command -v docker &> /dev/null; then
  log_pass "Docker installed: $(docker --version)"
  
  if docker ps &> /dev/null; then
    log_pass "Docker running and user in docker group"
  else
    log_fail "Docker installed but not running OR user not in docker group"
    log_warning "Run: sudo usermod -aG docker \$USER && sudo reboot"
  fi
else
  log_fail "Docker not installed"
fi

# Test kind
log_test "kind"
if command -v kind &> /dev/null; then
  log_pass "kind installed: $(kind version)"
else
  log_fail "kind not installed"
fi

# Test kubectl
log_test "kubectl"
if command -v kubectl &> /dev/null; then
  version=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1)
  log_pass "kubectl installed: $version"
else
  log_fail "kubectl not installed"
fi

# Test Helm
log_test "Helm"
if command -v helm &> /dev/null; then
  log_pass "Helm installed: $(helm version --short)"
else
  log_fail "Helm not installed"
fi

# Test Flux CLI
log_test "Flux CLI"
if command -v flux &> /dev/null; then
  log_pass "Flux CLI installed: $(flux version --client 2>&1 | grep 'flux:' || flux version --client)"
else
  log_fail "Flux CLI not installed"
fi

# Test k9s
log_test "k9s"
if command -v k9s &> /dev/null; then
  log_pass "k9s installed: $(k9s version --short 2>/dev/null || k9s version 2>&1 | head -1)"
else
  log_fail "k9s not installed"
fi

# Test Task (optional)
log_test "Task (optional)"
if command -v task &> /dev/null; then
  log_pass "Task installed: $(task --version)"
else
  log_warning "Task not installed (optional)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${CYAN}Test Results:${RESET}"
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
  echo "  Continue with Block 3:"
  echo "  ./setup-template/phase1/02-create-structure/create.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}║  ❌ Some Tests Failed!                                ║${RESET}"
  echo -e "${RED}╚════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${CYAN}📝 Fix Issues:${RESET}"
  echo "  1. Review failed tests above"
  echo "  2. Re-run install: ./setup-template/phase1/01-install-tools/install.sh"
  echo "  3. If Docker was just installed, REBOOT: sudo reboot"
  echo "  4. Re-run this test"
  echo ""
  exit 1
fi
