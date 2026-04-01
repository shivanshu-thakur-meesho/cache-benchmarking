#!/usr/bin/env bash
# Backup Test: GET load while backup is triggered (standalone)
# Trigger backup mid-test: redis-cli -u "$URI" BGSAVE
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=256, test-time=600
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 256 600

echo ">>> Start this test, then trigger backup in another terminal:"
echo ">>>   redis-cli -u \"$URI\" BGSAVE"
echo ""

run_memtier "standalone_backup_get_under_load" \
  docker run --rm --network=host \
  --cpus="$CPUS" \
  --memory="${HALF_MEM_KB}k" \
  --memory-swap="${HALF_MEM_KB}k" \
  redislabs/memtier_benchmark:latest \
  -u "$URI" --protocol=redis \
  --threads="$CPUS" \
  --clients="$(( CPUS * 2 ))" \
  --pipeline="$PIPELINE" \
  --key-minimum="$KEY_MINIMUM" \
  --key-maximum="$KEY_MAXIMUM" \
  --key-pattern="$KEY_PATTERN" \
  --data-size="$DATA_SIZE" \
  --ratio=0:1 \
  --test-time="$TEST_TIME" \
  --hide-histogram
