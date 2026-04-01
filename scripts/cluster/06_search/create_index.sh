#!/usr/bin/env bash
# Search Benchmark: Create search index (cluster)
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

setup_result_dir
OUTFILE="$RESULTS_DIR/cluster_search_create_index.txt"
mkdir -p "$RESULTS_DIR"

{
echo "# Search Index Creation (cluster)"
echo "# URI: $URI"
echo ""

redis-cli -u "$URI" FT.DROPINDEX product_idx 2>/dev/null || true

echo "Creating index: product_idx"

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
echo "Waiting for indexing..."
for attempt in $(seq 1 60); do
  sleep 2
  INFO=$(redis-cli -u "$URI" FT.INFO product_idx 2>/dev/null)
  INDEXING=$(echo "$INFO" | grep -A1 "indexing" | tail -1 | tr -d '[:space:]')
  NUM_DOCS=$(echo "$INFO" | grep -A1 "num_docs" | tail -1 | tr -d '[:space:]')
  printf "\r  Attempt %d: docs=%s indexing=%s" "$attempt" "$NUM_DOCS" "$INDEXING"
  if [[ "$INDEXING" == "0" ]]; then break; fi
done

TOTAL_END=$(date +%s%3N)
TOTAL_MS=$((TOTAL_END - START_TIME))

echo ""
echo ""
echo "Index ready. Total time: ${TOTAL_MS}ms, Docs indexed: $NUM_DOCS"
echo ""
echo "--- FT.INFO ---"
redis-cli -u "$URI" FT.INFO product_idx 2>/dev/null
} 2>&1 | tee "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
