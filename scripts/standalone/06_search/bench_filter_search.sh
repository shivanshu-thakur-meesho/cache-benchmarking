#!/usr/bin/env bash
# Search Benchmark: FT.SEARCH with filters (numeric, tag, combined) (standalone)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

set +e
set +o pipefail

prompt_uri

printf "\n${BOLD}Filter Search Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE        "pipeline"       "1"
prompt_param TEST_TIME       "test-time"      "60"
prompt_param SEARCH_CLIENTS  "clients"        "10"

export PIPELINE TEST_TIME SEARCH_CLIENTS

echo ""
echo -e "${BOLD}Running FT.SEARCH filter benchmarks...${NC}"
echo ""

# --- Numeric range search ---
run_search_bench "standalone_search_numeric_range" \
  FT.SEARCH product_idx "@price:[10 50]" LIMIT 0 10

# --- Tag filter search ---
run_search_bench "standalone_search_tag_filter" \
  FT.SEARCH product_idx "@category:{electronics}" LIMIT 0 10

# --- Combined: tag + numeric ---
run_search_bench "standalone_search_combined_filter" \
  FT.SEARCH product_idx "@category:{electronics} @price:[0 100]" LIMIT 0 10

# --- Sorted results ---
run_search_bench "standalone_search_sorted" \
  FT.SEARCH product_idx "*" SORTBY price ASC LIMIT 0 10

# --- NOCONTENT (IDs only, lighter) ---
run_search_bench "standalone_search_nocontent" \
  FT.SEARCH product_idx "@category:{electronics}" NOCONTENT LIMIT 0 100

# --- RETURN specific fields ---
run_search_bench "standalone_search_return_fields" \
  FT.SEARCH product_idx "@category:{electronics}" RETURN 2 title price LIMIT 0 10
