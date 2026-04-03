#!/usr/bin/env bash
# HA Recovery: SET/GET mixed load 1:1 (cluster)
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=256, test-time=600
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 256 600 "$CPUS"

echo ">>> Kill master mid-test to observe failover behavior"
echo ""

run_memtier "cluster_ha_set_get_mixed" \
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
  --ratio=1:1 \
  --test-time="$TEST_TIME" \
  --hide-histogram
