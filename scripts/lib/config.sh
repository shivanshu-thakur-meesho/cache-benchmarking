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
# Resolve the scripts/ root reliably (this file is always at scripts/lib/config.sh)
_CONFIG_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPTS_ROOT="$(cd "$_CONFIG_SH_DIR/.." && pwd)"
_PROJECT_ROOT="$(cd "$_SCRIPTS_ROOT/.." && pwd)"

RESULTS_DIR="${RESULTS_DIR:-${_PROJECT_ROOT}/results/$(date +%Y%m%d_%H%M%S)}"

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

# ── Search benchmark using redis-cli with pipeline support ───────────
# memtier --command splits on spaces, which breaks FT.SEARCH queries
# like "@price:[10 50]". This function uses redis-cli with pipelining.
#
# Pipeline works by sending N copies of the command to a single redis-cli
# stdin connection — redis-cli sends them all before reading responses,
# which is exactly what pipelining does at the protocol level.
#
# Config via env: PIPELINE (default 1), TEST_TIME (default 60), SEARCH_CLIENTS (default 10)
#
# Usage: run_search_bench "test_name" "FT.SEARCH" "index" "query" [extra args...]
run_search_bench() {
  local test_name="$1"
  shift
  local cmd_args=("$@")

  local duration="${TEST_TIME:-60}"
  local concurrency="${SEARCH_CLIENTS:-10}"
  local pipeline="${PIPELINE:-1}"
  local outfile="$RESULTS_DIR/${test_name}.txt"

  setup_result_dir

  echo -e "${BOLD}Running: ${CYAN}${test_name}${NC} (${duration}s, ${concurrency} clients, pipeline=${pipeline})"
  echo "  Command: ${cmd_args[*]}"
  echo "  Output: $outfile"
  echo "---"

  {
    echo "# Command: ${cmd_args[*]}"
    echo "# Duration: ${duration}s"
    echo "# Clients: ${concurrency}"
    echo "# Pipeline: ${pipeline}"
    echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""

    # Build the inline command string for piping to redis-cli
    # We need to quote args that contain spaces for the inline protocol
    local inline_cmd=""
    for arg in "${cmd_args[@]}"; do
      if [[ "$arg" =~ [[:space:]] ]]; then
        inline_cmd+="\"${arg}\" "
      else
        inline_cmd+="${arg} "
      fi
    done
    inline_cmd="${inline_cmd% }"  # trim trailing space

    # Build a pipeline batch: N copies of the command
    local pipe_batch=""
    for ((p=0; p<pipeline; p++)); do
      pipe_batch+="${inline_cmd}"$'\n'
    done

    # Verify command works first
    local test_result
    test_result=$(echo "$inline_cmd" | redis-cli -u "$URI" 2>&1) || true
    if [[ "$test_result" =~ ERR|error ]]; then
      echo "WARNING: Command returned error: $test_result"
      echo ""
    fi

    local start_epoch=$(date +%s%3N)
    local end_epoch=$(( start_epoch + duration * 1000 ))
    local latencies_file=$(mktemp)

    # Launch concurrent workers
    for ((w=0; w<concurrency; w++)); do
      (
        while [[ $(date +%s%3N) -lt $end_epoch ]]; do
          local t1=$(date +%s%3N)
          # Send pipeline batch through single redis-cli connection
          local res
          res=$(printf '%s' "$pipe_batch" | redis-cli -u "$URI" 2>&1) || true
          local t2=$(date +%s%3N)
          local batch_lat=$((t2 - t1))

          # Per-command latency = batch time / pipeline size
          local per_cmd_lat=$((batch_lat / pipeline))
          if [[ $per_cmd_lat -eq 0 ]]; then per_cmd_lat=1; fi

          if [[ "$res" =~ ERR|error ]]; then
            # still record — some in the batch may have succeeded
            :
          fi

          # Record one latency entry per command in the pipeline
          for ((pp=0; pp<pipeline; pp++)); do
            echo "$per_cmd_lat"
          done >> "$latencies_file"
        done
      ) &
    done

    # Progress while waiting
    local elapsed=0
    while [[ $elapsed -lt $duration ]]; do
      sleep 2
      elapsed=$(( ($(date +%s%3N) - start_epoch) / 1000 ))
      local current_ops=$(wc -l < "$latencies_file" 2>/dev/null | tr -d ' ')
      local rate=0
      if [[ $elapsed -gt 0 ]]; then rate=$((current_ops / elapsed)); fi
      printf "\r  %ds / %ds | %d ops | %d ops/sec  " "$elapsed" "$duration" "$current_ops" "$rate"
    done

    wait

    echo ""
    echo ""

    # Parse results
    local final_ops=$(wc -l < "$latencies_file" | tr -d ' ')
    local actual_elapsed=$(( $(date +%s%3N) - start_epoch ))
    local actual_secs=$(( actual_elapsed / 1000 ))
    if [[ $actual_secs -eq 0 ]]; then actual_secs=1; fi
    local ops_per_sec=$((final_ops / actual_secs))

    # Calculate latency percentiles
    local p50="N/A" p99="N/A" p999="N/A" avg="N/A"
    if [[ $final_ops -gt 0 ]]; then
      sort -n "$latencies_file" > "${latencies_file}.sorted"

      local p50_idx=$(( final_ops * 50 / 100 ))
      local p99_idx=$(( final_ops * 99 / 100 ))
      local p999_idx=$(( final_ops * 999 / 1000 ))
      if [[ $p50_idx -lt 1 ]]; then p50_idx=1; fi
      if [[ $p99_idx -lt 1 ]]; then p99_idx=1; fi
      if [[ $p999_idx -lt 1 ]]; then p999_idx=1; fi

      p50=$(sed -n "${p50_idx}p" "${latencies_file}.sorted")
      p99=$(sed -n "${p99_idx}p" "${latencies_file}.sorted")
      p999=$(sed -n "${p999_idx}p" "${latencies_file}.sorted")

      # Use awk for avg to avoid slow bash loop on large files
      avg=$(awk '{s+=$1} END {if(NR>0) printf "%.0f", s/NR; else print "0"}' "$latencies_file")

      rm -f "${latencies_file}.sorted"
    fi
    rm -f "$latencies_file"

    echo "═══════════════════════════════════════════════"
    echo "  Test:        $test_name"
    echo "  Duration:    ${actual_secs}s"
    echo "  Pipeline:    ${pipeline}"
    echo "  Total Ops:   $final_ops"
    echo "  Ops/sec:     $ops_per_sec"
    echo "  Avg Latency: ${avg}ms"
    echo "  p50 Latency: ${p50}ms"
    echo "  p99 Latency: ${p99}ms"
    echo "  p99.9 Lat:   ${p999}ms"
    echo "═══════════════════════════════════════════════"
    echo ""

    # Output a Totals line the report parser can read
    echo "Totals  ${ops_per_sec}.00  0.00  0.00  ${avg}.000  ${p50}.000  ${p99}.000  ${p999}.000  0.00"
  } 2>&1 | tee "$outfile"

  echo -e "${GREEN}Test ${test_name} completed${NC}"
  echo ""
}
