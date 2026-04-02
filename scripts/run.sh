#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  Dragonfly BYOC Benchmark CLI
#  Interactive tool for running all validation benchmarks
# ═══════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Set a shared RESULTS_DIR for the entire session so all child scripts write here
export RESULTS_DIR="${PROJECT_ROOT}/results/$(date +%Y%m%d_%H%M%S)"

# ── Banner ───────────────────────────────────────────────────────────
show_banner() {
  echo -e "${BOLD}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║       Dragonfly BYOC Benchmark Suite             ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Main Menu ────────────────────────────────────────────────────────
show_main_menu() {
  echo -e "${BOLD}Select deployment mode:${NC}"
  echo ""
  echo "  1) Standalone"
  echo "  2) Cluster"
  echo "  3) Generate report from existing results"
  echo "  0) Exit"
  echo ""
  printf "Choice: "
}

# ── Standalone Menu ──────────────────────────────────────────────────
show_standalone_menu() {
  echo ""
  echo -e "${BOLD}Standalone Tests:${NC}"
  echo ""
  echo -e "  ${CYAN}In-Memory Performance${NC}"
  echo "    1)  SET"
  echo "    2)  GET"
  echo "    3)  mGET (20 keys)"
  echo "    4)  mGET (50 keys)"
  echo "    5)  mGET (100 keys)"
  echo "    6)  Run ALL in-memory tests"
  echo ""
  echo -e "  ${CYAN}Backup Under Load${NC}"
  echo "    7)  Fill string data"
  echo "    8)  GET under load (trigger BGSAVE mid-test)"
  echo "    9)  Fill bloom filters"
  echo "    10) BF.MEXISTS parallel load (trigger BGSAVE mid-test)"
  echo ""
  echo -e "  ${CYAN}SSD Mode${NC}"
  echo "    11) Fill data (2KB)"
  echo "    12) GET"
  echo "    13) mGET (20 keys)"
  echo "    14) mGET (50 keys)"
  echo "    15) mGET (100 keys)"
  echo "    16) Run ALL SSD tests"
  echo ""
  echo -e "  ${CYAN}HA Recovery${NC}"
  echo "    17) SET/GET mixed (kill master mid-test)"
  echo ""
  echo -e "  ${CYAN}Eviction${NC}"
  echo "    18) Baseline (256B)"
  echo "    19) Stress 2KB"
  echo "    20) Stress 4KB"
  echo "    21) Run ALL eviction tests"
  echo ""
  echo -e "  ${CYAN}Search (FT.*)${NC}"
  echo "    22) Populate test data (100K docs)"
  echo "    23) Create search index"
  echo "    24) Compatibility check (all FT.* commands)"
  echo "    25) Bench: text search (simple, field, wildcard)"
  echo "    26) Bench: filter search (numeric, tag, combined, sorted)"
  echo "    27) Bench: aggregation (count, avg, sum)"
  echo "    28) Run ALL search tests (populate + index + all benchmarks)"
  echo ""
  echo "    0)  Back to main menu"
  echo ""
  printf "Choice: "
}

# ── Cluster Menu ─────────────────────────────────────────────────────
show_cluster_menu() {
  echo ""
  echo -e "${BOLD}Cluster Tests:${NC}"
  echo ""
  echo -e "  ${CYAN}In-Memory Performance${NC}"
  echo "    1)  SET"
  echo "    2)  GET"
  echo "    3)  Run ALL in-memory tests"
  echo ""
  echo -e "  ${CYAN}Backup Under Load${NC}"
  echo "    4)  Fill string data"
  echo "    5)  GET under load (trigger BGSAVE mid-test)"
  echo "    6)  Fill bloom filters"
  echo "    7)  BF.EXISTS parallel load (trigger BGSAVE mid-test)"
  echo ""
  echo -e "  ${CYAN}HA Recovery${NC}"
  echo "    8)  SET/GET mixed (kill master mid-test)"
  echo ""
  echo -e "  ${CYAN}Eviction${NC}"
  echo "    9)  Baseline (256B)"
  echo "    10) Stress 2KB"
  echo "    11) Stress 4KB"
  echo "    12) Run ALL eviction tests"
  echo ""
  echo -e "  ${CYAN}Search (FT.*)${NC}"
  echo "    13) Populate test data (100K docs)"
  echo "    14) Create search index"
  echo "    15) Compatibility check"
  echo "    16) Bench: text search"
  echo "    17) Bench: filter search"
  echo "    18) Bench: aggregation"
  echo "    19) Run ALL search tests"
  echo ""
  echo "    0)  Back to main menu"
  echo ""
  printf "Choice: "
}

# ── Run script helper ────────────────────────────────────────────────
run_script() {
  local script="$SCRIPT_DIR/$1"
  if [[ ! -f "$script" ]]; then
    echo -e "${RED}Script not found: $script${NC}"
    return 1
  fi
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
  bash "$script"
  echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
  echo ""
}

# ── Handle standalone choice ─────────────────────────────────────────
handle_standalone() {
  local choice="$1"
  case "$choice" in
    1)  run_script "standalone/01_inmemory/set.sh" ;;
    2)  run_script "standalone/01_inmemory/get.sh" ;;
    3)  run_script "standalone/01_inmemory/mget_20.sh" ;;
    4)  run_script "standalone/01_inmemory/mget_50.sh" ;;
    5)  run_script "standalone/01_inmemory/mget_100.sh" ;;
    6)  # Run all in-memory
        run_script "standalone/01_inmemory/set.sh"
        run_script "standalone/01_inmemory/get.sh"
        run_script "standalone/01_inmemory/mget_20.sh"
        run_script "standalone/01_inmemory/mget_50.sh"
        run_script "standalone/01_inmemory/mget_100.sh"
        ;;
    7)  run_script "standalone/02_backup/fill_string_data.sh" ;;
    8)  run_script "standalone/02_backup/get_under_load.sh" ;;
    9)  run_script "standalone/02_backup/fill_bloomfilter.sh" ;;
    10) run_script "standalone/02_backup/bf_mexists_load.sh" ;;
    11) run_script "standalone/03_ssd/fill_data.sh" ;;
    12) run_script "standalone/03_ssd/get.sh" ;;
    13) run_script "standalone/03_ssd/mget_20.sh" ;;
    14) run_script "standalone/03_ssd/mget_50.sh" ;;
    15) run_script "standalone/03_ssd/mget_100.sh" ;;
    16) # Run all SSD
        run_script "standalone/03_ssd/fill_data.sh"
        run_script "standalone/03_ssd/get.sh"
        run_script "standalone/03_ssd/mget_20.sh"
        run_script "standalone/03_ssd/mget_50.sh"
        run_script "standalone/03_ssd/mget_100.sh"
        ;;
    17) run_script "standalone/04_ha_recovery/set_get_mixed.sh" ;;
    18) run_script "standalone/05_eviction/baseline.sh" ;;
    19) run_script "standalone/05_eviction/stress_2k.sh" ;;
    20) run_script "standalone/05_eviction/stress_4k.sh" ;;
    21) # Run all eviction
        run_script "standalone/05_eviction/baseline.sh"
        run_script "standalone/05_eviction/stress_2k.sh"
        run_script "standalone/05_eviction/stress_4k.sh"
        ;;
    22) run_script "standalone/06_search/populate_data.sh" ;;
    23) run_script "standalone/06_search/create_index.sh" ;;
    24) run_script "standalone/06_search/compatibility_check.sh" ;;
    25) run_script "standalone/06_search/bench_text_search.sh" ;;
    26) run_script "standalone/06_search/bench_filter_search.sh" ;;
    27) run_script "standalone/06_search/bench_aggregate.sh" ;;
    28) # Run all search
        run_script "standalone/06_search/populate_data.sh"
        run_script "standalone/06_search/create_index.sh"
        run_script "standalone/06_search/compatibility_check.sh"
        run_script "standalone/06_search/bench_text_search.sh"
        run_script "standalone/06_search/bench_filter_search.sh"
        run_script "standalone/06_search/bench_aggregate.sh"
        ;;
    0)  return 1 ;;
    *)  echo -e "${RED}Invalid choice${NC}" ;;
  esac
}

