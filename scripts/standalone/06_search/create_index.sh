#!/usr/bin/env bash
# Search Benchmark: Create search index and measure index build time (standalone)
# Creates a product index with TEXT, NUMERIC, TAG, and GEO fields
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

setup_result_dir
OUTFILE="$RESULTS_DIR/standalone_search_create_index.txt"
mkdir -p "$RESULTS_DIR"

{
echo "# Search Index Creation"
echo "# URI: $URI"
echo ""

# Drop existing index if any
echo "Dropping existing index (if any)..."
redis-cli -u "$URI" FT.DROPINDEX product_idx 2>/dev/null || true
echo ""

# Create index
echo "Creating index: product_idx"
echo "  Fields: title(TEXT), description(TEXT), category(TAG), brand(TAG),"
echo "          price(NUMERIC SORTABLE), rating(NUMERIC SORTABLE),"
echo "          stock(NUMERIC), location(GEO)"
echo ""

START_TIME=$(date +%s%3N)

redis-cli -u "$URI" FT.CREATE product_idx \
  ON HASH PREFIX 1 "product:" \
  SCHEMA \
    title TEXT WEIGHT 5.0 \
    description TEXT \
    category TAG SEPARATOR "," \
    brand TAG \
    price NUMERIC SORTABLE \
    rating NUMERIC SORTABLE \
    stock NUMERIC \
    location GEO

CREATE_EXIT=$?
END_TIME=$(date +%s%3N)
CREATE_MS=$((END_TIME - START_TIME))

if [[ $CREATE_EXIT -eq 0 ]]; then
  echo "FT.CREATE completed in ${CREATE_MS}ms"
else
  echo "FT.CREATE FAILED (exit code: $CREATE_EXIT)"
fi

echo ""

# Wait for indexing to complete and poll FT.INFO
echo "Waiting for indexing to complete..."
for attempt in $(seq 1 60); do
  sleep 2
  INFO=$(redis-cli -u "$URI" FT.INFO product_idx 2>/dev/null)

  # Extract indexing status
  INDEXING=$(echo "$INFO" | grep -A1 "indexing" | tail -1 | tr -d '[:space:]')
  NUM_DOCS=$(echo "$INFO" | grep -A1 "num_docs" | tail -1 | tr -d '[:space:]')
  HASH_ERRS=$(echo "$INFO" | grep -A1 "hash_indexing_failures" | tail -1 | tr -d '[:space:]')

  printf "\r  Attempt %d: docs=%s indexing=%s errors=%s" "$attempt" "$NUM_DOCS" "$INDEXING" "$HASH_ERRS"

  if [[ "$INDEXING" == "0" ]]; then
    break
  fi
done

TOTAL_END=$(date +%s%3N)
TOTAL_MS=$((TOTAL_END - START_TIME))

echo ""
echo ""
echo "Index ready."
echo "  Total time (create + index build): ${TOTAL_MS}ms"
echo "  Documents indexed: $NUM_DOCS"
echo "  Indexing failures: $HASH_ERRS"
echo ""

# Full FT.INFO dump
echo "--- FT.INFO product_idx ---"
redis-cli -u "$URI" FT.INFO product_idx 2>/dev/null
echo ""

# Memory usage
echo "--- Memory Info ---"
redis-cli -u "$URI" INFO memory 2>/dev/null | grep -E "used_memory_human|used_memory_dataset|used_memory_rss"
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
