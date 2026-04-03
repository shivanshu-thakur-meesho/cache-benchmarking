#!/usr/bin/env bash
# In-Memory Performance: mGET 100 keys per batch (standalone)
# Defaults: pipeline=1, key-min=1, key-max=2M, data-size=256, test-time=60
source "$(dirname "$0")/../../lib/config.sh"
configure_params 1 1 2000000 "R:R" 256 60 "$CPUS" "$CPUS"

run_memtier "standalone_inmemory_mget100" \
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
  --command="mget __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__" \
  --command-ratio=1 \
  --command-key-pattern=R \
  --test-time="$TEST_TIME" \
  --hide-histogram
