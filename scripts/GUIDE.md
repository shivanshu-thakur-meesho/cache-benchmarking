# Dragonfly BYOC Benchmark Suite - Usage Guide

## Prerequisites

- **Docker** installed and running on the benchmark VM
- **redis-cli** installed (for bloom filter and backup commands)
- **memtier_benchmark** Docker image: `redislabs/memtier_benchmark:latest`
- Network connectivity to the Dragonfly instance

Pull the memtier image before starting:

```bash
docker pull redislabs/memtier_benchmark:latest
```

---

## Quick Start

### 1. Launch the Interactive CLI

```bash
bash scripts/run.sh
```

This opens a menu-driven interface:

```
  ╔══════════════════════════════════════════════════╗
  ║       Dragonfly BYOC Benchmark Suite             ║
  ╚══════════════════════════════════════════════════╝

Select deployment mode:

  1) Standalone
  2) Cluster
  3) Generate report from existing results
  0) Exit
```

Pick a mode, then select the specific test to run. Each test will prompt you for configuration.

### 2. Configure Parameters

Every test prompts for these parameters with **sensible defaults** (press Enter to accept):

```
Connection
  URI: redis://your-host:6379

Benchmark Parameters (press Enter for default)
  pipeline        [1]:
  key-minimum     [1]:
  key-maximum     [2000000]:
  key-pattern     [R:R]:
  data-size       [256]:
  test-time       [60]:
```

Defaults vary per test (e.g., backup fill uses `pipeline=10, data-size=1024, test-time=1200`).

### 3. View Results & Generate Report

After tests finish, select **option 3** from the main menu to generate a markdown report from captured results.

---

## Running Scripts Directly

Each test can be run standalone without the CLI menu.

### Basic usage

```bash
bash scripts/standalone/01_inmemory/set.sh
# Will prompt for URI and all parameters interactively
```

### Pre-set URI

```bash
URI="redis://your-host:6379" bash scripts/standalone/01_inmemory/set.sh
# Skips the URI prompt, still asks for other params
```

### Fully non-interactive (all via env vars)

```bash
URI="redis://your-host:6379" \
PIPELINE=1 \
KEY_MINIMUM=1 \
KEY_MAXIMUM=2000000 \
KEY_PATTERN="R:R" \
DATA_SIZE=256 \
TEST_TIME=60 \
bash scripts/standalone/01_inmemory/set.sh
```

Any parameter set via env var is used directly (no prompt). Unset parameters will be prompted interactively.

---

## Directory Structure

```
scripts/
├── run.sh                          # Main CLI entry point
├── lib/
│   ├── config.sh                   # Interactive config & output capture
│   └── report.sh                   # Result parser & report generator
│
├── standalone/
│   ├── 01_inmemory/
│   │   ├── set.sh                  # SET benchmark
│   │   ├── get.sh                  # GET benchmark
│   │   ├── mget_20.sh             # mGET 20 keys/batch
│   │   ├── mget_50.sh             # mGET 50 keys/batch
│   │   └── mget_100.sh            # mGET 100 keys/batch
│   │
│   ├── 02_backup/
│   │   ├── fill_string_data.sh    # Fill with 1KB strings
│   │   ├── get_under_load.sh      # GET load (trigger BGSAVE mid-test)
│   │   ├── fill_bloomfilter.sh    # Create & fill 10 bloom filters
│   │   └── bf_mexists_load.sh     # BF.MEXISTS parallel on 10 BFs
│   │
│   ├── 03_ssd/
│   │   ├── fill_data.sh           # Fill with 2KB values
│   │   ├── get.sh                 # GET benchmark
│   │   ├── mget_20.sh             # mGET 20 keys/batch
│   │   ├── mget_50.sh             # mGET 50 keys/batch
│   │   └── mget_100.sh            # mGET 100 keys/batch
│   │
│   ├── 04_ha_recovery/
│   │   └── set_get_mixed.sh       # 1:1 SET/GET (kill master mid-test)
│   │
│   ├── 05_eviction/
│   │   ├── baseline.sh            # Baseline 256B, 60s
│   │   ├── stress_2k.sh           # Eviction stress 2KB, 300s
│   │   └── stress_4k.sh           # Eviction stress 4KB, 300s
│   │
│   └── 06_search/
│       ├── populate_data.sh       # Load 100K product docs
│       ├── create_index.sh        # FT.CREATE + measure index build
│       ├── compatibility_check.sh # Test all FT.* commands (PASS/FAIL)
│       ├── bench_text_search.sh   # FT.SEARCH text queries via memtier
│       ├── bench_filter_search.sh # FT.SEARCH filters via memtier
│       └── bench_aggregate.sh     # FT.AGGREGATE via memtier
│
├── cluster/
│   ├── 01_inmemory/
│   │   ├── set.sh                 # SET (with --cluster-mode)
│   │   └── get.sh                 # GET (with --cluster-mode)
│   │
│   ├── 02_backup/
│   │   ├── fill_string_data.sh    # Fill strings (cluster)
│   │   ├── get_under_load.sh      # GET + BGSAVE (cluster)
│   │   ├── fill_bloomfilter.sh    # BF fill (cluster)
│   │   └── bf_exists_load.sh      # BF.EXISTS parallel (cluster)
│   │
│   ├── 04_ha_recovery/
│   │   └── set_get_mixed.sh       # 1:1 SET/GET (cluster HA)
│   │
│   ├── 05_eviction/
│   │   ├── baseline.sh
│   │   ├── stress_2k.sh
│   │   └── stress_4k.sh
│   │
│   └── 06_search/
│       ├── populate_data.sh       # Load docs (cluster, uses -c flag)
│       ├── create_index.sh        # FT.CREATE (cluster)
│       ├── compatibility_check.sh # Reuses standalone check
│       ├── bench_text_search.sh   # FT.SEARCH (cluster-mode)
│       ├── bench_filter_search.sh # FT.SEARCH filters (cluster-mode)
│       └── bench_aggregate.sh     # FT.AGGREGATE (cluster-mode)
│
└── results/                        # Auto-created per run
    └── 20260401_143022/            # Timestamped directory
        ├── standalone_inmemory_set.txt
        ├── standalone_inmemory_get.txt
        ├── ...
        └── benchmark_report.md     # Generated report
```

