#!/usr/bin/env bash
# Backup Test: Fill cache with string data (standalone)
# Defaults: pipeline=10, key-min=400M, key-max=500M, data-size=1024, test-time=1200
source "$(dirname "$0")/../../lib/config.sh"
configure_params 10 400000000 500000000 "R:R" 1024 1200 "$(( CPUS * 2 ))" "$(( CPUS * 4 ))"

run_memtier "standalone_backup_fill_string" \
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
