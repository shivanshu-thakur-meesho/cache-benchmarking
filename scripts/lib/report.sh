#!/usr/bin/env bash
# Report generator - parses memtier output files and generates a markdown report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Parse a single memtier result file ───────────────────────────────
# Extracts: Ops/sec, P99, P99.9, Hits, Misses
parse_result() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "FILE_NOT_FOUND"
    return
  fi

  local ops p99 p999 avg_latency

  # Try to extract from the TOTALS line (last summary)
  # memtier format: Type Ops/sec Hits/sec Misses/sec Avg. Latency p50 Latency p99 Latency p99.9 Latency KB/sec
  ops=$(grep -E "^Totals" "$file" | tail -1 | awk '{print $2}' || echo "N/A")
  avg_latency=$(grep -E "^Totals" "$file" | tail -1 | awk '{print $5}' || echo "N/A")
  p99=$(grep -E "^Totals" "$file" | tail -1 | awk '{print $7}' || echo "N/A")
  p999=$(grep -E "^Totals" "$file" | tail -1 | awk '{print $8}' || echo "N/A")

  # If no Totals line, try alternate patterns
  if [[ -z "$ops" || "$ops" == "N/A" ]]; then
    ops=$(grep -oP 'ops/sec:\s*\K[\d.]+' "$file" | tail -1 || echo "N/A")
  fi

  echo "${ops}|${p99}|${p999}|${avg_latency}"
}

