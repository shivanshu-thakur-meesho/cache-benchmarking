#!/usr/bin/env bash
# Backup Test: Fill cache with Bloom Filters (standalone)
# Creates 10 BFs and fills them via BF.ADD
# After fill, trigger backup: redis-cli -u "$URI" BGSAVE
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Bloom Filter Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param BF_ERROR_RATE  "error-rate"     "0.01"
prompt_param BF_CAPACITY    "bf-capacity"    "448000000"
prompt_param BF_FILL_CAP    "fill-capacity"  "269000000"
prompt_param TEST_TIME      "test-time"      "120"

export BF_ERROR_RATE BF_CAPACITY BF_FILL_CAP TEST_TIME

CPUS="$(nproc)"
HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"

setup_result_dir
OUTFILE="$RESULTS_DIR/standalone_backup_bloomfilter_fill.txt"
mkdir -p "$RESULTS_DIR"

{
echo "# Bloom Filter Fill"
echo "# URI: $URI"
echo "# BF_ERROR_RATE: $BF_ERROR_RATE"
echo "# BF_CAPACITY: $BF_CAPACITY"
echo "# BF_FILL_CAP: $BF_FILL_CAP"
echo ""

echo "Creating 10 bloom filters with BF.RESERVE..."
for i in $(seq -w 1 10); do
  redis-cli -u "$URI" DEL "bf$i" >/dev/null
  redis-cli -u "$URI" BF.RESERVE "bf$i" "$BF_ERROR_RATE" "$BF_CAPACITY"
  echo "  Created bf$i"
done

echo ""
echo "Filling bloom filters with BF.ADD via memtier..."
for i in $(seq -w 1 10); do
  echo "--- Filling bf$i ---"
  docker run --rm --network=host \
    redislabs/memtier_benchmark:latest \
    -u "$URI" --protocol=redis \
    --command="BF.ADD bf$i __key__" \
    --command-key-pattern=R \
    --command-ratio=1 \
    --key-minimum=1 \
    --key-maximum="$BF_FILL_CAP" \
    --threads="$CPUS" \
    --clients="$(( CPUS * 2 ))" \
    --pipeline=1 \
    --test-time="$TEST_TIME" \
    --hide-histogram
done

echo ""
echo "Fill complete. Trigger backup with: redis-cli -u \"\$URI\" BGSAVE"
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
