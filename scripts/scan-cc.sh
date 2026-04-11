#!/bin/bash
# 兼容 zsh/bash：glob 无匹配时返回空而非报错
setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null
proj=$(ls -d ~/.claude/projects/$(echo "$(pwd)" | sed 's/[^a-zA-Z0-9]/-/g')* 2>/dev/null | head -1)

# Memory 文件列表
echo "=== MEMORY ==="
find "$proj/memory" -name "*.md" 2>/dev/null || echo "NONE"
echo "=== MEMINDEX ==="
test -f "$proj/MEMORY.md" && echo "$proj/MEMORY.md" || echo "NONE"

# .claude/ 内容
echo "=== DOTCLAUDE ==="
ls .claude/ 2>/dev/null || echo "NONE"

# Session transcripts（文件名 + 大小 + mtime 天数 + 前30行内容采样）
echo "=== SESSIONS ==="
now=$(date +%s)
find "$proj" -maxdepth 1 -name "*.jsonl" 2>/dev/null | while read f; do
  size=$(du -h "$f" | cut -f1)
  mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)
  age_days=$(( (now - mtime) / 86400 ))
  sample=$(head -30 "$f" 2>/dev/null | cut -c1-200 | tr '\n' ' ')
  echo "FILE:$f|SIZE:$size|AGE:${age_days}d|SAMPLE:$sample"
done

# Skills config
echo "=== SKILLS ==="
cat ~/.claude/settings.json 2>/dev/null || echo "NONE"

# Plugin cache
echo "=== CACHE ==="
find ~/.claude/plugins/cache -maxdepth 1 -type d 2>/dev/null | tail -n +2 | while read d; do
  name=$(basename "$d")
  size=$(du -sh "$d" 2>/dev/null | cut -f1)
  has_mp=$(test -d ~/.claude/plugins/marketplaces/$name && echo "dup" || echo "orphan")
  echo "$name|$size|$has_mp"
done
