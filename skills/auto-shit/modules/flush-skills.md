# flush-skills

幽灵 skill 配置与孤儿依赖清理。

---

## 输入

- `~/.claude/settings.json`

---

## 前置检查

执行任何步骤之前，先确认 settings.json 存在且可解析。

- 读取 `~/.claude/settings.json`。
- 若文件不存在 → 输出 `settings.json 不存在，无法执行 skill 清理` 并结束。
- 若文件存在但 JSON 解析失败 → 输出 `settings.json 格式错误，无法解析` 并结束。
- 若文件存在且可解析 → 按顺序执行以下步骤。

---

## 步骤 1：读取配置

1. 读取 `~/.claude/settings.json` 完整内容。
2. 解析 JSON，提取所有注册的 skill/tool 路径。需要检查的字段包括：
   - `permissions.allow` 和 `permissions.deny` 中引用的路径。
   - `hooks` 配置中引用的命令路径和脚本路径。
   - 任何 `path`、`command`、`file` 等字段中指向文件系统的路径。
3. 构建路径清单，记录每条路径的来源字段（用于后续报告和精确移除）。

---

## 步骤 2：幽灵配置检测（直接注册，Phase 2）

对步骤 1 中提取到的每条路径，执行文件系统存在性检查：

1. 对每条路径使用 `test -e <path>` 验证是否存在。
2. 路径中包含 `~` 的，先展开为绝对路径再检查。
3. 将不存在的路径标记为"幽灵配置"（ghost config），记录：
   - 路径本身
   - 来源字段（如 `permissions.allow[3]`、`hooks.preCommit.command`）
4. 将存在的路径记录到"活跃 skill 清单"中，供步骤 4 使用。

### 步骤 3：幽灵配置检测（MCP server）

扫描 `settings.json` 中的 `mcpServers` 配置块。Skills 有两种注册方式：直接路径注册和通过 MCP server 动态暴露工具。

1. 读取 `mcpServers` 对象中的每个 server 配置
2. 对每个 server，检查 `command` 字段指向的路径是否存在（`test -e`）
3. 将路径不存在的 server 标记为幽灵配置

**局限性说明：**
- MCP server 可能是远程服务（如 HTTP URL），路径存在性检查不适用于远程 server
- 远程 server 可能需要认证、可能启动慢，可达性检查不在本步骤执行
- 本步骤只检查 `command` 字段指向本地路径的 server，远程 server 跳过并在报告中标注"远程服务，未检查"

---

## 步骤 4：孤儿依赖检测

对步骤 2 中确认存在的 skill 目录，检查是否残留大体积依赖目录：

1. 对"活跃 skill 清单"中的每条路径，判断其是否为目录（`test -d`）。
2. 对每个目录，检查以下子目录是否存在：
   - `node_modules/` — Node.js 依赖
   - `venv/` — Python 虚拟环境
   - `.venv/` — Python 虚拟环境（另一种命名）
   - `__pycache__/` — Python 字节码缓存
3. 对存在的依赖目录，使用 `du -sh <path>` 获取占用空间。
4. 将结果记录为"孤儿依赖"清单，包含：
   - 所属 skill 目录
   - 依赖目录类型（node_modules / venv / .venv / __pycache__）
   - 占用空间大小

---

## 步骤 5：Plugin 缓存副本检测

CC 的 plugin 系统在 `~/.claude/plugins/` 下维护多份数据：
- `marketplaces/<plugin-name>/` — marketplace 安装的 plugin 源文件
- `cache/<plugin-name>/` — 缓存副本（通常与 marketplace 内容重复）
- 另外，个人 skill 安装在 `~/.claude/skills/`，不在 plugins 目录下

本步骤只扫描 `~/.claude/plugins/cache/` 和 `~/.claude/plugins/marketplaces/` 的关系，不碰 `~/.claude/skills/`。

1. 检查 `~/.claude/plugins/cache/` 是否存在，不存在则跳过
2. 列出 `~/.claude/plugins/cache/` 下所有子目录
3. 对每个 cache 子目录，检查 `~/.claude/plugins/marketplaces/` 下是否有同名目录
4. 若两者都存在（重复缓存），记录 cache 和 marketplace 的路径及大小
5. 若 cache 存在但 marketplace 无对应项，标记为"孤儿缓存"

---

## 步骤 6：输出清单

输出三个分类列表：

**幽灵配置清单：**
```
[幽灵配置]
- /path/to/missing/skill → 来源: permissions.allow，建议移除
- /another/ghost/path → 来源: hooks.preCommit.command，建议移除
```

**孤儿依赖清单：**
```
[孤儿依赖]
- /path/to/skill/node_modules/ → 占用 128M，可选清理
- /path/to/skill/venv/ → 占用 256M，可选清理
```

**Plugin 缓存清单：**
```
[Plugin 缓存副本]
- cache/fullstack-dev-skills (6.5M) ↔ marketplaces/fullstack-dev-skills (8.9M) → 重复缓存
- cache/old-plugin (3.2M) → 孤儿缓存（marketplace 中已无对应 plugin）
```

若三类均为空 → 输出 `skill 配置干净，无需清理` 并结束。

---

## 步骤 7：执行清理

**在修改 settings.json 之前，必须先备份：**
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.auto-shit.bak
```

等待用户确认后，分三阶段执行：

### 阶段 1：清理幽灵配置

- 将用户确认要移除的幽灵配置条目从 `settings.json` 中删除。
- 使用 Read 读取当前 settings.json → 从 JSON 对象中移除目标条目 → 使用 Write 写回。
- 删除的是配置条目，**不删除文件系统上的任何目录**（路径本就不存在）。

### 阶段 2：清理孤儿依赖

- 对用户确认要清理的孤儿依赖目录，执行 `rm -rf <dependency-dir>`。
- **仅删除依赖子目录（node_modules、venv、.venv、__pycache__），绝对不删除 skill 目录本身。**

### 阶段 3：清理 Plugin 缓存

- 对用户确认要清理的重复缓存或孤儿缓存，执行 `rm -rf ~/.claude/plugins/cache/<plugin-name>/`。
- 重复缓存删除后不影响 plugin 功能（marketplace 源文件仍在）。
- 孤儿缓存删除后无任何影响（对应的 plugin 已不存在）。

---

## 输出格式

所有步骤执行完毕后，输出汇总报告：

```
[flush-skills 完成]
- 发现 {N} 个幽灵配置，已清理 {M} 个
- 发现 {K} 个孤儿依赖目录，已释放 {X} MB
- 发现 {C} 个缓存副本（{Y} MB），已清理 {D} 个（{Z} MB）
- settings.json 已备份为 settings.json.auto-shit.bak
```

---

## 边界情况

- settings.json 不存在 → 输出错误信息并结束，不执行任何步骤。
- settings.json 存在但 JSON 解析失败 → 输出错误信息并结束。
- 无幽灵配置且无孤儿依赖 → 输出 `skill 配置干净，无需清理`。
- 路径包含 `~` → 展开为绝对路径后再做 `test -e` 检查。
- 不使用 atime（macOS 上不可靠），使用路径有效性 + 配置注册状态判断。
- skill 目录存在但为空目录 → 不标记为孤儿依赖（无依赖子目录可清理）。
- 用户部分确认 → 仅清理用户确认的条目，其余保留。