---

## Test Scenarios & Execution Order

### 1. In-Memory Performance Validation

**Goal:** Baseline P99 performance and throughput at ~500K ops/sec.

| # | Script | Default Data Size | Default Time |
|---|--------|-------------------|--------------|
| 1 | `standalone/01_inmemory/set.sh` | 256B | 60s |
| 2 | `standalone/01_inmemory/get.sh` | 256B | 60s |
| 3 | `standalone/01_inmemory/mget_20.sh` | 256B | 60s |
| 4 | `standalone/01_inmemory/mget_50.sh` | 256B | 60s |
| 5 | `standalone/01_inmemory/mget_100.sh` | 256B | 60s |

Repeat with `cluster/01_inmemory/` for cluster mode. Note: mGET is not supported in cluster mode due to cross-slot key restrictions.

### 2. Backup Under Load Validation

**Goal:** Validate no severe P99 spike or throughput drop during backup.

**String data scenario:**

```bash
# Step 1: Fill the cache
bash scripts/standalone/02_backup/fill_string_data.sh

# Step 2: Run GET load
bash scripts/standalone/02_backup/get_under_load.sh
# In another terminal, trigger backup:
#   redis-cli -u "redis://host:6379" BGSAVE
```

**Bloom filter scenario:**

```bash
# Step 1: Fill bloom filters
bash scripts/standalone/02_backup/fill_bloomfilter.sh

# Step 2: Run BF.MEXISTS load + trigger backup
bash scripts/standalone/02_backup/bf_mexists_load.sh
# In another terminal:
#   redis-cli -u "redis://host:6379" BGSAVE
```

> **Warning:** Bloom filter backups cause 100-250% RSS increase. On instances with >60% memory usage, this can lead to data loss. Test with sufficient headroom.

### 3. SSD Mode Validation

**Goal:** Measure P99 latency delta vs pure in-memory mode at ~150K ops/sec.

```bash
# Step 1: Fill data (takes ~25 min with default 1500s)
bash scripts/standalone/03_ssd/fill_data.sh

# Step 2: Run read benchmarks
bash scripts/standalone/03_ssd/get.sh
bash scripts/standalone/03_ssd/mget_20.sh
bash scripts/standalone/03_ssd/mget_50.sh
bash scripts/standalone/03_ssd/mget_100.sh
```

### 4. HA Recovery Validation

**Goal:** Measure failover time, P99 spike, and recovery behavior.

```bash
# Start mixed load
bash scripts/standalone/04_ha_recovery/set_get_mixed.sh

# Mid-test: kill the master node (VM stop or systemctl stop dragonfly.service)
# Observe: reconnection time, error duration, P99 spike
```

Repeat with `cluster/04_ha_recovery/` for cluster mode.

### 5. Eviction Mode Validation

**Goal:** Validate no OOM under memory pressure, predictable eviction.

