# flush-state

合并清理 Claude Code 和 OpenClaw 的状态目录垃圾。

---

## 平台适配

本模块根据运行平台执行不同的清理步骤：
- **Claude Code**：Read `references/platforms/cc.md` 获取路径常量
- **OpenClaw**：Read `references/platforms/openclaw.md` 获取路径常量

---

## 前置检查

**Claude Code：** 执行任何步骤之前，先检查当前项目根目录下 `.claude/` 是否存在。

- 若不存在 → 输出 `当前项目无 .claude 目录` 并结束 Claude Code 清理，不执行任何步骤。
- 若存在 → 按顺序执行以下 5 个步骤。每个步骤中，若目标路径不存在则跳过该步骤，继续下一步。

**OpenClaw：** 检查 `${OPENCLAW_STATE_DIR:-~/.openclaw}` 是否存在。

- 若不存在 → 输出 `当前系统无 OpenClaw 状态目录` 并结束 OpenClaw 清理。
- 若存在 → 按顺序执行以下 7 个步骤。

---

## Claude Code 清理步骤

### 步骤 1：todos 清理

**注意：** CC 的 TaskCreate/TaskList 是会话级工具，其持久化格式未在源码中公开确认。可能是 `.claude/todos/` 目录下的独立文件，也可能是单个 JSON 文件，甚至可能不持久化到项目 `.claude/` 下。

1. 检查 `.claude/todos/` 是否存在。若不存在，尝试查找 `.claude/` 下任何包含 "todo" 或 "task" 的文件。都不存在则跳过本步骤。
2. 根据找到的文件格式（目录/JSON），读取 task 条目。
3. 标记以下两类为垃圾：
   - **status = `completed`** — 已完成的任务，留着没有意义。
   - **status = `pending`** 且创建时间距今超过 30 天且无 owner — 长期无人认领的僵尸任务。
4. 将标记结果列表展示给用户，等待用户确认要删除哪些。
5. 删除用户确认的条目。

---

### 步骤 2：scheduled_tasks 清理

1. 读取 `.claude/scheduled_tasks.json`，不存在则跳过本步骤。
2. **关键背景：** 只有 `durable: true` 的任务会持久化到此文件。`recurring: false` 的一次性任务仅存在于内存中，触发后自动删除，永远不会出现在此文件中。
3. **必须跳过** prompt 以 `[auto-shit-cron]` 开头的条目 — 这些是 auto-shit 自身注册的定时任务，不能被自己冲掉。
4. 在剩余条目中标记可清理项：
   - `durable: true` 但 prompt 内容引用了不存在的文件或项目（已过时）。
   - `durable: true` 且 cron 指向过去的时间点，已超过 7 天自动过期期限但条目仍残留在文件中。
5. 将标记结果列表展示给用户，等待确认后从 JSON 中移除对应条目。

---

### 步骤 3：worktrees 孤儿目录清理

> **注意：** 本步骤只清理 `.claude/worktrees/` 下由 Claude Code 的 EnterWorktree 工具创建的 worktree 目录。不涉及用户手动通过 `git worktree add` 创建的 worktree — 那属于 flush-worktrees 模块的职责。

1. 列出 `.claude/worktrees/` 下的所有子目录，不存在则跳过本步骤。
2. 对每个目录，检查其对应的 git 分支是否仍然存在（`git branch --list <branch-name>`）。
3. 标记分支已删除或已合并的目录为可清理。
4. 将标记结果列表展示给用户，等待确认后删除对应目录。

---

### 步骤 4：settings.local.json 冲突检测

1. 读取 `.claude/settings.local.json`，不存在则跳过本步骤。
2. 读取全局配置 `~/.claude/settings.json`。
3. 对比两者，找出 local 中与 global 完全相同的覆写项（冗余配置）。
4. 将冗余项列表展示给用户，由用户决定是否移除。
5. **仅建议，不强制修改。** 用户不确认则不动。

---

### 步骤 5：session transcript 清理

Claude Code 会将每个会话的完整交互记录写入 JSONL 文件（`getTranscriptPath()` 定义在 `src/utils/sessionStorage.ts`），内容包括所有消息、工具调用结果、token 使用量。**这些文件永远不会被自动删除。** 长期使用后累积量非常可观（每个会话数百 KB 到数 MB）。

