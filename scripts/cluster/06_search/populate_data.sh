#!/usr/bin/env bash
# Search Benchmark: Populate test data with HSET (cluster)
# Creates product-like documents with TEXT, NUMERIC, TAG, and GEO fields
source "$(dirname "$0")/../../lib/config.sh"

set +e
set +o pipefail

prompt_uri

printf "\n${BOLD}Data Population Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param DOC_COUNT       "doc-count"       "100000"
prompt_param BATCH_SIZE      "batch-size"      "1000"

export DOC_COUNT BATCH_SIZE

setup_result_dir
OUTFILE="$RESULTS_DIR/cluster_search_populate.txt"
mkdir -p "$RESULTS_DIR"

CATEGORIES=("electronics" "clothing" "home" "sports" "books" "toys" "automotive" "garden" "health" "food")
BRANDS=("acme" "globex" "initech" "umbrella" "wayne" "stark" "oscorp" "lexcorp" "cyberdyne" "soylent")
TITLES=("wireless-headphones" "cotton-tshirt" "steel-bottle" "running-shoes" "programming-guide"
        "bluetooth-speaker" "leather-wallet" "ceramic-mug" "yoga-mat" "cooking-pan"
        "laptop-stand" "phone-case" "desk-lamp" "backpack" "sunglasses"
        "smart-watch" "power-bank" "mouse-pad" "keyboard" "monitor")
DESCRIPTIONS=("high-quality-product-with-excellent-performance"
              "premium-materials-for-long-lasting-use"
              "best-seller-with-thousands-of-positive-reviews"
              "lightweight-portable-design-for-everyday-use"
              "advanced-technology-with-modern-features"
              "eco-friendly-made-from-sustainable-materials"
              "professional-grade-suitable-for-commercial-use"
              "budget-friendly-great-value-for-money"
              "limited-edition-with-exclusive-features"
              "top-rated-by-experts-and-consumers")

show_progress() {
  local current="$1" total="$2" start_time="$3"
  local pct=$((current * 100 / total))
  local elapsed=$(( $(date +%s) - start_time ))
  local rate=0
  if [[ $elapsed -gt 0 ]]; then rate=$((current / elapsed)); fi
  local eta="--"
  if [[ $rate -gt 0 ]]; then eta="$(( (total - current) / rate ))s"; fi
  local filled=$((pct * 40 / 100))
  local empty=$((40 - filled))
  local bar=""
  for ((b=0; b<filled; b++)); do bar+="█"; done
  for ((b=0; b<empty; b++)); do bar+="░"; done
  printf "\r  [%s] %3d%% | %d/%d | %d keys/s | ETA: %s  " "$bar" "$pct" "$current" "$total" "$rate" "$eta"
}

{
echo "# Search Data Population (cluster)"
echo "# URI: $URI"
echo "# Documents: $DOC_COUNT"
echo ""

echo "Testing connection..."
PING=$(redis-cli -u "$URI" PING 2>&1)
if [[ "$PING" != *"PONG"* ]]; then
  echo "ERROR: Cannot connect to $URI (got: $PING)"
  exit 1
fi
echo "Connection OK."
echo ""

DBSIZE_BEFORE=$(redis-cli -u "$URI" DBSIZE 2>/dev/null)
echo "DBSIZE before: $DBSIZE_BEFORE"
echo ""

START_TIME=$(date +%s)
echo "Populating $DOC_COUNT documents..."
echo ""

BATCH_FILE=$(mktemp)
ERRORS=0

for ((i=1; i<=DOC_COUNT; i++)); do
  cat_idx=$((RANDOM % ${#CATEGORIES[@]}))
  brand_idx=$((RANDOM % ${#BRANDS[@]}))
  title_idx=$((RANDOM % ${#TITLES[@]}))
  desc_idx=$((RANDOM % ${#DESCRIPTIONS[@]}))
  price=$((RANDOM % 9900 + 100))
  price_dec="$((price / 100)).$((price % 100))"
  rating=$((RANDOM % 50 + 1))
  rating_dec="$((rating / 10)).$((rating % 10))"
  stock=$((RANDOM % 1000))
  lat_offset=$((RANDOM % 100))
  lon_offset=$((RANDOM % 100))

  echo "HSET product:${i} title ${TITLES[$title_idx]}-${i} description ${DESCRIPTIONS[$desc_idx]} category ${CATEGORIES[$cat_idx]} brand ${BRANDS[$brand_idx]} price ${price_dec} rating ${rating_dec} stock ${stock} location 77.5${lon_offset},12.9${lat_offset}" >> "$BATCH_FILE"

  if (( i % BATCH_SIZE == 0 )); then
    RESULT=$(redis-cli -u "$URI" -c < "$BATCH_FILE" 2>&1)
    ERR_COUNT=$(echo "$RESULT" | grep -ci "err" || true)
    ERRORS=$((ERRORS + ERR_COUNT))
    > "$BATCH_FILE"
    show_progress "$i" "$DOC_COUNT" "$START_TIME"
  fi
done

if [[ -s "$BATCH_FILE" ]]; then
  RESULT=$(redis-cli -u "$URI" -c < "$BATCH_FILE" 2>&1)
  ERR_COUNT=$(echo "$RESULT" | grep -ci "err" || true)
  ERRORS=$((ERRORS + ERR_COUNT))
fi
rm -f "$BATCH_FILE"

show_progress "$DOC_COUNT" "$DOC_COUNT" "$START_TIME"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo ""
echo "════════════════════════════════════════════"
echo "  Data population complete."
echo "  Documents sent:  $DOC_COUNT"
echo "  Errors:          $ERRORS"
echo "  Time taken:      ${ELAPSED}s"
if [[ $ELAPSED -gt 0 ]]; then
  echo "  Avg rate:        $((DOC_COUNT / ELAPSED)) keys/s"
fi
echo "════════════════════════════════════════════"
echo ""

DBSIZE_AFTER=$(redis-cli -u "$URI" DBSIZE 2>/dev/null)
echo "DBSIZE after: $DBSIZE_AFTER"
echo ""

echo "Spot check:"
for s in 1 $((DOC_COUNT / 2)) $DOC_COUNT; do
  echo "  product:${s} ->"
  redis-cli -u "$URI" HGETALL "product:${s}" 2>/dev/null | paste - - | head -4
  echo ""
done
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
