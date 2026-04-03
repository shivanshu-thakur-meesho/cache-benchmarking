#!/usr/bin/env bash
# Backup Test: GET load while backup is triggered (cluster)
# Defaults: pipeline=1, key-min=200M, key-max=400M, data-size=4096, test-time=600
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 200000000 400000000 "R:R" 4096 600 "$(( CPUS * 2 ))" "$(( CPUS * 4 ))"

echo ">>> Start this test, then trigger backup in another terminal"
echo ""

run_memtier "cluster_backup_get_under_load" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --cluster-mode \
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