Session transcript 文件存放在 CC 全局目录，不在项目 `.claude/` 下。路径为 `~/.claude/projects/<hash>/`，其中 hash 为当前工作目录中所有非字母数字字符替换为 `-`。

1. 用 Bash 计算当前项目的 CC 路径 hash：`echo $(pwd) | sed 's/[^a-zA-Z0-9]/-/g'`，然后 `ls -d ~/.claude/projects/${hash}*` 匹配
2. 扫描 `~/.claude/projects/<hash>/*.jsonl`（transcript 直接在项目 hash 目录下）
3. 同时扫描其他项目的 transcript：`~/.claude/projects/*/*.jsonl`
4. 使用 Bash 按 mtime 分桶统计：
   ```bash
   # 30 天以内
   find <path> -name "*.jsonl" -mtime -30 | wc -l
   # 30-90 天
   find <path> -name "*.jsonl" -mtime +30 -mtime -90 | wc -l
   # 90 天以上
   find <path> -name "*.jsonl" -mtime +90 | wc -l
   # 总占用空间
   du -sh <path>
   ```

5. 将分桶统计结果展示给用户，询问要清理哪个时间段的文件。**mtime 在 3 天以内的文件不纳入默认清理建议（遵守硬约束第 6 条），即使用户选择"清理 30 天以内"也排除。**
6. **活写风险警告：** 当前会话的 transcript 文件正被 CC 的 `appendEntryToFile()` 持续写入。如果删除正在写入的 .jsonl 文件，进程持有的 fd 仍然有效但 inode 已被回收，后续追加内容会在 fd 关闭后丢失。因此：**必须排除当前 session 的 transcript 文件**。用最近 mtime 的 .jsonl 文件作为当前 session 标识，将其从删除列表中剔除。
7. 用户确认后执行删除。

---

## OpenClaw 清理步骤

### 步骤 1：cron 任务清理

1. 使用 `openclaw cron list` 获取当前所有 cron 任务列表（需 gateway 运行中）。
2. **必须跳过** message 字段以 `[auto-shit-cron]` 开头的条目 — 这些是 auto-shit 自身注册的定时任务，不能被自己冲掉。注意：OpenClaw 使用 **message** 字段（区别于 Claude Code 的 prompt 字段）。
3. 在剩余条目中，通过 Read `${OPENCLAW_STATE_DIR:-~/.openclaw}/cron/jobs.json` 辅助检测以下可清理项：
   - message 内容引用了不存在的文件或项目（已过时的孤儿任务）。
   - cron 指向过去的时间点，已超过 7 天自动过期期限但条目仍残留。
4. 将标记结果列表展示给用户，等待确认。
5. 使用 `openclaw cron remove --name <name>` 删除用户确认的条目。**禁止直接修改 `jobs.json`** — 该文件由 gateway 进程管理，直接修改会导致状态不一致。

---

### 步骤 2：配置冲突检测

1. 读取 `${OPENCLAW_STATE_DIR:-~/.openclaw}/openclaw.json`（JSON5 兼容），不存在则跳过本步骤。
2. 检查当前 workspace 配置（`AGENTS.md` / `SOUL.md` / `IDENTITY.md` 等 workspace 配置文件）中是否存在与 `openclaw.json` 重复或冲突的配置项。
3. 检查是否存在遗留的 `clawdbot.json` 文件（旧品牌配置文件残留）。
4. 将冲突项和遗留文件列表展示给用户，由用户决定如何处理。
5. **仅建议，不强制修改。** 用户不确认则不动。

---

### 步骤 3：session transcript 清理

OpenClaw 的 session transcript 存在双路径（来源 `src/config/sessions/paths.ts:14-16`）：

- **Canonical 路径：** `${OPENCLAW_STATE_DIR:-~/.openclaw}/agents/*/sessions/*.jsonl`
- **Workspace 内联路径：** `${OPENCLAW_STATE_DIR:-~/.openclaw}/workspace/.openclaw/sessions/*.jsonl`（以及所有 `workspace-*/` 变体）

1. 扫描上述两类路径下的所有 `.jsonl` 文件。
2. 使用 Bash 按 mtime 分桶统计：
   ```bash
   # 30 天以内
   find <path> -name "*.jsonl" -mtime -30 | wc -l
   # 30-90 天
   find <path> -name "*.jsonl" -mtime +30 -mtime -90 | wc -l
   # 90 天以上
   find <path> -name "*.jsonl" -mtime +90 | wc -l
   # 总占用空间
   du -sh <path>
   ```
3. 将分桶统计结果展示给用户，询问要清理哪个时间段的文件。**mtime 在 3 天以内的文件不纳入默认清理建议，即使用户选择"清理 30 天以内"也排除。**
4. **活写风险警告：** 当前 session 的 transcript 文件正在被持续写入。必须排除当前 session 的 transcript 文件。用最近 mtime 的 `.jsonl` 文件作为当前 session 标识，将其从删除列表中剔除。
5. 用户确认后执行删除。

---

### 步骤 4：Gateway 日志清理

OpenClaw Gateway 日志文件前缀由 `OPENCLAW_LOG_PREFIX` 环境变量控制（默认 `gateway`），文件名不固定，**禁止硬编码文件名**。

1. 扫描 `${OPENCLAW_STATE_DIR:-~/.openclaw}/logs/` 目录。注意：若 `OPENCLAW_PROFILE` 存在，gateway state dir 可能为 `~/.openclaw-<profile>/`，日志目录随之变化，需用 `resolveGatewayStateDir()` 等效逻辑处理。
2. 使用 glob 匹配所有日志文件：`*.log`、`*.err.log`、`*.jsonl`。
3. 使用 Bash 按 mtime 分桶统计：
   ```bash
   # 7 天以内
   find <logs_dir> \( -name "*.log" -o -name "*.err.log" -o -name "*.jsonl" \) -mtime -7 | wc -l
   # 7-30 天
   find <logs_dir> \( -name "*.log" -o -name "*.err.log" -o -name "*.jsonl" \) -mtime +7 -mtime -30 | wc -l
   # 30 天以上
   find <logs_dir> \( -name "*.log" -o -name "*.err.log" -o -name "*.jsonl" \) -mtime +30 | wc -l
   # 总占用空间
   du -sh <logs_dir>
   ```
4. 将分桶统计结果展示给用户，对以下情况建议清理：
   - mtime 超过 7 天的日志文件。
   - 总占用空间超过 50MB 的日志目录。
5. 用户确认后执行删除。**mtime 在 3 天以内的文件不纳入删除范围。**

---

### 步骤 5：Cron 运行日志清理

1. 扫描 `${OPENCLAW_STATE_DIR:-~/.openclaw}/cron/runs/` 目录，不存在则跳过本步骤。
2. 该目录下每个活跃 job 对应一个 `<job-id>.jsonl` 运行日志文件。
3. 读取 `${OPENCLAW_STATE_DIR:-~/.openclaw}/cron/jobs.json` 获取当前所有已注册 job 的 ID 列表。
4. 对 `runs/` 下的每个 `.jsonl` 文件，检查其文件名（去掉 `.jsonl` 后缀）是否在 jobs.json 的 job ID 列表中。
5. 标记在 jobs.json 中找不到对应 job ID 的运行日志为孤儿日志（对应 job 已被删除）。
6. 将孤儿运行日志列表展示给用户，等待确认后删除。

---

### 步骤 6：遗留品牌目录检测

OpenClaw 的前身 ClawdBot 遗留了 `~/.clawdbot/` 状态目录。

1. 检查 `~/.clawdbot/` 是否存在。
2. 根据检测结果分三种情况处理：
   - **`~/.clawdbot/` 和 `${OPENCLAW_STATE_DIR:-~/.openclaw}/` 同时存在** → 存在品牌迁移遗留，自动调用 `openclaw doctor --fix` 执行修复。
   - **只有 `~/.clawdbot/` 存在，没有 OpenClaw 状态目录** → 可能是未完成迁移，建议用户手动运行 `openclaw doctor` 进行诊断。
   - **只有 OpenClaw 状态目录，没有 `~/.clawdbot/`** → 无遗留，跳过本步骤。

