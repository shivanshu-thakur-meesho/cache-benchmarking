#!/usr/bin/env bash
# Search Benchmark: FT.AGGREGATE throughput/latency (standalone)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

set +e
set +o pipefail

prompt_uri

printf "\n${BOLD}Aggregate Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE        "pipeline"       "1"
prompt_param TEST_TIME       "test-time"      "60"
prompt_param SEARCH_CLIENTS  "clients"        "10"

export PIPELINE TEST_TIME SEARCH_CLIENTS

echo ""
echo -e "${BOLD}Running FT.AGGREGATE benchmarks...${NC}"
echo ""

# --- GROUPBY + COUNT ---
run_search_bench "standalone_search_agg_count" \
  FT.AGGREGATE product_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total

# --- GROUPBY + AVG + SORTBY ---
run_search_bench "standalone_search_agg_avg" \
  FT.AGGREGATE product_idx "*" GROUPBY 1 @brand REDUCE AVG 1 @price AS avg_price SORTBY 2 @avg_price DESC

# --- GROUPBY + SUM + LIMIT ---
run_search_bench "standalone_search_agg_sum" \
  FT.AGGREGATE product_idx "*" GROUPBY 1 @category REDUCE SUM 1 @stock AS total_stock SORTBY 2 @total_stock DESC LIMIT 0 5

# --- Multiple REDUCE functions ---
run_search_bench "standalone_search_agg_multi" \
  FT.AGGREGATE product_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total REDUCE AVG 1 @price AS avg_price REDUCE SUM 1 @stock AS total_stock
