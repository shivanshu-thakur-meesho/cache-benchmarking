#!/usr/bin/env bash
# Search Benchmark: Compatibility validation of all FT.* commands (standalone)
# Includes all tests from: https://www.dragonflydb.io/blog/announcing-dragonfly-search
# Tests each RediSearch command against Dragonfly and reports pass/fail
source "$(dirname "$0")/../../lib/config.sh"

# Disable strict error mode — this script expects some commands to fail
set +e
set +o pipefail

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
  result=$(redis-cli -u "$URI" "$@" 2>&1) || true
  local exit_code=$?

  if [[ $exit_code -eq 0 ]] && [[ ! "$result" =~ ERR|error|"unknown command"|"not supported" ]]; then
    printf "  %-55s ${GREEN}PASS${NC}\n" "$name"
    echo "  [PASS] $name" >> "$OUTFILE"
    echo "         Command: $*" >> "$OUTFILE"
    echo "         Result: $(echo "$result" | head -5)" >> "$OUTFILE"
    PASS=$((PASS + 1))
  else
    printf "  %-55s ${RED}FAIL${NC}\n" "$name"
    echo "  [FAIL] $name" >> "$OUTFILE"
    echo "         Command: $*" >> "$OUTFILE"
    echo "         Error: $(echo "$result" | head -5)" >> "$OUTFILE"
    FAIL=$((FAIL + 1))
  fi
  echo "" >> "$OUTFILE"
}

