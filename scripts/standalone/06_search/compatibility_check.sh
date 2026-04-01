#!/usr/bin/env bash
# Search Benchmark: Compatibility validation of all FT.* commands (standalone)
# Tests each RediSearch command against Dragonfly and reports pass/fail
source "$(dirname "$0")/../../lib/config.sh"

prompt_uri

setup_result_dir
OUTFILE="$RESULTS_DIR/standalone_search_compatibility.txt"
mkdir -p "$RESULTS_DIR"

PASS=0
FAIL=0
SKIP=0

run_test() {
  local name="$1"
  shift
  local result
  result=$(redis-cli -u "$URI" "$@" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]] && ! echo "$result" | grep -qi "ERR\|error\|unknown command\|not supported"; then
    printf "  %-45s ${GREEN}PASS${NC}\n" "$name"
    echo "  [PASS] $name" >> "$OUTFILE"
    echo "         Command: $*" >> "$OUTFILE"
    echo "         Result: $(echo "$result" | head -3)" >> "$OUTFILE"
    ((PASS++))
  else
    printf "  %-45s ${RED}FAIL${NC}\n" "$name"
    echo "  [FAIL] $name" >> "$OUTFILE"
    echo "         Command: $*" >> "$OUTFILE"
    echo "         Error: $(echo "$result" | head -3)" >> "$OUTFILE"
    ((FAIL++))
  fi
  echo "" >> "$OUTFILE"
}

{
echo "# Dragonfly Search Compatibility Check"
echo "# URI: $URI"
echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

echo -e "${BOLD}=== Setup: Creating test data ===${NC}"
echo ""

# Create a few test documents
redis-cli -u "$URI" HSET "compat:1" title "wireless headphones" description "noise cancelling bluetooth headphones" category "electronics" brand "acme" price 79.99 rating 4.5 stock 100 location "77.5,12.9" 2>/dev/null
redis-cli -u "$URI" HSET "compat:2" title "cotton tshirt blue" description "premium cotton casual wear" category "clothing" brand "globex" price 29.99 rating 4.2 stock 500 location "77.6,13.0" 2>/dev/null
redis-cli -u "$URI" HSET "compat:3" title "stainless steel water bottle" description "insulated bottle for outdoor use" category "home" brand "initech" price 19.99 rating 4.8 stock 250 location "77.55,12.95" 2>/dev/null

echo "Test documents created."
echo ""

# Drop any existing test index
redis-cli -u "$URI" FT.DROPINDEX compat_idx 2>/dev/null || true

echo -e "${BOLD}=== FT.CREATE Tests ===${NC}"
echo ""

run_test "FT.CREATE (basic TEXT+NUMERIC+TAG+GEO)" \
  FT.CREATE compat_idx ON HASH PREFIX 1 "compat:" SCHEMA \
    title TEXT WEIGHT 5.0 \
    description TEXT \
    category TAG \
    brand TAG \
    price NUMERIC SORTABLE \
    rating NUMERIC SORTABLE \
    stock NUMERIC \
    location GEO

sleep 2  # Let index build

echo ""
echo -e "${BOLD}=== FT.SEARCH Tests ===${NC}"
echo ""

run_test "FT.SEARCH: simple text query" \
  FT.SEARCH compat_idx "headphones"

run_test "FT.SEARCH: field-specific text" \
  FT.SEARCH compat_idx "@title:cotton"

run_test "FT.SEARCH: numeric range" \
  FT.SEARCH compat_idx "@price:[10 50]"

run_test "FT.SEARCH: tag filter" \
  FT.SEARCH compat_idx "@category:{electronics}"

run_test "FT.SEARCH: multi-tag filter (OR)" \
  FT.SEARCH compat_idx "@category:{electronics|clothing}"

run_test "FT.SEARCH: boolean AND (text + numeric)" \
  FT.SEARCH compat_idx "@title:headphones @price:[0 100]"

run_test "FT.SEARCH: wildcard (*)" \
  FT.SEARCH compat_idx "*"

run_test "FT.SEARCH: NOCONTENT" \
  FT.SEARCH compat_idx "*" NOCONTENT

run_test "FT.SEARCH: SORTBY" \
  FT.SEARCH compat_idx "*" SORTBY price ASC

run_test "FT.SEARCH: LIMIT" \
  FT.SEARCH compat_idx "*" LIMIT 0 2

run_test "FT.SEARCH: RETURN specific fields" \
  FT.SEARCH compat_idx "*" RETURN 2 title price

echo ""
echo -e "${BOLD}=== FT.AGGREGATE Tests ===${NC}"
echo ""

run_test "FT.AGGREGATE: GROUPBY + COUNT" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total

run_test "FT.AGGREGATE: GROUPBY + AVG" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE AVG 1 @price AS avg_price

run_test "FT.AGGREGATE: GROUPBY + SUM" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @brand REDUCE SUM 1 @stock AS total_stock

run_test "FT.AGGREGATE: SORTBY" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total SORTBY 2 @total DESC

run_test "FT.AGGREGATE: LIMIT" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total LIMIT 0 2

echo ""
echo -e "${BOLD}=== FT.INFO / FT.ALTER / Management Tests ===${NC}"
echo ""

run_test "FT.INFO" \
  FT.INFO compat_idx

run_test "FT._LIST" \
  FT._LIST

run_test "FT.TAGVALS" \
  FT.TAGVALS compat_idx category

run_test "FT.ALTER (add field)" \
  FT.ALTER compat_idx SCHEMA ADD color TAG

run_test "FT.CONFIG SET" \
  FT.CONFIG SET TIMEOUT 5000

run_test "FT.CONFIG GET" \
  FT.CONFIG GET TIMEOUT

run_test "FT.SYNUPDATE (create synonym)" \
  FT.SYNUPDATE compat_idx syn1 headphones earphones earbuds

run_test "FT.SYNDUMP" \
  FT.SYNDUMP compat_idx

run_test "FT.PROFILE SEARCH" \
  FT.PROFILE compat_idx SEARCH QUERY "headphones"

echo ""
echo -e "${BOLD}=== FT.SUGADD / FT.SUGGET (Autocomplete) ===${NC}"
echo ""

run_test "FT.SUGADD (autocomplete)" \
  FT.SUGADD ac_idx "wireless headphones" 1.0

run_test "FT.SUGGET (autocomplete)" \
  FT.SUGGET ac_idx "wire"

echo ""
echo -e "${BOLD}=== Cleanup ===${NC}"
echo ""

run_test "FT.DROPINDEX" \
  FT.DROPINDEX compat_idx

# Clean up test data
redis-cli -u "$URI" DEL "compat:1" "compat:2" "compat:3" 2>/dev/null

echo ""
echo "════════════════════════════════════════════"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  SKIP: $SKIP"
echo "════════════════════════════════════════════"
echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped out of $((PASS+FAIL+SKIP)) tests"
} 2>&1 | tee -a "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