```bash
# Step 1: Baseline (256B, normal mode)
bash scripts/standalone/05_eviction/baseline.sh

# Step 2: Increase data size to trigger eviction
bash scripts/standalone/05_eviction/stress_2k.sh

# Step 3: Further increase for heavier eviction
bash scripts/standalone/05_eviction/stress_4k.sh
```

Compare P99/P999 across the three runs.

### 6. Search (FT.*) Validation

**Goal:** Validate RediSearch compatibility and search performance on Dragonfly.

This tests FT.CREATE, FT.SEARCH, FT.AGGREGATE and other FT.* commands to ensure clusters using Redis Search can be migrated to Dragonfly.

**Step-by-step:**

```bash
# Step 1: Populate test data (100K e-commerce product docs with TEXT/NUMERIC/TAG/GEO fields)
bash scripts/standalone/06_search/populate_data.sh

# Step 2: Create the search index and measure index build time
bash scripts/standalone/06_search/create_index.sh

# Step 3: Run compatibility check (tests every FT.* command, reports PASS/FAIL)
bash scripts/standalone/06_search/compatibility_check.sh

# Step 4: Benchmark FT.SEARCH text queries (simple, field-specific, wildcard)
bash scripts/standalone/06_search/bench_text_search.sh

# Step 5: Benchmark FT.SEARCH with filters (numeric range, tag, combined, sorted, NOCONTENT)
bash scripts/standalone/06_search/bench_filter_search.sh

# Step 6: Benchmark FT.AGGREGATE (GROUPBY+COUNT, GROUPBY+AVG, GROUPBY+SUM)
bash scripts/standalone/06_search/bench_aggregate.sh
```

Or run everything at once via the CLI menu (option 28 for standalone, 19 for cluster).

**What the compatibility check validates:**

| Category | Commands Tested |
|----------|-----------------|
| Index Management | FT.CREATE, FT.DROPINDEX, FT.ALTER, FT.INFO, FT._LIST |
| Text Search | Simple text, field-specific, boolean AND |
| Filters | Numeric range, tag filter, multi-tag OR |
| Query Options | NOCONTENT, SORTBY, LIMIT, RETURN |
| Aggregation | GROUPBY + COUNT/AVG/SUM, SORTBY, LIMIT |
| Config | FT.CONFIG SET/GET |
| Synonyms | FT.SYNUPDATE, FT.SYNDUMP |
| Profiling | FT.PROFILE SEARCH |
| Autocomplete | FT.SUGADD, FT.SUGGET (expected to FAIL on Dragonfly) |

**Known Dragonfly limitations:**
- FT.SUGADD / FT.SUGGET (autocomplete) -- not supported
- FT.AGGREGATE APPLY / FILTER -- not supported
- Multiple PREFIX in FT.CREATE -- only `PREFIX 1` supported
- Full-text scoring/relevance ranking -- limited

**Throughput benchmarks use memtier** with `--command` flag to send FT.SEARCH and FT.AGGREGATE queries. This gives Ops/sec and P99/P99.9 latency. memtier works well for fixed query patterns but cannot randomize search terms within queries.

---

## Generating the Report

After running benchmarks, generate a consolidated report:

### Via CLI menu

```bash
bash scripts/run.sh
# Select option 3 → pick the results directory → report is generated
```

### Directly

```bash
bash scripts/lib/report.sh results/20260401_143022/
```

Output: `results/20260401_143022/benchmark_report.md`

The report contains:
- Tables with Ops/sec, P99, P99.9, Avg Latency for each test
- Organized by test scenario (In-Memory, Backup, SSD, HA, Eviction)
- Separated by deployment mode (Standalone vs Cluster)
- Appendix with exact commands used

---

## Sharing Results Across Runs

All results within a single `bash scripts/run.sh` session go into the same timestamped directory. If you exit and re-enter, a new directory is created.

To merge results or use a custom output directory:

```bash
RESULTS_DIR="/path/to/my/results" bash scripts/standalone/01_inmemory/set.sh
```

---

## Tips

- **Bloom filter tests** need `redis-cli` installed on the benchmark VM (not in Docker)
- **Cluster mGET** is not available — Redis cluster requires all keys in a single command to hash to the same slot
- **SSD tests** use fewer threads/clients (2 threads, 3 clients) to match the expected ~150K ops target
- **Backup tests** require a second terminal to trigger `BGSAVE` at the right moment
- When running "all" tests from the menu (e.g., option 6 for all in-memory), the URI and config are prompted once per sub-test — pre-set them via env vars to avoid repeated prompts:
  ```bash
  URI="redis://host:6379" bash scripts/run.sh
  ```
