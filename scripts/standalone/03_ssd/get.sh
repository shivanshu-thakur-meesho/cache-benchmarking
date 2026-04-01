#!/usr/bin/env bash
# SSD Mode: GET benchmark (standalone)
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=2048, test-time=600
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 2048 600

run_memtier "standalone_ssd_get" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads=2 \
  --clients=3 \
  --pipeline="$PIPELINE" \
  --key-minimum="$KEY_MINIMUM" \
  --key-maximum="$KEY_MAXIMUM" \
  --key-pattern="$KEY_PATTERN" \
  --data-size="$DATA_SIZE" \
  --ratio=0:1 \
  --test-time="$TEST_TIME" \
  --hide-histogram
