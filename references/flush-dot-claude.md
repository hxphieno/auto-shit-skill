# flush-dot-claude

清理项目级 `.claude/` 目录内积累的工作垃圾。这是 auto-shit 最核心的模块。

---

## 前置检查

执行任何步骤之前，先检查当前项目根目录下 `.claude/` 是否存在。

- 若不存在 → 输出 `当前项目无 .claude 目录` 并结束，不执行任何步骤。
- 若存在 → 按顺序执行以下 5 个步骤。每个步骤中，若目标路径不存在则跳过该步骤，继续下一步。

---

## 步骤 1：todos 清理

**注意：** CC 的 TaskCreate/TaskList 是会话级工具，其持久化格式未在源码中公开确认。可能是 `.claude/todos/` 目录下的独立文件，也可能是单个 JSON 文件，甚至可能不持久化到项目 `.claude/` 下。

1. 检查 `.claude/todos/` 是否存在。若不存在，尝试查找 `.claude/` 下任何包含 "todo" 或 "task" 的文件。都不存在则跳过本步骤。
2. 根据找到的文件格式（目录/JSON），读取 task 条目。
3. 标记以下两类为垃圾：
   - **status = `completed`** — 已完成的任务，留着没有意义。
   - **status = `pending`** 且创建时间距今超过 30 天且无 owner — 长期无人认领的僵尸任务。
4. 将标记结果列表展示给用户，等待用户确认要删除哪些。
5. 删除用户确认的条目。

---

## 步骤 2：scheduled_tasks 清理

1. 读取 `.claude/scheduled_tasks.json`，不存在则跳过本步骤。
2. **关键背景：** 只有 `durable: true` 的任务会持久化到此文件。`recurring: false` 的一次性任务仅存在于内存中，触发后自动删除，永远不会出现在此文件中。
3. **必须跳过** prompt 以 `[auto-shit-cron]` 开头的条目 — 这些是 auto-shit 自身注册的定时任务，不能被自己冲掉。
4. 在剩余条目中标记可清理项：
   - `durable: true` 但 prompt 内容引用了不存在的文件或项目（已过时）。
   - `durable: true` 且 cron 指向过去的时间点，已超过 7 天自动过期期限但条目仍残留在文件中。
5. 将标记结果列表展示给用户，等待确认后从 JSON 中移除对应条目。

---

## 步骤 3：worktrees 孤儿目录清理

> **注意：** 本步骤只清理 `.claude/worktrees/` 下由 Claude Code 的 EnterWorktree 工具创建的 worktree 目录。不涉及用户手动通过 `git worktree add` 创建的 worktree — 那属于 flush-worktrees 模块的职责。

1. 列出 `.claude/worktrees/` 下的所有子目录，不存在则跳过本步骤。
2. 对每个目录，检查其对应的 git 分支是否仍然存在（`git branch --list <branch-name>`）。
3. 标记分支已删除或已合并的目录为可清理。
4. 将标记结果列表展示给用户，等待确认后删除对应目录。

---

## 步骤 4：settings.local.json 冲突检测

1. 读取 `.claude/settings.local.json`，不存在则跳过本步骤。
2. 读取全局配置 `~/.claude/settings.json`。
3. 对比两者，找出 local 中与 global 完全相同的覆写项（冗余配置）。
4. 将冗余项列表展示给用户，由用户决定是否移除。
5. **仅建议，不强制修改。** 用户不确认则不动。

---

## 步骤 5：session transcript 清理

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

5. 将分桶统计结果展示给用户，询问要清理哪个时间段的文件。
6. **活写风险警告：** 当前会话的 transcript 文件正被 CC 的 `appendEntryToFile()` 持续写入。如果删除正在写入的 .jsonl 文件，进程持有的 fd 仍然有效但 inode 已被回收，后续追加内容会在 fd 关闭后丢失。因此：**必须排除当前 session 的 transcript 文件**。用最近 mtime 的 .jsonl 文件作为当前 session 标识，将其从删除列表中剔除。
7. 用户确认后执行删除。

---

## 输出格式

所有步骤执行完毕后，输出汇总报告：

```
[flush-dot-claude 完成]
- todos：清理了 {N} 个过期条目
- scheduled_tasks：清理了 {N} 个过期任务
- worktrees：清理了 {N} 个孤儿目录
- settings：发现 {N} 处冗余（已/未处理）
- transcripts：清理了 {N} 个文件，释放 {X} MB
```

被跳过的步骤在报告中显示数量为 0 或标注"跳过"。

---

## 边界情况

- `.claude/` 目录不存在 → 输出 `当前项目无 .claude 目录` 并结束。
- 任何子步骤的目标路径不存在 → 跳过该步骤，继续执行下一步。
- 所有步骤均被跳过（`.claude/` 存在但无任何子目标） → 输出报告，所有项显示为 0。