# ── Generate full report ─────────────────────────────────────────────
generate_report() {
  local results_dir="$1"
  local report_file="${results_dir}/benchmark_report.md"

  if [[ ! -d "$results_dir" ]]; then
    echo "Results directory not found: $results_dir"
    exit 1
  fi

  echo -e "${BOLD}Generating benchmark report...${NC}"

  cat > "$report_file" << 'HEADER'
# Dragonfly BYOC Benchmark Report

**Generated:** REPORT_DATE
**Results Directory:** RESULTS_PATH

---

HEADER

  # Replace placeholders
  sed -i'' -e "s|REPORT_DATE|$(date '+%Y-%m-%d %H:%M:%S %Z')|" "$report_file"
  sed -i'' -e "s|RESULTS_PATH|${results_dir}|" "$report_file"

  # ── In-Memory Standalone ──
  if ls "$results_dir"/standalone_inmemory_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
## 1. In-Memory Performance Validation

### Standalone

| Command | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|---------|---------|----------|------------|-------------------|
EOF
    for test_file in "$results_dir"/standalone_inmemory_*.txt; do
      local name=$(basename "$test_file" .txt | sed 's/standalone_inmemory_//')
      local data=$(parse_result "$test_file")
      IFS='|' read -r ops p99 p999 avg <<< "$data"
      echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
    done
    echo "" >> "$report_file"
  fi

  # ── In-Memory Cluster ──
  if ls "$results_dir"/cluster_inmemory_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
### Cluster

| Command | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|---------|---------|----------|------------|-------------------|
EOF
    for test_file in "$results_dir"/cluster_inmemory_*.txt; do
      local name=$(basename "$test_file" .txt | sed 's/cluster_inmemory_//')
      local data=$(parse_result "$test_file")
      IFS='|' read -r ops p99 p999 avg <<< "$data"
      echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
    done
    echo "" >> "$report_file"
  fi

  # ── Backup Standalone ──
  if ls "$results_dir"/standalone_backup_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
---

## 2. Backup Under Load Validation

### Standalone

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
    for test_file in "$results_dir"/standalone_backup_*.txt; do
      local name=$(basename "$test_file" .txt | sed 's/standalone_backup_//')
      local data=$(parse_result "$test_file")
      IFS='|' read -r ops p99 p999 avg <<< "$data"
      echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
    done
    echo "" >> "$report_file"
  fi

  # ── Backup Cluster ──
  if ls "$results_dir"/cluster_backup_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
### Cluster

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
    for test_file in "$results_dir"/cluster_backup_*.txt; do
      local name=$(basename "$test_file" .txt | sed 's/cluster_backup_//')
      local data=$(parse_result "$test_file")
      IFS='|' read -r ops p99 p999 avg <<< "$data"
      echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
    done
    echo "" >> "$report_file"
  fi

  # ── SSD ──
  if ls "$results_dir"/standalone_ssd_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
---

## 3. SSD Mode Validation

### Standalone

| Command | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|---------|---------|----------|------------|-------------------|
EOF
    for test_file in "$results_dir"/standalone_ssd_*.txt; do
      local name=$(basename "$test_file" .txt | sed 's/standalone_ssd_//')
      local data=$(parse_result "$test_file")
      IFS='|' read -r ops p99 p999 avg <<< "$data"
      echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
    done
    echo "" >> "$report_file"
  fi

  # ── HA Recovery ──
  if ls "$results_dir"/standalone_ha_* 1>/dev/null 2>&1 || ls "$results_dir"/cluster_ha_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
---

## 4. HA Recovery Validation

EOF
    if ls "$results_dir"/standalone_ha_* 1>/dev/null 2>&1; then
      cat >> "$report_file" << 'EOF'
### Standalone

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
      for test_file in "$results_dir"/standalone_ha_*.txt; do
        local name=$(basename "$test_file" .txt | sed 's/standalone_ha_//')
        local data=$(parse_result "$test_file")
        IFS='|' read -r ops p99 p999 avg <<< "$data"
        echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
      done
      echo "" >> "$report_file"
    fi

    if ls "$results_dir"/cluster_ha_* 1>/dev/null 2>&1; then
      cat >> "$report_file" << 'EOF'
### Cluster

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
      for test_file in "$results_dir"/cluster_ha_*.txt; do
        local name=$(basename "$test_file" .txt | sed 's/cluster_ha_//')
        local data=$(parse_result "$test_file")
        IFS='|' read -r ops p99 p999 avg <<< "$data"
        echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
      done
      echo "" >> "$report_file"
    fi
  fi

  # ── Eviction ──
  if ls "$results_dir"/standalone_eviction_* 1>/dev/null 2>&1 || ls "$results_dir"/cluster_eviction_* 1>/dev/null 2>&1; then
    cat >> "$report_file" << 'EOF'
---

## 5. Eviction Mode Validation

EOF
    if ls "$results_dir"/standalone_eviction_* 1>/dev/null 2>&1; then
      cat >> "$report_file" << 'EOF'
### Standalone

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
      for test_file in "$results_dir"/standalone_eviction_*.txt; do
        local name=$(basename "$test_file" .txt | sed 's/standalone_eviction_//')
        local data=$(parse_result "$test_file")
        IFS='|' read -r ops p99 p999 avg <<< "$data"
        echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
      done
      echo "" >> "$report_file"
    fi

    if ls "$results_dir"/cluster_eviction_* 1>/dev/null 2>&1; then
      cat >> "$report_file" << 'EOF'
### Cluster

| Scenario | Ops/sec | P99 (ms) | P99.9 (ms) | Avg Latency (ms) |
|----------|---------|----------|------------|-------------------|
EOF
      for test_file in "$results_dir"/cluster_eviction_*.txt; do
        local name=$(basename "$test_file" .txt | sed 's/cluster_eviction_//')
        local data=$(parse_result "$test_file")
        IFS='|' read -r ops p99 p999 avg <<< "$data"
        echo "| ${name} | ${ops} | ${p99} | ${p999} | ${avg} |" >> "$report_file"
      done
      echo "" >> "$report_file"
    fi
  fi

  # ── Appendix: Commands Used ──
  cat >> "$report_file" << 'EOF'
---

## Appendix: Commands Used

EOF
  for test_file in "$results_dir"/*.txt; do
    local name=$(basename "$test_file" .txt)
    echo "### ${name}" >> "$report_file"
    echo '```bash' >> "$report_file"
    grep -A1 "^# Command:" "$test_file" | tail -1 >> "$report_file" 2>/dev/null || echo "N/A" >> "$report_file"
    echo '```' >> "$report_file"
    echo "" >> "$report_file"
  done

  echo -e "${GREEN}Report generated: ${report_file}${NC}"
  echo "$report_file"
}

# Allow direct invocation: ./report.sh /path/to/results
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <results_directory>"
    echo "  Generates benchmark_report.md from memtier output files"
    exit 1
  fi
  generate_report "$1"
fi
