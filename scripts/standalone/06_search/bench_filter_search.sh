#!/usr/bin/env bash
# Search Benchmark: FT.SEARCH with filters (numeric, tag, combined) (standalone)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Filter Search Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE       "pipeline"       "1"
prompt_param TEST_TIME      "test-time"      "60"

export PIPELINE TEST_TIME

CPUS="$(nproc)"
HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"

echo ""
echo -e "${BOLD}Running FT.SEARCH filter benchmarks...${NC}"
echo ""

# --- Numeric range search ---
run_memtier "standalone_search_numeric_range" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.SEARCH product_idx @price:[10 50] LIMIT 0 10" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

# --- Tag filter search ---
run_memtier "standalone_search_tag_filter" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.SEARCH product_idx @category:{electronics} LIMIT 0 10" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

# --- Combined: text + numeric + tag ---
run_memtier "standalone_search_combined_filter" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.SEARCH product_idx @category:{electronics} @price:[0 100] LIMIT 0 10" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

# --- Sorted results ---
run_memtier "standalone_search_sorted" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.SEARCH product_idx * SORTBY price ASC LIMIT 0 10" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

# --- NOCONTENT (IDs only, lighter) ---
run_memtier "standalone_search_nocontent" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.SEARCH product_idx @category:{electronics} NOCONTENT LIMIT 0 100" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram
