#!/usr/bin/env bash
# Search Benchmark: Populate test data with HSET (standalone)
# Creates product-like documents with TEXT, NUMERIC, TAG, and GEO fields
# to simulate a realistic e-commerce search use case.
# Uses RESP protocol for redis-cli --pipe (handles spaces in values correctly).
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

printf "\n${BOLD}Data Population Parameters${NC} ${YELLOW}(press Enter for default)${NC}\n"
prompt_param DOC_COUNT       "doc-count"       "100000"
prompt_param BATCH_SIZE      "batch-size"      "500"

export DOC_COUNT BATCH_SIZE

setup_result_dir
OUTFILE="$RESULTS_DIR/standalone_search_populate.txt"
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

# Generate a single RESP-encoded argument: $<len>\r\n<data>\r\n
resp_arg() {
  local val="$1"
  printf '$%d\r\n%s\r\n' "${#val}" "$val"
}

{
echo "# Search Data Population"
echo "# URI: $URI"
echo "# Documents: $DOC_COUNT"
echo "# Batch size: $BATCH_SIZE"
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

  title_val="${TITLES[$title_idx]}-${i}"
  desc_val="${DESCRIPTIONS[$desc_idx]}"
  cat_val="${CATEGORIES[$cat_idx]}"
  brand_val="${BRANDS[$brand_idx]}"
  loc_val="${lon},${lat}"
  key="product:${i}"

  # HSET key title val description val category val brand val price val rating val stock val location val
  # = 17 args total (1 cmd + 1 key + 8 field-value pairs)
  {
    printf '*17\r\n'
    resp_arg "HSET"
    resp_arg "$key"
    resp_arg "title"
    resp_arg "$title_val"
    resp_arg "description"
    resp_arg "$desc_val"
    resp_arg "category"
    resp_arg "$cat_val"
    resp_arg "brand"
    resp_arg "$brand_val"
    resp_arg "price"
    resp_arg "$price_dec"
    resp_arg "rating"
    resp_arg "$rating_dec"
    resp_arg "stock"
    resp_arg "$stock"
    resp_arg "location"
    resp_arg "$loc_val"
  } >> "$PIPE_FILE"

  if (( i % BATCH_SIZE == 0 )); then
    redis-cli -u "$URI" --pipe < "$PIPE_FILE" 2>&1 | tail -1
    > "$PIPE_FILE"
    printf "\r  Loaded %d / %d documents..." "$i" "$DOC_COUNT"
  fi
done

# Flush remaining
if [[ -s "$PIPE_FILE" ]]; then
  redis-cli -u "$URI" --pipe < "$PIPE_FILE" 2>&1 | tail -1
fi
rm -f "$PIPE_FILE"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo ""
echo "Data population complete."
echo "  Documents loaded: $DOC_COUNT"
echo "  Time taken: ${ELAPSED}s"
echo ""

# Verify
echo "Verifying..."
DBSIZE=$(redis-cli -u "$URI" DBSIZE 2>/dev/null)
echo "  DBSIZE: $DBSIZE"

# Spot check a random doc
SAMPLE_KEY="product:$((RANDOM % DOC_COUNT + 1))"
echo "  Sample ($SAMPLE_KEY):"
redis-cli -u "$URI" HGETALL "$SAMPLE_KEY" 2>/dev/null | head -20
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
