---
name: auto-shit
description: Use when the user wants to clean up Claude Code's environment — stale memory entries, expired .claude/ directory artifacts, ghost skill configs, abandoned worktrees, outdated plan documents, or unrelated project debris. Also triggers on "该拉屎了", "shit", "拉屎", "冲水", "flush", "便秘了", "堵了", "大扫除", "全冲", "定点拉屎", "别拉了", "查异物", "扫残留".
---

# auto-shit — Claude Code 环境卫生

清理 Claude Code 在工作过程中积累的认知与环境垃圾。只扫描和清理 CC 自身环境，不碰用户代码。

---

## 触发词路由

### 快速体检（只扫描不动手）

**触发词：** `该拉屎了` / `shit` / `拉屎` / `auto-shit`

执行内容级扫描，覆盖所有维度，输出摘要和建议，不修改任何文件。

**核心原则：读内容做相关性判断，不只统计体积。** 体积信息作为辅助展示，主要输出是内容摘要和清理建议。

**第一步：用单个 Bash 收集文件清单（用户只需 allow 一次）：**

**注意：** 脚本必须兼容 zsh 和 bash。zsh 的 `nomatch` 选项会在 glob 无匹配时报错退出，必须在脚本开头禁用。所有 `ls *.md` 类操作都加 `2>/dev/null` 防止报错。确保脚本一次执行成功，不要出现失败重试。

```bash
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

# Session transcripts（只列文件名 + 大小 + 首行内容预览）
echo "=== SESSIONS ==="
find "$proj" -maxdepth 1 -name "*.jsonl" 2>/dev/null | while read f; do
  size=$(du -h "$f" | cut -f1)
  preview=$(head -1 "$f" 2>/dev/null | cut -c1-200)
  echo "FILE:$f|SIZE:$size|PREVIEW:$preview"
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
```

**第二步：读取内容做相关性判断。** 基于第一步的文件清单：

1. **Memory**：如果有 memory 文件，用 Read 逐个读取内容。判断每条 memory 是否与当前项目相关——提到了不存在的项目？记录了过时的偏好？与其他条目矛盾？输出每条的内容摘要和判断。
2. **Sessions**：从第一步的 PREVIEW 字段判断每个 session 的话题。如果话题明显与当前工作无关（如讨论另一个项目的 bug），标记为可清理。不需要读完整 JSONL。
3. **Plans/Specs**：从标题和日期判断是否过时。如果日期很旧且标题涉及已完成的功能，标记为可归档。
4. **Skills**：读 settings.json 内容，检查路径有效性和 MCP server 配置。
5. **.claude/**：读 settings.local.json 内容，检查是否有冗余或冲突配置。
6. **Plugin Cache**：从第一步结果直接判断重复/孤儿。
7. **Worktrees**：从第一步结果直接判断。

**输出格式：** 按 `style.md` 中的模板生成报告，替换 `{N}`、`{X}` 等占位符。每项标注 ✓（相关）或 ✗（建议清理）。清单为空时输出 style.md 中定义的"环境干净"回复。

**清单交互规则：**
- 体检完成后，自动将所有标记为 ✗ 的项目汇总为「建议清理清单」，带编号
- 用户说"冲水"→ 直接清理清单内所有项目，不再逐条确认
- 用户说"去掉 2"或"保留 def456"→ 从清单中移除该项，然后等待用户说"冲水"
- 用户说"加上 xxx"→ 将指定项目加入清单
- 用户说"只冲 1 和 3"→ 只清理指定编号
- 清单为空时输出：「环境干净，不用冲水。」

---

### 执行清理

**触发词：** `冲水` / `flush`

询问用户要清理哪个模块，然后 Read 对应的 `modules/` 文件并按其指令执行：

| 用户说 | 动作 |
|--------|------|
| 冲 memory / 清记忆 | Read `modules/flush-memory.md` |
| 冲 .claude / 清项目垃圾 | Read `modules/flush-dot-claude.md` |
| 冲 plans / 清旧文档 | Read `modules/flush-plans.md` |
| 冲 skills / 清废弃工具 | Read `modules/flush-skills.md` |
| 冲 worktrees | Read `modules/flush-worktrees.md` |
| 查异物 / 扫残留 | Read `modules/scan-debris.md` |

模块执行完毕后，输出提示：「冲完了。运行 `/compact` 让改动立即生效，继续当前对话；或开新对话效果相同。」

---

### 详细诊断

**触发词：** `便秘了` / `堵了` / `体检` / `scan`

Read `modules/scan-context.md` 并按其指令执行深度诊断。

---

### 全量清理

**触发词：** `大扫除` / `全冲`

按顺序执行全部 6 个模块，每个模块执行完毕后暂停等待用户确认再继续：

1. Read `modules/flush-memory.md` 并执行 → 暂停，等用户确认
2. Read `modules/scan-context.md` 并执行 → 暂停，等用户确认
3. Read `modules/flush-dot-claude.md` 并执行 → 暂停，等用户确认
4. Read `modules/flush-plans.md` 并执行 → 暂停，等用户确认
5. Read `modules/flush-skills.md` 并执行 → 暂停，等用户确认
6. Read `modules/flush-worktrees.md` 并执行 → 暂停，等用户确认

---

### 定时任务管理

**注册触发词：** `定点拉屎` / `每天帮我拉一次屎` / `每周一拉屎` / `每隔N小时体检`

执行定时体检注册：

- 使用 CronCreate，设置 `durable: true`，`recurring: true`。
- Prompt 必须以 `[auto-shit-cron]` 前缀开头，并硬编码注册日期。
- Prompt 内容格式：`[auto-shit-cron] 执行 auto-shit 快速体检。注册日期：{YYYY-MM-DD}。如果今天日期距注册日期已满 6 天，在报告末尾追加："你的 auto-shit 定时拉屎将在明天到期，要续期吗？"`
- Cron 表达式避免整点分钟（例如用 9:03 而非 9:00）。

**取消触发词：** `别拉了` / `取消定时`

- 使用 CronList 查找所有 prompt 包含 `[auto-shit-cron]` 前缀的任务。
- 对找到的每个任务调用 CronDelete 删除。

---

## 硬约束

1. **所有破坏性操作必须先征得用户确认。** 扫描可以自动执行，删除/修改必须用户同意。
2. **不得清除当前对话的上下文窗口。** auto-shit 清理的是持久化环境文件，不是当前会话内存。
3. **不碰活跃配置。** 当前 session 正在使用的配置文件不做修改。
4. **不使用 atime，使用 mtime + 配置注册状态** 判断文件是否过期。
5. **flush-dot-claude 必须跳过 `scheduled_tasks` 中包含 `[auto-shit-cron]` 前缀的条目。** 避免自己把自己的定时任务冲掉。
