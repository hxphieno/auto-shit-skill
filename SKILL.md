---
name: auto-shit-skill
description: Use when the user wants to clean up the agent environment (Claude Code or OpenClaw) — stale memory entries, expired state directory artifacts, ghost skill/extension configs, abandoned worktrees, outdated plan documents, or unrelated project debris. Also triggers on "该拉屎了", "shit", "拉屎", "冲水", "flush", "便秘了", "堵了", "大扫除", "全冲", "定点拉屎", "别拉了", "查异物", "扫残留".
compatibility: Designed for Claude Code and OpenClaw
metadata:
  author: hxphieno
  version: "1.1.0"
  platforms: "claude-code, openclaw"
---

# auto-shit — Agent 环境卫生

清理 agent 在工作过程中积累的认知与环境垃圾。支持 Claude Code 和 OpenClaw。只扫描和清理 agent 自身环境，不碰用户代码。

---

## 平台识别

确认你的运行平台：
- 如果你是 Claude Code，设 `PLATFORM=cc`
- 如果你是 OpenClaw，设 `PLATFORM=openclaw`
- 如果不确定，运行 `scripts/detect-platform.sh` 验证

验证规则：
- 你说自己是 Claude Code 但 `~/.claude` 不存在 → 报警提示环境异常
- 你说自己是 OpenClaw 但 `~/.openclaw` 不存在 → 报警提示环境异常
- 两个目录都存在 → 正常，走你自识别的平台

---

## 触发词路由

### 快速检查（只扫描不动手）

**触发词：** `该拉屎了` / `shit` / `拉屎` / `auto-shit`

执行内容级扫描，覆盖所有维度，输出摘要和建议，不修改任何文件。

**核心原则：读内容做相关性判断，不只统计体积。** 体积信息作为辅助展示，主要输出是内容摘要和清理建议。

**第一步：平台识别与环境验证**

运行 `scripts/detect-platform.sh`，对比模型自识别结果验证环境。

**第二步：用单个 Bash 收集文件清单（用户只需 allow 一次）**

根据 PLATFORM 运行对应采集脚本，**必须传入当前项目目录作为第一个参数**：
- Claude Code：运行 `scripts/scan-cc.sh "$(pwd)"`
- OpenClaw：运行 `scripts/scan-openclaw.sh "$(pwd)"`

然后运行 `scripts/scan-common.sh` 采集通用信息（Plans/Specs、Git/Worktrees）。

**注意：** 所有脚本已兼容 zsh 和 bash，无需额外处理。

**第三步：读取内容做相关性判断。** 基于第二步的文件清单：

