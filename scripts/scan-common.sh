#!/bin/bash
# auto-shit-skill: 通用采集脚本（Plans/Specs + Git/Worktrees）
# 跨平台通用，不涉及 Claude Code 或 OpenClaw 特定路径

setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null

# Plans/Specs（列文件名 + 首行标题）
echo "=== PLANS ==="
find docs/superpowers/specs docs/superpowers/plans -name "*.md" 2>/dev/null | while read f; do
  title=$(head -3 "$f" | grep -m1 "^#" || echo "(无标题)")
  echo "FILE:$f|TITLE:$title"
done

# Git + Worktrees
echo "=== GIT ==="
git rev-parse --is-inside-work-tree 2>/dev/null && git worktree list 2>/dev/null || echo "NOT_GIT"

echo "=== DONE ==="
