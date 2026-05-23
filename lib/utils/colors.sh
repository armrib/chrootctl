#!/bin/sh

# ANSI color codes for terminal output
if [ -z "${RED:-}" ]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly CYAN='\033[0;36m'
  readonly BOLD='\033[1m'
  readonly NC='\033[0m'
fi

# Helper functions for colored output
info() {
  printf '%b\n' "${CYAN}ℹ ${NC}$*"
}

success() {
  printf '%b\n' "${GREEN}✓ ${NC}$*"
}

error() {
  printf '%b\n' "${RED}✗ ${NC}$*" >&2
}

warning() {
  printf '%b\n' "${YELLOW}⚠ ${NC}$*" >&2
}

header() {
  printf '%b\n' "${BOLD}${BLUE}$*${NC}"
}
