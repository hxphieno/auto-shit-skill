# flush-worktrees

废弃 git worktree 清理。清理整个 git 项目的所有 worktree（含用户手动创建的），与 flush-dot-claude 步骤 3 的范围不同。

> **边界说明：** flush-dot-claude 步骤 3 只清理 `.claude/worktrees/` 下由 Claude Code 的 EnterWorktree 工具创建的目录。**本模块清理所有 git worktree**（包括用户通过 `git worktree add` 手动创建的），作用域是整个 git 项目。两者不重叠。

---

## 前置检查

执行任何步骤之前，先确认当前目录是 git 仓库。

- 使用 `git rev-parse --is-inside-work-tree` 检测。
- 若不是 git 仓库 → 输出 `当前目录不是 git 仓库` 并结束，不执行任何步骤。
- 若是 git 仓库 → 按顺序执行以下步骤。

---

## 步骤 1：检查 remote 并 prune

清理过时的远程跟踪分支，为后续"分支已在远程删除"的检测提供准确数据。

1. 执行 `git remote` 获取远程仓库列表。
2. 若输出为空（无任何 remote）→ 跳过本步骤，继续步骤 2。
3. 若存在 remote → 执行 `git remote prune origin` 清理已在远程删除的过时跟踪分支。
   - 若 remote 名称不是 `origin`（通过步骤 1 的输出确认），使用实际的 remote 名称替代。
   - 若存在多个 remote，逐个 prune。

---

## 步骤 2：获取 worktree 列表

1. 执行 `git worktree list --porcelain` 获取所有 worktree 的结构化信息。
2. 解析输出，提取每个 worktree 的：
   - `worktree <path>` — worktree 路径
   - `HEAD <commit>` — 当前 HEAD 提交
   - `branch refs/heads/<name>` — 所在分支名
   - 是否为 `bare` 或 detached HEAD
3. 识别主工作树（main working tree）— 列表中的第一个条目，或标记为 `bare` 的条目。
4. 统计除主工作树外的 worktree 数量 N。
5. 若 N = 0 → 输出 `没有额外的 worktree` 并结束。

---

## 步骤 3：检测废弃特征

对每个非主工作树的 worktree，检查以下三个废弃标准。**任意一条命中即标记为废弃候选：**

### 标准 A：分支已合并到 main/master

1. 确定主分支名称：检查 `main` 和 `master` 哪个存在（`git branch --list main master`），优先使用 `main`。
2. 执行 `git branch --merged <主分支名>` 获取已合并分支列表。
3. 若 worktree 的分支出现在此列表中 → 标记为废弃，原因：`分支已合并到 {主分支名}`。

### 标准 B：分支已在远程删除

1. 若步骤 1 确认存在 remote：
   - 对 worktree 的分支，检查其远程跟踪分支是否存在：`git branch -vv` 并检查对应分支行是否包含 `[origin/<branch>: gone]`。
   - 若跟踪分支已标记为 gone → 标记为废弃，原因：`远程分支已删除`。
2. 若无 remote → 跳过此标准。

### 标准 C：最后提交超过 N 天

1. N 的默认值为 30 天。用户可通过参数指定不同的天数。
2. 获取 worktree 中最后一次提交的时间：
   ```bash
   git log -1 --format=%ct <worktree-branch>
   ```
3. 与当前时间对比，若距今超过 N 天 → 标记为废弃，原因：`最后提交距今 {X} 天（阈值 {N} 天）`。

### detached HEAD 的特殊处理

若 worktree 处于 detached HEAD 状态（无分支名）：
- 标准 A 和 B 不适用，跳过。
- 仅使用标准 C 判断。
- 原因描述中注明 `detached HEAD`。

---

## 步骤 4：列出清单

将所有标记为废弃候选的 worktree 展示给用户：

```
[废弃 worktree 清单]

1. /path/to/worktree-a
   分支：feature/old-experiment
   原因：分支已合并到 main

2. /path/to/worktree-b
   分支：fix/deprecated-api
   原因：远程分支已删除

3. /path/to/worktree-c
   分支：(detached HEAD)
   原因：最后提交距今 45 天（阈值 30 天）
```

若无任何 worktree 被标记 → 输出 `所有 worktree 状态正常，无需清理` 并结束。

---

## 步骤 5：执行清理

逐个询问用户是否删除每个废弃 worktree。**不提供"全部删除"选项** — 每个 worktree 单独确认。

对每个用户确认要删除的 worktree：

### 未提交更改检测

1. 在目标 worktree 中检查是否有未提交的更改：
   ```bash
   git -C <worktree-path> status --porcelain
   ```
2. 若输出不为空（存在未提交更改）→ **拒绝删除**，输出警告：
   ```
   ⚠ /path/to/worktree 有未提交的更改，跳过删除：
     M  src/file.js
     ?? new-file.txt
   ```
3. 跳过此 worktree，继续处理下一个。

### 执行删除

1. 使用 `git worktree remove <path>` 执行删除。
   - **不使用 `rm -rf`** — `git worktree remove` 会同时清理 `.git/worktrees/` 下的元数据，保证 git 内部状态一致。
2. 若 `git worktree remove` 报错（例如路径已被锁定），输出原始错误信息，跳过此 worktree。
3. 记录成功删除的数量 K。

---

## 输出格式

所有步骤执行完毕后，输出汇总报告：

```
[flush-worktrees 完成]
- 扫描了 {N} 个 worktree
- 发现 {M} 个废弃
- 清理了 {K} 个
```

---

## 边界情况

- 当前目录不是 git 仓库 → 输出 `当前目录不是 git 仓库` 并结束。
- 除主工作树外无额外 worktree → 输出 `没有额外的 worktree` 并结束。
- 所有 worktree 均健康（无废弃标记）→ 输出 `所有 worktree 状态正常，无需清理` 并结束。
- worktree 有未提交更改 → 拒绝删除，输出警告，跳过到下一个。
- N 天阈值可由用户指定，默认 30。
- 无 remote → 跳过 prune 和远程分支检测，仅使用标准 A 和 C。
- detached HEAD → 仅使用标准 C 检测。
- `git worktree remove` 执行失败 → 输出原始错误信息，跳过该 worktree，计入扫描但不计入清理。
