#!/usr/bin/env bash
# In-Memory Performance: GET commands (standalone)
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=256, test-time=60
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 256 60 "$CPUS"

run_memtier "standalone_inmemory_get" \
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
  --ratio=0:1 \
  --test-time="$TEST_TIME" \
  --hide-histogram
