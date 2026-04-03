#!/usr/bin/env bash
# SSD Mode: Fill cache with SET commands (standalone)
# Defaults: pipeline=1, key-min=40M, key-max=60M, data-size=2048, test-time=1500
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 40000000 60000000 "S:S" 2048 1500 2 3

run_memtier "standalone_ssd_fill" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$THREADS" \
  --clients="$CLIENTS" \
  --pipeline="$PIPELINE" \
  --key-minimum="$KEY_MINIMUM" \
  --key-maximum="$KEY_MAXIMUM" \
  --key-pattern="$KEY_PATTERN" \
  --data-size="$DATA_SIZE" \
  --ratio=1:0 \
  --test-time="$TEST_TIME" \
  --hide-histogram