# ── Handle cluster choice ────────────────────────────────────────────
handle_cluster() {
  local choice="$1"
  case "$choice" in
    1)  run_script "cluster/01_inmemory/set.sh" ;;
    2)  run_script "cluster/01_inmemory/get.sh" ;;
    3)  # Run all in-memory cluster
        run_script "cluster/01_inmemory/set.sh"
        run_script "cluster/01_inmemory/get.sh"
        ;;
    4)  run_script "cluster/02_backup/fill_string_data.sh" ;;
    5)  run_script "cluster/02_backup/get_under_load.sh" ;;
    6)  run_script "cluster/02_backup/fill_bloomfilter.sh" ;;
    7)  run_script "cluster/02_backup/bf_exists_load.sh" ;;
    8)  run_script "cluster/04_ha_recovery/set_get_mixed.sh" ;;
    9)  run_script "cluster/05_eviction/baseline.sh" ;;
    10) run_script "cluster/05_eviction/stress_2k.sh" ;;
    11) run_script "cluster/05_eviction/stress_4k.sh" ;;
    12) # Run all eviction cluster
        run_script "cluster/05_eviction/baseline.sh"
        run_script "cluster/05_eviction/stress_2k.sh"
        run_script "cluster/05_eviction/stress_4k.sh"
        ;;
    13) run_script "cluster/06_search/populate_data.sh" ;;
    14) run_script "cluster/06_search/create_index.sh" ;;
    15) run_script "cluster/06_search/compatibility_check.sh" ;;
    16) run_script "cluster/06_search/bench_text_search.sh" ;;
    17) run_script "cluster/06_search/bench_filter_search.sh" ;;
    18) run_script "cluster/06_search/bench_aggregate.sh" ;;
    19) # Run all search cluster
        run_script "cluster/06_search/populate_data.sh"
        run_script "cluster/06_search/create_index.sh"
        run_script "cluster/06_search/compatibility_check.sh"
        run_script "cluster/06_search/bench_text_search.sh"
        run_script "cluster/06_search/bench_filter_search.sh"
        run_script "cluster/06_search/bench_aggregate.sh"
        ;;
    0)  return 1 ;;
    *)  echo -e "${RED}Invalid choice${NC}" ;;
  esac
}

