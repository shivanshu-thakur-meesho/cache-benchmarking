#!/usr/bin/env bash
# Search Benchmark: FT.SEARCH text query throughput/latency (cluster)
# Requires: populate_data.sh + create_index.sh already run
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Text Search Benchmark Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param PIPELINE       "pipeline"       "1"
prompt_param TEST_TIME      "test-time"      "60"

export PIPELINE TEST_TIME

CPUS="$(nproc)"
HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"

echo ""
echo -e "${BOLD}Running FT.SEARCH text benchmarks (cluster)...${NC}"
echo ""

run_memtier "cluster_search_text_simple" \
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
  --command="FT.SEARCH product_idx headphones" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram

run_memtier "cluster_search_text_field" \
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
  --command="FT.SEARCH product_idx @title:wireless" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram
