# flush-memory

全局 memory 文件清理。Agent 的 memory 系统只写入，从不清理。此模块填补空白。

---

## 平台适配

本模块根据运行平台确定 memory 目录路径：
- **Claude Code**：Read `references/platforms/cc.md` 获取路径。Memory 在 `~/.claude/projects/<hash>/memory/`，索引在 `~/.claude/projects/<hash>/MEMORY.md`
- **OpenClaw**：Read `references/platforms/openclaw.md` 获取路径。Memory 在 `~/.openclaw/workspace/memory/`（由 `session-memory` bundled hook 生成，来源 `src/hooks/bundled/session-memory/handler.ts:80`），索引在 `~/.openclaw/workspace/MEMORY.md`。多 workspace 支持：用 `ls -d ~/.openclaw/workspace-*/memory/ 2>/dev/null` 枚举所有 profile 的 memory 目录，逐个执行相同清理流程

---

## 输入

根据平台不同：

**Claude Code：**
- `~/.claude/projects/<hash>/memory/*.md`（hash 为当前工作目录路径中所有非字母数字字符替换为 `-`。优先用 `echo $(pwd) | sed 's/[^a-zA-Z0-9]/-/g'` 计算，再 `ls -d ~/.claude/projects/${hash}*` 匹配）
- `~/.claude/projects/<hash>/MEMORY.md`（索引文件）

**OpenClaw：**
- `~/.openclaw/workspace/memory/*.md`（默认 workspace）
- `~/.openclaw/workspace-*/memory/*.md`（其他 profile workspace，逐个处理）
- `~/.openclaw/workspace/MEMORY.md`（索引文件）

---

## 前置检查

执行任何步骤之前，先确认 memory 目录存在。

- 定位当前项目对应的 memory 目录：`~/.claude/projects/<project>/memory/`
- 若该目录不存在或为空 → 输出 `未发现 memory 文件` 并结束，不执行任何步骤。
- 若存在 → 按顺序执行以下步骤。

---

## 步骤 1：扫描 memory 文件

1. 使用 Glob 扫描 `memory/*.md` 下所有文件。
2. 统计文件总数 N，记录每个文件的路径。
3. 若 N = 0 → 输出 `未发现 memory 文件` 并结束。

---

## 步骤 2：构建 @include 引用图

CC 的 `claudemd.ts` 支持在 memory 文件中使用 `@path` 指令 — 被引用的文件以独立条目插入。在删除任何文件之前，必须先建立完整的引用关系图。

