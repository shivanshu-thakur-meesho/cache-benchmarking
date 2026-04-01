#!/usr/bin/env bash
# Search Benchmark: FT.AGGREGATE throughput/latency (cluster)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Aggregate Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE       "pipeline"       "1"
prompt_param TEST_TIME      "test-time"      "60"

export PIPELINE TEST_TIME

CPUS="$(nproc)"
HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"

echo ""
echo -e "${BOLD}Running FT.AGGREGATE benchmarks (cluster)...${NC}"
echo ""

run_memtier "cluster_search_agg_count" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --cluster-mode \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.AGGREGATE product_idx * GROUPBY 1 @category REDUCE COUNT 0 AS total" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

run_memtier "cluster_search_agg_avg" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --cluster-mode \
  --threads="$(( CPUS / 2 > 0 ? CPUS / 2 : 1 ))" \
  --clients="$CPUS" \
  --pipeline="$PIPELINE" \
  --command="FT.AGGREGATE product_idx * GROUPBY 1 @brand REDUCE AVG 1 @price AS avg_price SORTBY 2 @avg_price DESC" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram
