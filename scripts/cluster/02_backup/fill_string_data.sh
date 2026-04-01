#!/usr/bin/env bash
# Backup Test: Fill cache with string data (cluster)
# Defaults: pipeline=10, key-min=300M, key-max=350M, data-size=4096, test-time=600
source "$(dirname "$0")/../../lib/config.sh"
configure_params 10 300000000 350000000 "R:R" 4096 600

run_memtier "cluster_backup_fill_string" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --cluster-mode \
  --threads="$(( CPUS * 2 ))" \
  --clients="$(( CPUS * 4 ))" \
  --pipeline="$PIPELINE" \
  --key-minimum="$KEY_MINIMUM" \
  --key-maximum="$KEY_MAXIMUM" \
  --key-pattern="$KEY_PATTERN" \
  --data-size="$DATA_SIZE" \
  --ratio=1:0 \
  --test-time="$TEST_TIME" \
  --hide-histogram
