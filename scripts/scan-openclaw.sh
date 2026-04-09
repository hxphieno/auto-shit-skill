#!/bin/bash
# auto-shit-skill: OpenClaw 平台状态采集脚本
# 采集 OpenClaw 环境的内存、会话、扩展、日志、Cron、Legacy、Lock 信息

setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null

OC_STATE="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

# === MEMORY ===
echo "=== MEMORY ==="
find "$OC_STATE/workspace/memory" -name "*.md" 2>/dev/null || echo "NONE"
find "$OC_STATE"/workspace-*/memory -name "*.md" 2>/dev/null

# === MEMINDEX ===
echo "=== MEMINDEX ==="
test -f "$OC_STATE/workspace/MEMORY.md" && echo "$OC_STATE/workspace/MEMORY.md" || echo "NONE"

# === SESSIONS ===
echo "=== SESSIONS ==="
now=$(date +%s)
_scan_sessions() {
  local f="$1"
  [ -f "$f" ] || return
  size=$(du -h "$f" | cut -f1)
  mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
  age_days=$(( (now - mtime) / 86400 ))
  sample=$(head -c 120 "$f" 2>/dev/null | tr '\n' ' ')
  echo "FILE:$f|SIZE:$size|AGE:${age_days}d|SAMPLE:$sample"
}
found_sessions=0
for f in "$OC_STATE"/agents/*/sessions/*.jsonl; do
  _scan_sessions "$f"
  found_sessions=1
done
for f in "$OC_STATE/workspace/.openclaw/sessions/"*.jsonl; do
  _scan_sessions "$f"
  found_sessions=1
done
for f in "$OC_STATE"/workspace-*/.openclaw/sessions/*.jsonl; do
  _scan_sessions "$f"
  found_sessions=1
done
[ "$found_sessions" -eq 0 ] && echo "NONE"

# === EXTENSIONS ===
echo "=== EXTENSIONS ==="
cat "$OC_STATE/openclaw.json" 2>/dev/null || echo "NONE"

# === LOGS ===
echo "=== LOGS ==="
LOGS_DIR="$OC_STATE/logs"
if [ -d "$LOGS_DIR" ]; then
  now_logs=$(date +%s)
  found_logs=0
  for f in "$LOGS_DIR"/*.log "$LOGS_DIR"/*.err.log "$LOGS_DIR"/*.jsonl; do
    [ -f "$f" ] || continue
    size=$(du -h "$f" | cut -f1)
    mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
    age_days=$(( (now_logs - mtime) / 86400 ))
    echo "FILE:$f|SIZE:$size|AGE:${age_days}d"
    found_logs=1
  done
  [ "$found_logs" -eq 0 ] && echo "NONE"
else
  echo "NONE"
fi

# === CRON_RUNS ===
echo "=== CRON_RUNS ==="
CRON_RUNS_DIR="$OC_STATE/cron/runs"
CRON_JOBS_FILE="$OC_STATE/cron/jobs.json"
if [ -d "$CRON_RUNS_DIR" ]; then
  found_cron=0
  for f in "$CRON_RUNS_DIR"/*.jsonl; do
    [ -f "$f" ] || continue
    size=$(du -h "$f" | cut -f1)
    fname=$(basename "$f" .jsonl)
    if [ -f "$CRON_JOBS_FILE" ] && command -v jq >/dev/null 2>&1; then
      job_exists=$(jq -r --arg id "$fname" 'if type=="array" then .[] | select(.id==$id) elif type=="object" then .[$id] else empty end' "$CRON_JOBS_FILE" 2>/dev/null | head -1)
    else
      job_exists=""
    fi
    if [ -n "$job_exists" ]; then
      status="JOB_EXISTS"
    else
      status="JOB_MISSING"
    fi
    echo "FILE:$f|SIZE:$size|JOB_ID:$fname|STATUS:$status"
    found_cron=1
  done
  [ "$found_cron" -eq 0 ] && echo "NONE"
else
  echo "NONE"
fi

# === LEGACY ===
echo "=== LEGACY ==="
if [ -d ~/.clawdbot ] && [ -d "$OC_STATE" ]; then
  echo "BOTH"
elif [ -d ~/.clawdbot ]; then
  echo "LEGACY_ONLY"
else
  echo "NONE"
fi

# === LOCK ===
echo "=== LOCK ==="
lockdir="/tmp/openclaw-$(id -u)"
if [ -d "$lockdir" ]; then
  found_lock=0
  for f in "$lockdir"/gateway.*.lock; do
    [ -f "$f" ] || continue
    pid=$(cat "$f" 2>/dev/null | jq -r .pid 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "LOCK_ACTIVE:$f:$pid"
    else
      configPath=$(cat "$f" 2>/dev/null | jq -r .configPath 2>/dev/null)
      echo "LOCK_STALE:$f:$pid:$configPath"
    fi
    found_lock=1
  done
  [ "$found_lock" -eq 0 ] && echo "NONE"
else
  echo "NONE"
fi
