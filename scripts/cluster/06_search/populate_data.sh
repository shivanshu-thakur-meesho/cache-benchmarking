#!/usr/bin/env bash
# Search Benchmark: Populate test data with HSET (cluster)
# Same as standalone - cluster handles hash slot routing automatically
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Data Population Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param DOC_COUNT       "doc-count"       "100000"
prompt_param BATCH_SIZE      "batch-size"      "500"

export DOC_COUNT BATCH_SIZE

setup_result_dir
OUTFILE="$RESULTS_DIR/cluster_search_populate.txt"
mkdir -p "$RESULTS_DIR"

CATEGORIES=("electronics" "clothing" "home" "sports" "books" "toys" "automotive" "garden" "health" "food")
BRANDS=("acme" "globex" "initech" "umbrella" "wayne" "stark" "oscorp" "lexcorp" "cyberdyne" "soylent")
TITLES=("wireless headphones" "cotton tshirt" "stainless steel bottle" "running shoes" "programming guide"
        "bluetooth speaker" "leather wallet" "ceramic mug" "yoga mat" "cooking pan"
        "laptop stand" "phone case" "desk lamp" "backpack" "sunglasses"
        "smart watch" "power bank" "mouse pad" "keyboard" "monitor")
DESCRIPTIONS=("high quality product with excellent performance and durability"
              "premium materials used in manufacturing for long lasting use"
              "best seller in category with thousands of positive reviews"
              "lightweight and portable design perfect for everyday use"
              "advanced technology with modern features and sleek design"
              "eco friendly product made from sustainable materials"
              "professional grade item suitable for commercial use"
              "budget friendly option with great value for money"
              "limited edition release with exclusive features"
              "top rated by experts and consumers alike")

{
echo "# Search Data Population (cluster)"
echo "# URI: $URI"
echo "# Documents: $DOC_COUNT"
echo ""

START_TIME=$(date +%s)
echo "Populating $DOC_COUNT documents..."

PIPE_FILE=$(mktemp)

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
  lat="12.9${lat_offset}"
  lon="77.5${lon_offset}"

  printf 'HSET product:%d title "%s %d" description "%s" category "%s" brand "%s" price %s rating %s stock %d location "%s,%s"\r\n' \
    "$i" "${TITLES[$title_idx]}" "$i" "${DESCRIPTIONS[$desc_idx]}" \
    "${CATEGORIES[$cat_idx]}" "${BRANDS[$brand_idx]}" \
    "$price_dec" "$rating_dec" "$stock" "$lon" "$lat" >> "$PIPE_FILE"

  if (( i % BATCH_SIZE == 0 )); then
    redis-cli -u "$URI" -c --pipe < "$PIPE_FILE" 2>/dev/null
    > "$PIPE_FILE"
    printf "\r  Loaded %d / %d documents..." "$i" "$DOC_COUNT"
  fi
done

if [[ -s "$PIPE_FILE" ]]; then
  redis-cli -u "$URI" -c --pipe < "$PIPE_FILE" 2>/dev/null
fi
rm -f "$PIPE_FILE"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo ""
echo "Data population complete."
echo "  Documents loaded: $DOC_COUNT"
echo "  Time taken: ${ELAPSED}s"
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