# ── Report generation ────────────────────────────────────────────────
handle_report() {
  local results_base="$SCRIPT_DIR/../results"
  echo ""
  echo -e "${BOLD}Available result directories:${NC}"
  echo ""

  if [[ ! -d "$results_base" ]] || [[ -z "$(ls -A "$results_base" 2>/dev/null)" ]]; then
    echo -e "  ${RED}No results found in $results_base${NC}"
    echo "  Run some benchmarks first."
    return
  fi

  local dirs=()
  local idx=1
  for d in "$results_base"/*/; do
    if [[ -d "$d" ]]; then
      local name=$(basename "$d")
      local count=$(ls "$d"/*.txt 2>/dev/null | wc -l | tr -d ' ')
      echo "  $idx) $name  ($count result files)"
      dirs+=("$d")
      idx=$((idx + 1))
    fi
  done

  echo ""
  printf "Select directory (number): "
  read -r sel

  if [[ "$sel" -ge 1 && "$sel" -le ${#dirs[@]} ]] 2>/dev/null; then
    generate_report "${dirs[$((sel-1))]}"
  else
    echo -e "${RED}Invalid selection${NC}"
  fi
}

# ── Main loop ────────────────────────────────────────────────────────
main() {
  show_banner

  while true; do
    show_main_menu
    read -r main_choice

    case "$main_choice" in
      1)  # Standalone
          while true; do
            show_standalone_menu
            read -r choice
            handle_standalone "$choice" || break
          done
          ;;
      2)  # Cluster
          while true; do
            show_cluster_menu
            read -r choice
            handle_cluster "$choice" || break
          done
          ;;
      3)  handle_report ;;
      0)  echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
      *)  echo -e "${RED}Invalid choice${NC}" ;;
    esac
  done
}

main "$@"
