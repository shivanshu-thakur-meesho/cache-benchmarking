#!/usr/bin/env bash
# Search Benchmark: FT.SEARCH text query throughput/latency (standalone)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

set +e
set +o pipefail

prompt_uri

printf "\n${BOLD}Text Search Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE        "pipeline"       "1"
prompt_param TEST_TIME       "test-time"      "60"
prompt_param SEARCH_CLIENTS  "clients"        "10"

export PIPELINE TEST_TIME SEARCH_CLIENTS

echo ""
echo -e "${BOLD}Running FT.SEARCH text benchmarks...${NC}"
echo ""

# --- Simple text search ---
run_search_bench "standalone_search_text_simple" \
  FT.SEARCH product_idx "headphones"

# --- Field-specific text search ---
run_search_bench "standalone_search_text_field" \
  FT.SEARCH product_idx "@title:wireless"

# --- Wildcard with LIMIT ---
run_search_bench "standalone_search_text_wildcard" \
  FT.SEARCH product_idx "*" LIMIT 0 10

# --- Prefix search ---
run_search_bench "standalone_search_text_prefix" \
  FT.SEARCH product_idx "head*"
