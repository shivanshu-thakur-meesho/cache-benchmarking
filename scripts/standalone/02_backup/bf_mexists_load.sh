#!/usr/bin/env bash
# Backup Test: BF.MEXISTS load on all 10 BFs in parallel (standalone)
# Run this while triggering backup to observe impact
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}BF.MEXISTS Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param BF_FILL_CAP    "fill-capacity"  "269000000"
prompt_param PIPELINE       "pipeline"       "30"
prompt_param TEST_TIME      "test-time"      "300"

export BF_FILL_CAP PIPELINE TEST_TIME

CPUS="$(nproc)"
HALF_MEM_KB="$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 2 ))"

setup_result_dir
OUTFILE="$RESULTS_DIR/standalone_backup_bf_mexists.txt"
mkdir -p "$RESULTS_DIR"

echo ">>> Trigger backup in another terminal: redis-cli -u \"$URI\" BGSAVE"
echo ""

{
echo "# BF.MEXISTS parallel load on 10 BFs"
echo "# URI: $URI"
echo ""

for i in $(seq -w 1 10); do
  docker run --rm --network=host \
    redislabs/memtier_benchmark:latest \
    -u "$URI" \
    --protocol=redis \
    --command="BF.MEXISTS bf$i __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__ __key__" \
    --command-key-pattern=R \
    --key-minimum=1 \
    --key-maximum="$BF_FILL_CAP" \
    --threads="$CPUS" \
    --clients="$CPUS" \
    --pipeline="$PIPELINE" \
    --test-time="$TEST_TIME" \
    --hide-histogram &
done

wait
echo "All BF.MEXISTS runs completed."
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
