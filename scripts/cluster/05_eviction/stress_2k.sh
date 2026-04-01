#!/usr/bin/env bash
# Eviction Test: Stress with 2KB values (cluster)
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=2048, test-time=300
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 2048 300

run_memtier "cluster_eviction_stress_2k" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --cluster-mode \
  --threads="$CPUS" \
  --clients="$(( CPUS * 2 ))" \
  --pipeline="$PIPELINE" \
  --key-minimum="$KEY_MINIMUM" \
  --key-maximum="$KEY_MAXIMUM" \
  --key-pattern="$KEY_PATTERN" \
  --data-size="$DATA_SIZE" \
  --ratio=1:1 \
  --test-time="$TEST_TIME" \
  --hide-histogram