1. 逐个读取所有 memory 文件的内容。
2. 扫描每个文件中的 `@` 指令：
   - 匹配规则：行首以 `@` 开头，后跟一个路径（如 `@./other-file.md`、`@../shared/common.md`）。
   - **排除代码块内的 `@` 行** — 被 `` ``` `` 围起来的内容不算。
3. 构建反向引用映射（reverse reference map）：
   - 对每个被引用的文件，记录哪些文件引用了它。
   - 数据结构示例：`{ "target.md": ["referrer-a.md", "referrer-b.md"] }`
4. 此映射在后续步骤中用于判断删除安全性 — 防止删除一个仍被其他文件引用的条目（删除后不会报错，只会静默失效，产生悬空引用）。

---

## 步骤 3：两类检测（Phase 1）

### 死引用检测

对每个 memory 文件，读取其内容并检查：

1. **只检查 frontmatter 和结构化字段中的路径引用**，不从自然语言正文中提取路径。Memory 文件正文中经常包含范例性路径（如"例如 ~/project/foo"、"在 /path/to/example"），这些不应被验证。
2. 具体检查范围：
   - frontmatter 中的路径字段
   - `@include` / `@path` 指令引用的文件
   - 明确标注为"文件路径"或在代码块中出现的绝对路径
3. 使用 `test -e <path>` 验证路径是否存在。
4. 将包含不存在路径的文件标记为"死引用"条目，记录具体哪些路径已失效。

**假阳性防护：** 不对自然语言正文做正则路径提取，只检查结构化引用，大幅降低误报率。

### 过期孤立条目检测

对每个 memory 文件，检查以下 **三个条件是否全部满足**（必须同时满足）：

1. **mtime > 90 天** — 使用 `stat -f %m` (macOS) 获取修改时间，与当前时间对比。
2. **未被 MEMORY.md 索引引用** — 在 MEMORY.md 中 Grep 该文件名，若无匹配则视为未索引。
3. **未被任何其他 memory 文件 @include** — 在步骤 2 的反向引用映射中查找，若无任何引用方则视为孤立。

三个条件全部满足的文件标记为"过期孤立"条目。

---

## 步骤 4：输出分类清单

输出两个分类列表：

**死引用条目：**
```
[死引用]
- filename.md → 路径不存在：/path/to/missing/file
- another.md → 路径不存在：/old/project/dir
```

**过期孤立条目：**
```
[过期孤立]
- old-note.md → mtime: 2025-08-15, 原因: 未索引 + 无引用 + 超过 90 天
- stale-config.md → mtime: 2025-06-01, 原因: 未索引 + 无引用 + 超过 90 天
```

若两类均为空 → 输出 `未发现垃圾条目` 并结束。

---

## 步骤 5：用户确认

提供两种确认模式供用户选择：

- **"全部删除"** — 一次性删除所有标记的条目。
- **"逐条确认"** — 逐个询问用户是否删除每个条目。

**特殊情况处理：**
- 若目标文件被其他文件 `@include` 引用（在步骤 2 的反向引用映射中有引用方），则发出警告：`此文件被 {filename} 引用，建议先处理引用方`。
- 用户拒绝删除某条目 → 跳过该条目，不再重复询问。

---

## 步骤 6：执行清理

对用户确认要删除的每个条目：

1. **询问归档偏好**（仅首次询问一次，后续复用同一选择）：
   - 直接删除 `.md` 文件。
   - 或移动到 `memory/archived/` 目录（若目录不存在则自动创建）。
2. 从 `MEMORY.md` 中移除对应的指针行（Grep 文件名定位行，删除该行）。
3. 若选择归档，将文件移动到 `memory/archived/` 而非删除。

---

## Phase 2 扩展：矛盾检测

**此功能为建议性质，不执行自动删除。**

### 检测逻辑

在完成 Phase 1 的死引用和过期检测之后，额外执行矛盾检测：

1. 读取所有 memory 文件的内容
2. 由 Claude 进行语义分析，识别条目间存在逻辑冲突的情况
3. 常见矛盾类型：
   - 语言偏好冲突（如一条说"用中文"，另一条说"use English"）
   - 编码风格冲突（如一条说"不加 docstring"，另一条说"必须有 docstring"）
   - 项目信息冲突（如一条说"用 React"，另一条说"用 Vue"，但针对同一项目）
   - 用户偏好冲突（如一条说"简洁回复"，另一条说"详细解释"）

### 输出

矛盾检测的结果单独输出为"建议"区域：

```
[矛盾检测 — 仅供参考]
发现 {N} 处疑似矛盾：
  ⚠️ memory/feedback_lang.md:2 vs memory/user_pref.md:5
     "始终用中文" ↔ "always respond in English"
     建议：保留其中一条，删除另一条

注意：矛盾检测基于语义判断，可能有假阳性。请自行判断是否需要处理。
```

### 约束
- **仅作为建议输出，绝对不自动删除任何条目**
- 假阳性风险高，每条建议都标注"请自行判断"
- 用户可以选择忽略所有矛盾建议

---

## 输出格式

所有步骤执行完毕后，输出汇总报告：

```
[flush-memory 完成]
- 扫描了 {N} 个 memory 文件
- 发现 {M} 个死引用，{K} 个过期孤立
- 清理了 {X} 个条目
- MEMORY.md 已更新
```

---

## 边界情况

- memory 目录不存在或为空 → 输出 `未发现 memory 文件` 并结束。
- 用户拒绝删除某条目 → 跳过，不再重复询问。
- 目标文件被其他文件 `@include` 引用 → 警告：`此文件被 {filename} 引用，建议先处理引用方`。
- 所有条目均健康 → 输出 `未发现垃圾条目`。
