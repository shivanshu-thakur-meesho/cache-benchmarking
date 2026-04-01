#!/usr/bin/env bash
# Shared config library - provides interactive prompts with defaults

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Prompt helper ────────────────────────────────────────────────────
# Usage: prompt_param "VARNAME" "Label" "default_value"
# If env var is already set, uses that. Otherwise asks interactively.
# If user presses Enter, uses default.
prompt_param() {
  local varname="$1" label="$2" default="$3"
  local current="${!varname:-}"

  if [[ -n "$current" ]]; then
    printf "  ${CYAN}%-15s${NC} = ${GREEN}%s${NC} (from env)\n" "$label" "$current"
    return
  fi

  printf "  ${CYAN}%-15s${NC} [${YELLOW}%s${NC}]: " "$label" "$default"
  read -r input
  if [[ -z "$input" ]]; then
    eval "$varname='$default'"
  else
    eval "$varname='$input'"
  fi
}

# ── URI prompt (always required) ─────────────────────────────────────
prompt_uri() {
  if [[ -z "${URI:-}" ]]; then
    printf "\n${BOLD}Connection${NC}\n"
    printf "  ${CYAN}URI${NC}: "
    read -r URI
    if [[ -z "$URI" ]]; then
      echo -e "${RED}ERROR: URI is required (e.g. redis://host:6379)${NC}"
      exit 1
    fi
  else
    printf "\n${BOLD}Connection${NC}\n"
    printf "  ${CYAN}URI${NC} = ${GREEN}%s${NC} (from env)\n" "$URI"
  fi
  export URI
}

# ── Full interactive config ──────────────────────────────────────────
# Call with: configure_params <default_pipeline> <default_key_min> <default_key_max> <default_key_pattern> <default_data_size> <default_test_time>
configure_params() {
  local def_pipeline="${1:-1}" def_key_min="${2:-1}" def_key_max="${3:-2000000}"
  local def_key_pattern="${4:-R:R}" def_data_size="${5:-256}" def_test_time="${6:-60}"

  prompt_uri

  printf "\n${BOLD}Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
  prompt_param PIPELINE       "pipeline"      "$def_pipeline"
  prompt_param KEY_MINIMUM    "key-minimum"   "$def_key_min"
  prompt_param KEY_MAXIMUM    "key-maximum"   "$def_key_max"
  prompt_param KEY_PATTERN    "key-pattern"   "$def_key_pattern"
  prompt_param DATA_SIZE      "data-size"     "$def_data_size"
  prompt_param TEST_TIME      "test-time"     "$def_test_time"

  export PIPELINE KEY_MINIMUM KEY_MAXIMUM KEY_PATTERN DATA_SIZE TEST_TIME

  # Docker resource defaults
  CPUS="$(nproc)"
  HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"
  export CPUS HALF_MEM_KB

  printf "\n${BOLD}Final Config:${NC}\n"
  printf "  URI          = ${GREEN}%s${NC}\n" "$URI"
  printf "  pipeline     = ${GREEN}%s${NC}\n" "$PIPELINE"
  printf "  key-minimum  = ${GREEN}%s${NC}\n" "$KEY_MINIMUM"
  printf "  key-maximum  = ${GREEN}%s${NC}\n" "$KEY_MAXIMUM"
  printf "  key-pattern  = ${GREEN}%s${NC}\n" "$KEY_PATTERN"
  printf "  data-size    = ${GREEN}%s${NC}\n" "$DATA_SIZE"
  printf "  test-time    = ${GREEN}%s${NC}\n" "$TEST_TIME"
  printf "  threads      = ${GREEN}%s${NC} (auto)\n" "$CPUS"
  echo ""

  printf "Proceed? [Y/n]: "
  read -r confirm
  if [[ "$confirm" =~ ^[nN] ]]; then
    echo "Aborted."
    exit 0
  fi
}

# ── Result capture ───────────────────────────────────────────────────
RESULTS_DIR="${RESULTS_DIR:-$(dirname "$(dirname "$(realpath "$0")")")/../results/$(date +%Y%m%d_%H%M%S)}"

setup_result_dir() {
  mkdir -p "$RESULTS_DIR"
  export RESULTS_DIR
}

# Run memtier and capture output to both terminal and result file
# Usage: run_memtier "test_name" docker run ...
run_memtier() {
  local test_name="$1"
  shift
  local outfile="$RESULTS_DIR/${test_name}.txt"

  setup_result_dir

  echo -e "${BOLD}Running: ${CYAN}${test_name}${NC}"
  echo "Output: $outfile"
  echo "---"

  # Save the full command for the report
  echo "# Command:" > "$outfile"
  echo "$@" >> "$outfile"
  echo "" >> "$outfile"
  echo "# Output:" >> "$outfile"

  # Run and tee output
  "$@" 2>&1 | tee -a "$outfile"
  local exit_code=${PIPESTATUS[0]}

  echo "" >> "$outfile"
  echo "# Exit code: $exit_code" >> "$outfile"
  echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$outfile"

  if [[ $exit_code -ne 0 ]]; then
    echo -e "${RED}Test ${test_name} failed with exit code ${exit_code}${NC}"
  else
    echo -e "${GREEN}Test ${test_name} completed successfully${NC}"
  fi
  echo ""

  return $exit_code
}