{
echo "# Dragonfly Search Compatibility Check"
echo "# URI: $URI"
echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "# Reference: https://www.dragonflydb.io/blog/announcing-dragonfly-search"
echo ""

# ═══════════════════════════════════════════════════════════════════
# SECTION 1: Blog Post Examples (Dragonfly Search Announcement)
# ═══════════════════════════════════════════════════════════════════

echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 1: Blog Post Examples (Dragonfly Announcement)${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}=== Setup: City Data (from blog) ===${NC}"
echo ""

# Exact data from the Dragonfly Search blog post
redis-cli -u "$URI" HSET "city:1" name London population 8.8 continent Europe 2>/dev/null
redis-cli -u "$URI" HSET "city:2" name Athens population 3.1 continent Europe 2>/dev/null
redis-cli -u "$URI" HSET "city:3" name Tel-Aviv population 1.3 continent Asia 2>/dev/null
redis-cli -u "$URI" HSET "city:4" name Hyderabad population 9.8 continent Asia 2>/dev/null

echo "City documents created (city:1 to city:4)."
echo ""

# Drop existing
redis-cli -u "$URI" FT.DROPINDEX cities 2>/dev/null || true

echo -e "${BOLD}--- FT.CREATE (blog example) ---${NC}"
echo ""

run_test "FT.CREATE cities (TEXT+NUMERIC SORTABLE+TAG)" \
  FT.CREATE cities PREFIX 1 "city:" SCHEMA name TEXT population NUMERIC SORTABLE continent TAG

sleep 2  # Let index build

echo ""
echo -e "${BOLD}--- FT.INFO (blog example) ---${NC}"
echo ""

run_test "FT.INFO cities" \
  FT.INFO cities

echo ""
echo -e "${BOLD}--- FT.SEARCH: Blog Query 1 ---${NC}"
echo "    European cities sorted by population DESC, return name+population"
echo ""

run_test "FT.SEARCH: tag + SORTBY + LIMIT + RETURN" \
  FT.SEARCH cities "@continent:{Europe}" SORTBY population DESC LIMIT 0 1 RETURN 2 name population

echo ""
echo -e "${BOLD}--- FT.SEARCH: Blog Query 2 ---${NC}"
echo "    Asian cities with population under 5M"
echo ""

run_test "FT.SEARCH: numeric range + tag + RETURN" \
  FT.SEARCH cities "@population:[0 5] @continent:{Asia}" RETURN 1 name

echo ""

# Clean up cities
redis-cli -u "$URI" FT.DROPINDEX cities 2>/dev/null || true
redis-cli -u "$URI" DEL "city:1" "city:2" "city:3" "city:4" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# SECTION 2: Vector Search (from blog - KNN similarity)
# ═══════════════════════════════════════════════════════════════════

echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 2: Vector Search (KNN Similarity)${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

# Create vector test data (4-dimensional vectors for simplicity)
# Simulating blog post embeddings with small vectors
redis-cli -u "$URI" HSET "vec:1" title "intro to redis" content "getting started with redis" embedding "$(printf '\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')" 2>/dev/null
redis-cli -u "$URI" HSET "vec:2" title "dragonfly basics" content "introduction to dragonfly db" embedding "$(printf '\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00')" 2>/dev/null
redis-cli -u "$URI" HSET "vec:3" title "search engines" content "building search with redis" embedding "$(printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x00\x00')" 2>/dev/null

redis-cli -u "$URI" FT.DROPINDEX vec_idx 2>/dev/null || true

echo -e "${BOLD}--- FT.CREATE with VECTOR field (FLAT) ---${NC}"
echo ""

run_test "FT.CREATE: VECTOR field (FLAT, 4 dims, FLOAT32)" \
  FT.CREATE vec_idx ON HASH PREFIX 1 "vec:" SCHEMA \
    title TEXT \
    content TEXT \
    embedding VECTOR FLAT 6 TYPE FLOAT32 DIM 4 DISTANCE_METRIC COSINE

sleep 2

echo ""
echo -e "${BOLD}--- FT.SEARCH: KNN Vector Similarity ---${NC}"
echo ""

# Query vector (4 floats = 16 bytes): [1.0, 0.0, 0.0, 0.0]
QUERY_VEC="$(printf '\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')"

run_test "FT.SEARCH: KNN vector search (top 2)" \
  FT.SEARCH vec_idx "*=>[KNN 2 @embedding \$query_vector AS vector_score]" PARAMS 2 query_vector "$QUERY_VEC" SORTBY vector_score ASC RETURN 2 title vector_score DIALECT 2

echo ""

run_test "FT.CREATE: VECTOR field (HNSW)" \
  FT.CREATE vec_hnsw_idx ON HASH PREFIX 1 "vec:" SCHEMA \
    title TEXT \
    embedding VECTOR HNSW 6 TYPE FLOAT32 DIM 4 DISTANCE_METRIC L2

sleep 1

run_test "FT.SEARCH: KNN with HNSW index" \
  FT.SEARCH vec_hnsw_idx "*=>[KNN 2 @embedding \$query_vector AS score]" PARAMS 2 query_vector "$QUERY_VEC" SORTBY score ASC DIALECT 2

echo ""

# Clean up vectors
redis-cli -u "$URI" FT.DROPINDEX vec_idx 2>/dev/null || true
redis-cli -u "$URI" FT.DROPINDEX vec_hnsw_idx 2>/dev/null || true
redis-cli -u "$URI" DEL "vec:1" "vec:2" "vec:3" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# SECTION 3: Comprehensive FT.CREATE Field Type Tests
# ═══════════════════════════════════════════════════════════════════

echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 3: Comprehensive FT.CREATE Field Type Tests${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

# Create rich test documents
redis-cli -u "$URI" HSET "compat:1" title "wireless headphones" description "noise cancelling bluetooth headphones" category "electronics" brand "acme" price 79.99 rating 4.5 stock 100 location "77.5,12.9" 2>/dev/null
redis-cli -u "$URI" HSET "compat:2" title "cotton tshirt blue" description "premium cotton casual wear" category "clothing" brand "globex" price 29.99 rating 4.2 stock 500 location "77.6,13.0" 2>/dev/null
redis-cli -u "$URI" HSET "compat:3" title "stainless steel water bottle" description "insulated bottle for outdoor use" category "home" brand "initech" price 19.99 rating 4.8 stock 250 location "77.55,12.95" 2>/dev/null

redis-cli -u "$URI" FT.DROPINDEX compat_idx 2>/dev/null || true

echo -e "${BOLD}--- FT.CREATE: All field types ---${NC}"
echo ""

run_test "FT.CREATE (TEXT+NUMERIC+TAG+GEO, WEIGHT)" \
  FT.CREATE compat_idx ON HASH PREFIX 1 "compat:" SCHEMA \
    title TEXT WEIGHT 5.0 \
    description TEXT \
    category TAG \
    brand TAG \
    price NUMERIC SORTABLE \
    rating NUMERIC SORTABLE \
    stock NUMERIC \
    location GEO

sleep 2

run_test "FT.CREATE: TEXT with NOSTEM" \
  FT.CREATE nostem_idx ON HASH PREFIX 1 "compat:" SCHEMA \
    title TEXT NOSTEM

sleep 1

run_test "FT.CREATE: TAG with custom SEPARATOR" \
  FT.CREATE tagsep_idx ON HASH PREFIX 1 "compat:" SCHEMA \
    category TAG SEPARATOR ";"

sleep 1

run_test "FT.CREATE: TEXT with SORTABLE" \
  FT.CREATE txtsort_idx ON HASH PREFIX 1 "compat:" SCHEMA \
    title TEXT SORTABLE

sleep 1

# Clean up extra indexes
redis-cli -u "$URI" FT.DROPINDEX nostem_idx 2>/dev/null || true
redis-cli -u "$URI" FT.DROPINDEX tagsep_idx 2>/dev/null || true
redis-cli -u "$URI" FT.DROPINDEX txtsort_idx 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════
# SECTION 4: FT.SEARCH — All Query Types
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 4: FT.SEARCH — All Query Types${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}--- Text Queries ---${NC}"
echo ""

run_test "FT.SEARCH: simple text" \
  FT.SEARCH compat_idx "headphones"

run_test "FT.SEARCH: field-specific text (@title)" \
  FT.SEARCH compat_idx "@title:cotton"

run_test "FT.SEARCH: field-specific text (@description)" \
  FT.SEARCH compat_idx "@description:bluetooth"

run_test "FT.SEARCH: multi-word text" \
  FT.SEARCH compat_idx "wireless headphones"

run_test "FT.SEARCH: prefix match" \
  FT.SEARCH compat_idx "head*"

run_test "FT.SEARCH: negation (-)" \
  FT.SEARCH compat_idx "-headphones"

run_test "FT.SEARCH: OR (|) operator" \
  FT.SEARCH compat_idx "headphones|tshirt"

echo ""
echo -e "${BOLD}--- Numeric Range Queries ---${NC}"
echo ""

run_test "FT.SEARCH: numeric range [10 50]" \
  FT.SEARCH compat_idx "@price:[10 50]"

run_test "FT.SEARCH: numeric range open-ended [50 +inf]" \
  FT.SEARCH compat_idx "@price:[50 +inf]"

run_test "FT.SEARCH: numeric range open-ended [-inf 30]" \
  FT.SEARCH compat_idx "@price:[-inf 30]"

run_test "FT.SEARCH: numeric exclusive range [(10 (80]" \
  FT.SEARCH compat_idx "@price:[(10 (80]"

echo ""
echo -e "${BOLD}--- Tag Queries ---${NC}"
echo ""

run_test "FT.SEARCH: single tag" \
  FT.SEARCH compat_idx "@category:{electronics}"

run_test "FT.SEARCH: multi-tag OR" \
  FT.SEARCH compat_idx "@category:{electronics|clothing}"

run_test "FT.SEARCH: tag + brand" \
  FT.SEARCH compat_idx "@brand:{acme}"

echo ""
echo -e "${BOLD}--- GEO Queries ---${NC}"
echo ""

run_test "FT.SEARCH: geo radius filter" \
  FT.SEARCH compat_idx "@location:[77.5 12.9 50 km]"

echo ""
echo -e "${BOLD}--- Combined / Boolean Queries ---${NC}"
echo ""

run_test "FT.SEARCH: text + numeric AND" \
  FT.SEARCH compat_idx "@title:headphones @price:[0 100]"

run_test "FT.SEARCH: tag + numeric AND" \
  FT.SEARCH compat_idx "@category:{electronics} @price:[0 100]"

run_test "FT.SEARCH: tag + numeric + text AND" \
  FT.SEARCH compat_idx "@category:{electronics} @price:[0 100] @title:wireless"

run_test "FT.SEARCH: tag + rating range" \
  FT.SEARCH compat_idx "@category:{home} @rating:[4 5]"

echo ""
echo -e "${BOLD}--- Query Options ---${NC}"
echo ""

run_test "FT.SEARCH: wildcard (*)" \
  FT.SEARCH compat_idx "*"

run_test "FT.SEARCH: NOCONTENT" \
  FT.SEARCH compat_idx "*" NOCONTENT

run_test "FT.SEARCH: SORTBY ASC" \
  FT.SEARCH compat_idx "*" SORTBY price ASC

run_test "FT.SEARCH: SORTBY DESC" \
  FT.SEARCH compat_idx "*" SORTBY price DESC

run_test "FT.SEARCH: LIMIT" \
  FT.SEARCH compat_idx "*" LIMIT 0 2

run_test "FT.SEARCH: LIMIT with offset" \
  FT.SEARCH compat_idx "*" LIMIT 1 2

run_test "FT.SEARCH: RETURN 1 field" \
  FT.SEARCH compat_idx "*" RETURN 1 title

run_test "FT.SEARCH: RETURN 2 fields" \
  FT.SEARCH compat_idx "*" RETURN 2 title price

run_test "FT.SEARCH: RETURN 0 (IDs only)" \
  FT.SEARCH compat_idx "*" RETURN 0

run_test "FT.SEARCH: SORTBY + LIMIT + RETURN" \
  FT.SEARCH compat_idx "*" SORTBY price ASC LIMIT 0 2 RETURN 2 title price

run_test "FT.SEARCH: HIGHLIGHT" \
  FT.SEARCH compat_idx "headphones" HIGHLIGHT FIELDS 1 title

run_test "FT.SEARCH: SUMMARIZE" \
  FT.SEARCH compat_idx "headphones" SUMMARIZE FIELDS 1 description

run_test "FT.SEARCH: DIALECT 2" \
  FT.SEARCH compat_idx "*" LIMIT 0 1 DIALECT 2

echo ""
echo -e "${BOLD}--- FT.SEARCH: PARAMS (parameterized queries) ---${NC}"
echo ""

run_test "FT.SEARCH: PARAMS with numeric" \
  FT.SEARCH compat_idx "@price:[0 \$maxprice]" PARAMS 2 maxprice 50 DIALECT 2

# ═══════════════════════════════════════════════════════════════════
# SECTION 5: FT.AGGREGATE — All Reduce Functions
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 5: FT.AGGREGATE — All Reduce Functions${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.AGGREGATE: GROUPBY + COUNT" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total

run_test "FT.AGGREGATE: GROUPBY + SUM" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @brand REDUCE SUM 1 @stock AS total_stock

run_test "FT.AGGREGATE: GROUPBY + AVG" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE AVG 1 @price AS avg_price

run_test "FT.AGGREGATE: GROUPBY + MIN" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE MIN 1 @price AS min_price

run_test "FT.AGGREGATE: GROUPBY + MAX" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE MAX 1 @price AS max_price

run_test "FT.AGGREGATE: GROUPBY + STDDEV" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE STDDEV 1 @price AS price_stddev

run_test "FT.AGGREGATE: GROUPBY + COUNT_DISTINCT" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT_DISTINCT 1 @brand AS unique_brands

run_test "FT.AGGREGATE: GROUPBY + COUNT_DISTINCTISH" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT_DISTINCTISH 1 @brand AS approx_brands

run_test "FT.AGGREGATE: GROUPBY + TOLIST" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE TOLIST 1 @title AS titles

run_test "FT.AGGREGATE: GROUPBY + FIRST_VALUE" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE FIRST_VALUE 1 @title AS first_title

run_test "FT.AGGREGATE: GROUPBY + RANDOM_SAMPLE" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE RANDOM_SAMPLE 1 @title 1 AS sample

run_test "FT.AGGREGATE: Multiple REDUCE functions" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category \
    REDUCE COUNT 0 AS total \
    REDUCE AVG 1 @price AS avg_price \
    REDUCE SUM 1 @stock AS total_stock

run_test "FT.AGGREGATE: SORTBY" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total SORTBY 2 @total DESC

run_test "FT.AGGREGATE: LIMIT" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total LIMIT 0 2

run_test "FT.AGGREGATE: APPLY (transform)" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE AVG 1 @price AS avg APPLY "upper(@category)" AS upper_cat

run_test "FT.AGGREGATE: FILTER" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total FILTER "@total > 0"

run_test "FT.AGGREGATE: with query filter" \
  FT.AGGREGATE compat_idx "@category:{electronics}" GROUPBY 1 @brand REDUCE COUNT 0 AS count

# ═══════════════════════════════════════════════════════════════════
# SECTION 6: Index Management Commands
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 6: Index Management Commands${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.INFO" \
  FT.INFO compat_idx

run_test "FT._LIST" \
  FT._LIST

run_test "FT.TAGVALS" \
  FT.TAGVALS compat_idx category

run_test "FT.TAGVALS: brand field" \
  FT.TAGVALS compat_idx brand

run_test "FT.ALTER: add TAG field" \
  FT.ALTER compat_idx SCHEMA ADD color TAG

run_test "FT.ALTER: add NUMERIC field" \
  FT.ALTER compat_idx SCHEMA ADD weight NUMERIC

run_test "FT.ALTER: add TEXT field" \
  FT.ALTER compat_idx SCHEMA ADD notes TEXT

# ═══════════════════════════════════════════════════════════════════
# SECTION 7: Configuration & Synonyms
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 7: Configuration & Synonyms${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.CONFIG SET TIMEOUT" \
  FT.CONFIG SET TIMEOUT 5000

run_test "FT.CONFIG GET TIMEOUT" \
  FT.CONFIG GET TIMEOUT

run_test "FT.CONFIG SET MAXSEARCHRESULTS" \
  FT.CONFIG SET MAXSEARCHRESULTS 10000

run_test "FT.CONFIG GET MAXSEARCHRESULTS" \
  FT.CONFIG GET MAXSEARCHRESULTS

run_test "FT.CONFIG GET *" \
  FT.CONFIG GET "*"

run_test "FT.SYNUPDATE: create synonym group" \
  FT.SYNUPDATE compat_idx syn1 headphones earphones earbuds

run_test "FT.SYNUPDATE: another synonym group" \
  FT.SYNUPDATE compat_idx syn2 tshirt shirt top

run_test "FT.SYNDUMP" \
  FT.SYNDUMP compat_idx

run_test "FT.SEARCH: with synonym (earphones -> headphones)" \
  FT.SEARCH compat_idx "earphones"

# ═══════════════════════════════════════════════════════════════════
# SECTION 8: Profiling
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 8: Profiling (FT.PROFILE)${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.PROFILE: SEARCH query" \
  FT.PROFILE compat_idx SEARCH QUERY "headphones"

run_test "FT.PROFILE: SEARCH with filter" \
  FT.PROFILE compat_idx SEARCH QUERY "@category:{electronics}"

run_test "FT.PROFILE: AGGREGATE query" \
  FT.PROFILE compat_idx AGGREGATE QUERY "*" GROUPBY 1 @category REDUCE COUNT 0 AS total

# ═══════════════════════════════════════════════════════════════════
# SECTION 9: Autocomplete (FT.SUGADD / FT.SUGGET)
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 9: Autocomplete (expected FAIL on Dragonfly)${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.SUGADD: add suggestion" \
  FT.SUGADD ac_idx "wireless headphones" 1.0

run_test "FT.SUGADD: add with payload" \
  FT.SUGADD ac_idx "bluetooth speaker" 0.8 PAYLOAD "audio"

run_test "FT.SUGGET: prefix lookup" \
  FT.SUGGET ac_idx "wire"

run_test "FT.SUGGET: with FUZZY" \
  FT.SUGGET ac_idx "wireles" FUZZY

run_test "FT.SUGGET: with WITHSCORES" \
  FT.SUGGET ac_idx "blue" WITHSCORES

run_test "FT.SUGGET: with WITHPAYLOADS" \
  FT.SUGGET ac_idx "blue" WITHPAYLOADS

run_test "FT.SUGLEN: suggestion count" \
  FT.SUGLEN ac_idx

run_test "FT.SUGDEL: delete suggestion" \
  FT.SUGDEL ac_idx "wireless headphones"

# ═══════════════════════════════════════════════════════════════════
# SECTION 10: JSON Document Support
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 10: JSON Document Support${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

redis-cli -u "$URI" JSON.SET "jdoc:1" '$' '{"title":"redis guide","price":49.99,"tags":["database","nosql"]}' 2>/dev/null
redis-cli -u "$URI" JSON.SET "jdoc:2" '$' '{"title":"dragonfly intro","price":29.99,"tags":["database","cache"]}' 2>/dev/null

redis-cli -u "$URI" FT.DROPINDEX json_idx 2>/dev/null || true

run_test "FT.CREATE: ON JSON with JSONPath" \
  FT.CREATE json_idx ON JSON PREFIX 1 "jdoc:" SCHEMA \
    '$.title' AS title TEXT \
    '$.price' AS price NUMERIC SORTABLE \
    '$.tags[*]' AS tags TAG

sleep 2

run_test "FT.SEARCH: JSON index text query" \
  FT.SEARCH json_idx "redis"

run_test "FT.SEARCH: JSON index numeric range" \
  FT.SEARCH json_idx "@price:[0 40]"

run_test "FT.SEARCH: JSON index tag filter" \
  FT.SEARCH json_idx "@tags:{database}"

# Clean up JSON
redis-cli -u "$URI" FT.DROPINDEX json_idx 2>/dev/null || true
redis-cli -u "$URI" DEL "jdoc:1" "jdoc:2" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# SECTION 11: Edge Cases & Advanced
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SECTION 11: Edge Cases & Advanced${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo ""

run_test "FT.SEARCH: empty result set" \
  FT.SEARCH compat_idx "nonexistentterm12345"

run_test "FT.SEARCH: LIMIT 0 0 (count only)" \
  FT.SEARCH compat_idx "*" LIMIT 0 0

run_test "FT.AGGREGATE: no GROUPBY (global reduce)" \
  FT.AGGREGATE compat_idx "*" REDUCE COUNT 0 AS total

run_test "FT.AGGREGATE: GROUPBY 2 fields" \
  FT.AGGREGATE compat_idx "*" GROUPBY 2 @category @brand REDUCE COUNT 0 AS total

run_test "FT.CREATE: multiple PREFIX (expected FAIL)" \
  FT.CREATE multi_pfx ON HASH PREFIX 2 "a:" "b:" SCHEMA title TEXT

redis-cli -u "$URI" FT.DROPINDEX multi_pfx 2>/dev/null || true

run_test "FT.SEARCH: WITHSCORES" \
  FT.SEARCH compat_idx "headphones" WITHSCORES

run_test "FT.SEARCH: EXPLAINSCORE" \
  FT.SEARCH compat_idx "headphones" EXPLAINSCORE

run_test "FT.EXPLAIN: query parse tree" \
  FT.EXPLAIN compat_idx "headphones"

run_test "FT.EXPLAINCLI: query parse tree (CLI)" \
  FT.EXPLAINCLI compat_idx "@category:{electronics} @price:[0 100]"

run_test "FT.CURSOR READ (after AGGREGATE)" \
  FT.AGGREGATE compat_idx "*" GROUPBY 1 @category REDUCE COUNT 0 AS total WITHCURSOR COUNT 1

# ═══════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}=== Cleanup ===${NC}"
echo ""

run_test "FT.DROPINDEX compat_idx" \
  FT.DROPINDEX compat_idx

redis-cli -u "$URI" DEL "compat:1" "compat:2" "compat:3" 2>/dev/null
redis-cli -u "$URI" DEL "ac_idx" 2>/dev/null

# ═══════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  SKIP: $SKIP"
echo -e "  Total: $((PASS+FAIL+SKIP)) tests"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo ""
echo "Known Dragonfly limitations (expected FAILs):"
echo "  - FT.SUGADD / FT.SUGGET / FT.SUGLEN / FT.SUGDEL (autocomplete)"
echo "  - FT.AGGREGATE APPLY / FILTER"
echo "  - FT.CREATE with multiple PREFIX"
echo "  - FT.EXPLAIN / FT.EXPLAINCLI"
echo "  - FT.CURSOR READ"
echo "  - JSON index support (may vary by version)"
} 2>&1 | tee -a "$OUTFILE"

echo -e "${GREEN}Output saved to: ${OUTFILE}${NC}"