1. **Memory**：如果有 memory 文件，用 Read 逐个读取内容。对每条 memory 输出一句话内容摘要（类型 + 核心信息），再判断是否与当前项目相关。
2. **Sessions**：基于第一步 SAMPLE 字段（前 30 行 × 每行 200 字符），为每个 session 输出一句话内容摘要（讨论主题 + 涉及的功能/文件），再判断相关性。不要只输出"相关/无关"的结论。
3. **Plans/Specs**：从标题和日期判断是否过时。如果日期很旧且标题涉及已完成的功能，标记为可归档。
4. **Skills**：读 settings.json 内容，检查路径有效性和 MCP server 配置。
5. **.claude/**：读 settings.local.json 内容，检查是否有冗余或冲突配置。
6. **Plugin Cache**：从第一步结果直接判断重复/孤儿。
7. **Worktrees**：从第一步结果直接判断。
8. **Logs**（仅 OpenClaw）：按 mtime 和体积给出清理建议，> 7 天或 > 50MB 标 ✗
9. **Cron Runs**（仅 OpenClaw）：已删除 job 的日志标 ✗，活跃 job 的日志标 🕐
10. **Legacy**（仅 OpenClaw）：`.clawdbot/` 存在且 `.openclaw/` 也存在 → 标 ✗ 并提示可调用 `openclaw doctor --fix`
11. **Lock**（仅 OpenClaw）：锁文件存在但进程已死 → 标 ✗

**输出格式：** 按 `style.md` 中的模板生成报告，替换 `{N}`、`{X}` 等占位符。每项标注 ✓（相关）、✗（建议清理）或 🕐（3 天内修改，暂不建议清理）。清单为空时输出 style.md 中定义的"环境干净"回复。

**清单交互规则：**
- 检查完成后，自动将所有标记为 ✗ 的项目汇总为「建议清理清单」，带编号
- 用户说"冲水"→ 直接清理清单内所有项目，不再逐条确认
- 用户说"去掉 2"或"保留 def456"→ 从清单中移除该项，然后等待用户说"冲水"
- 用户说"加上 xxx"→ 将指定项目加入清单
- 用户说"只冲 1 和 3"→ 只清理指定编号
- 清单为空时输出：「环境干净，不用冲水。」

---

### 执行清理

**触发词：** `冲水` / `flush`

询问用户要清理哪个模块，然后 Read 对应的 `references/` 文件并按其指令执行：

| 用户说 | 动作 |
|--------|------|
| 冲 memory / 清记忆 | Read `references/flush-memory.md` |
| 冲状态 / 冲 .claude / 冲环境 | Read `references/flush-state.md` |
| 冲插件 / 冲 skills / 冲 extensions | Read `references/flush-extensions.md` |
| 冲 plans / 清旧文档 | Read `references/flush-plans.md` |
| 冲 worktrees | Read `references/flush-worktrees.md` |
| 查异物 / 扫残留 | Read `references/scan-debris.md` |
| 冲旧图 / 清旧图 | Read `references/flush-media.md`（仅 OpenClaw） |
| 退旧房 / 清空房 | Read `references/flush-workspaces.md`（仅 OpenClaw） |
| 拔废管 / 清废管 | Read `references/flush-orphan-extensions.md`（仅 OpenClaw） |

Claude Code 环境下触发 OpenClaw 独有命令，回复："这个功能仅适用于 OpenClaw 环境。"

模块执行完毕后，输出提示：「冲完了。运行 `/compact` 让改动立即生效，继续当前对话；或开新对话效果相同。」

---

### 详细诊断

**触发词：** `便秘了` / `堵了` / `体检` / `scan`

Read `references/scan-context.md` 并按其指令执行深度诊断。

**OpenClaw 平台注意：** scan-context 深度诊断尚未适配 OpenClaw 平台，将在后续版本支持。OpenClaw 用户触发此命令时，输出提示：「scan-context 深度诊断尚未适配 OpenClaw 平台，将在后续版本支持。当前可用：`openclaw doctor` 进行系统级诊断。」

---

### 全量清理

**触发词：** `大扫除` / `全冲`

按顺序执行清理模块，每个模块执行完毕后暂停等待用户确认再继续：

1. Read `references/flush-memory.md` 并执行 → 暂停，等用户确认
2. Read `references/scan-context.md` 并执行 → 暂停（Claude Code 执行诊断；OpenClaw 跳过并提示"scan-context 尚未适配 OpenClaw，跳过"）
3. Read `references/flush-state.md` 并执行 → 暂停，等用户确认
4. Read `references/flush-plans.md` 并执行 → 暂停，等用户确认
5. Read `references/flush-extensions.md` 并执行 → 暂停，等用户确认
6. Read `references/flush-worktrees.md` 并执行 → 暂停，等用户确认

OpenClaw 独有模块（flush-media / flush-workspaces / flush-orphan-extensions）不进入大扫除序列。

---

### 定时任务管理

**注册触发词：** `定点拉屎` / `每天帮我拉一次屎` / `每周一拉屎` / `每隔N小时检查`

执行定时检查注册：

- 使用 CronCreate，设置 `durable: true`，`recurring: true`。
- Prompt 必须以 `[auto-shit-cron]` 前缀开头，并硬编码注册日期。
- Prompt 内容格式：`[auto-shit-cron] 执行 auto-shit 快速检查。注册日期：{YYYY-MM-DD}。如果今天日期距注册日期已满 6 天，在报告末尾追加："你的 auto-shit 定时拉屎将在明天到期，要续期吗？"`
- Cron 表达式避免整点分钟（例如用 9:03 而非 9:00）。

**取消触发词：** `别拉了` / `取消定时`

- 使用 CronList 查找所有 prompt 包含 `[auto-shit-cron]` 前缀的任务。
- 对找到的每个任务调用 CronDelete 删除。

**OpenClaw 平台定时任务注册：**

- 需要 gateway 正在运行。如果 gateway 未启动，提示用户先运行 `openclaw gateway` 或 `openclaw onboard --install-daemon`
- 使用 `openclaw cron add --name "auto-shit-check" --message "[auto-shit-cron] 执行 auto-shit 快速检查。注册日期：{YYYY-MM-DD}。如果今天日期距注册日期已满 6 天，在报告末尾追加：你的 auto-shit 定时拉屎将在明天到期，要续期吗？" --cron "<expr>"`
- Cron 表达式避免整点分钟（例如用 9:03 而非 9:00）

**OpenClaw 平台取消定时：**

- 使用 `openclaw cron list` 查找所有 message 包含 `[auto-shit-cron]` 的任务
- 对找到的每个任务调用 `openclaw cron remove <id>` 删除

---

## 硬约束

1. **所有破坏性操作必须先征得用户确认。** 扫描可以自动执行，删除/修改必须用户同意。
2. **不得清除当前对话的上下文窗口。** auto-shit 清理的是持久化环境文件，不是当前会话内存。
3. **不碰活跃配置。** 当前 session 正在使用的配置文件不做修改。
4. **不使用 atime，使用 mtime + 配置注册状态** 判断文件是否过期。
5. **flush-state 必须跳过定时任务中包含 `[auto-shit-cron]` 前缀的条目。** 避免自己把自己的定时任务冲掉。
   - Claude Code 中 `[auto-shit-cron]` 前缀在 prompt 字段；OpenClaw 中在 message 字段。
6. **3 天保护：mtime 在 3 天以内的文件不纳入"建议清理清单"。** 报告中照常显示摘要和判断，用 🕐 标记。用户可手动说"加上 N"将其加入清单。所有模块（快速检查、flush-*）统一遵守此规则。
7. **OpenClaw 平台同样遵守以上所有硬约束。** 平台差异仅在路径和工具接口，安全原则完全一致。