---

### 步骤 7：Gateway 锁文件检测

Gateway 启动时会在 `/tmp/openclaw-<uid>/` 下创建锁文件，文件名格式为 `gateway.<sha256>.lock`（sha256 为 configPath 的前 8 字符），同一系统可能存在多个锁文件。

1. 使用 glob `/tmp/openclaw-$(id -u)/gateway.*.lock` 扫描所有锁文件。不存在则跳过本步骤。
2. 对每个锁文件，解析其 JSON 内容：`{pid, createdAt, configPath, startTime}`。
3. 使用 `kill -0 <pid>` 检测对应进程是否仍在运行：
   - `kill -0` 成功（退出码 0）→ 进程存活，锁文件有效，不处理。
   - `kill -0` 失败（退出码非 0）→ 进程已死，锁文件为残留（stale lock）。
4. 将检测到的残留锁文件列表展示给用户，等待确认后删除。

---

## 输出格式

所有步骤执行完毕后，输出统一汇总报告：

```
[flush-state 完成]

Claude Code：
- todos：清理了 {N} 个过期条目
- scheduled_tasks：清理了 {N} 个过期任务
- worktrees：清理了 {N} 个孤儿目录
- settings：发现 {N} 处冗余（已/未处理）
- transcripts：清理了 {N} 个文件，释放 {X} MB

OpenClaw：
- cron 任务：清理了 {N} 个过期任务
- 配置冲突：发现 {N} 处冲突（已/未处理）
- session transcripts：清理了 {N} 个文件，释放 {X} MB
- gateway 日志：清理了 {N} 个文件，释放 {X} MB
- cron 运行日志：清理了 {N} 个孤儿日志
- 遗留品牌目录：{检测结果/跳过}
- gateway 锁文件：清理了 {N} 个残留锁文件
```

被跳过的步骤在报告中显示数量为 0 或标注"跳过"。未安装的平台整节标注"未检测到"。

---

## 硬约束

- **`[auto-shit-cron]` 前缀保护：** Claude Code 中检查 `prompt` 字段，OpenClaw 中检查 `message` 字段。两者均不得被清理。
- **3 天 mtime 保护规则：** 所有 mtime 在 3 天以内的文件不纳入任何默认清理建议，即使用户选择更宽泛的时间范围也必须排除。
- **当前 session transcript 排除：** 两个平台均需以最近 mtime 的 `.jsonl` 文件作为当前 session 标识，从删除列表中剔除，防止删除正在写入的文件。
- **所有破坏性操作需用户确认：** 任何删除、修改操作在执行前必须向用户展示清单并等待确认，用户不确认则不动。
- **禁止直接修改 OpenClaw `jobs.json`：** OpenClaw cron 任务必须通过 CLI 命令（`openclaw cron remove`）管理，不得直接读写 `jobs.json`。

---

## 边界情况

**Claude Code：**
- `.claude/` 目录不存在 → 输出 `当前项目无 .claude 目录` 并结束 Claude Code 清理。
- 任何子步骤的目标路径不存在 → 跳过该步骤，继续执行下一步。
- 所有步骤均被跳过（`.claude/` 存在但无任何子目标） → 输出报告，所有项显示为 0。

**OpenClaw：**
- OpenClaw 状态目录不存在 → 输出 `当前系统无 OpenClaw 状态目录` 并结束 OpenClaw 清理。
- Gateway 未运行时调用 `openclaw cron list` → 命令可能失败，跳过步骤 1 并提示用户启动 gateway。
- `OPENCLAW_PROFILE` 存在时，gateway logs 目录路径随之变化 → 需先解析实际 gateway state dir，再扫描日志。
- `/tmp/openclaw-<uid>/` 目录不存在 → 无锁文件，步骤 7 跳过。
- `cron/runs/` 目录不存在 → 步骤 5 跳过。
- `~/.clawdbot/` 不存在 → 步骤 6 跳过。

**通用：**
- 两个平台均未检测到 → 报告提示无可清理内容。
- 仅安装其中一个平台 → 只执行对应平台的清理步骤，另一平台整节标注"未检测到"。
