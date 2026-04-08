# scan-debris

扫描项目目录中与主项目无关的残留文件。只报告，不删除，不修改。

---

## 定位

开发过程中，Claude Code 和开发者都会在项目里留下一些"异物"——和项目主要技术栈或目的无关的文件。这些文件不影响运行，但会：
- 被 Claude 在全局搜索时读进上下文，浪费 token
- 让项目结构变得混乱
- 在新开发者接手时造成困惑

本模块只做诊断，输出报告，由用户自行决定是否清理。

---

## 执行步骤

### 步骤 1：识��项目主技术栈

读取项目根目录的关键文件，推断项目类型：
- `package.json` → Node.js/前端项目
- `requirements.txt` / `pyproject.toml` / `setup.py` → Python 项目
- `go.mod` → Go 项目
- `Cargo.toml` → Rust 项目
- `pom.xml` / `build.gradle` → Java 项目
- `Gemfile` → Ruby 项目
- 无以上文件 → 通用项目，跳过技术栈匹配，只做通用检测

### 步骤 2：扫描通用异物

无论什么项目类型，以下文件/目录如果出现在项目根目录且未被 `.gitignore` 忽略，标记为疑似异物：

- `.DS_Store`（macOS 系统文件）
- `Thumbs.db`（Windows 系统文件）
- `*.swp` / `*.swo`（vim 临时文件）
- `*~`（编辑器备份文件）
- `.env.local.bak` / `.env.backup`（环境文件备份）
- `dump.rdb`（Redis dump 文件）
- `*.sqlite` / `*.db`（非预期的数据库文件，排除项目明确使用 SQLite 的情况）
- `npm-debug.log` / `yarn-error.log` / `pip-debug.log`（包管理器错误日志）

### 步骤 3：扫描技术栈异物

根据步骤 1 识别的技术栈，检测不属于该技术栈的配置文件：

**Node.js 项目中的异物示例：**
- `requirements.txt` / `setup.py`（Python 配置）
- `go.mod` / `go.sum`（Go 配置）
- `Gemfile`（Ruby 配置）

**Python 项目中的异物示例：**
- `package.json` / `node_modules/`（Node.js 配置）
- `tsconfig.json`（TypeScript 配置，除非项目确实用了 TS）

依此类推。检测逻辑是：**如果一个配置文件属于另一个技术栈，且项目中没有该技术栈的源代码文件，则标记为疑似异物。**

### 步骤 4：扫描孤立大文件

用 Bash 找出项目中超过 1MB 且不在 `.gitignore` 中的文件：
```bash
find . -maxdepth 3 -type f -size +1M \
  -not -path './.git/*' \
  -not -path './node_modules/*' \
  -not -path './venv/*' \
  -not -path './.venv/*' \
  -not -path './dist/*' \
  -not -path './build/*'
```
对每个大文件，标注文件类型和大小。

### 步骤 5：输出报告

```
[scan-debris 报告]

📋 项目类型：{type}（基于 {indicator} 推断）

🗑️ 通用异物：{N} 个
  - .DS_Store（macOS 系统文件）
  - npm-debug.log（包管理器错误日志，47 KB）

🔀 技术栈异物：{M} 个
  - requirements.txt（Python 配置，但本项目是 Node.js）
  - go.sum（Go 配置，项目中无 .go 文件）

📦 孤立大文件：{K} 个
  - data/export.csv（12 MB）
  - backup.sql（8 MB）

以上仅为报告，未做任何修改。需要清理请手动处理或指定文件删除。
```

若未发现异物：「项目目录干净，未发现异物。」

---

## 约束

- **只读模块，不修改、不删除任何文件**
- 不扫描 `.git/`、`node_modules/`、`venv/`、`dist/`、`build/` 等标准忽略目录
- 技术栈判断是启发式的，可能有误判，报告中标注"疑似"
- 不判断文件内容是否有用，只判断文件类型是否属于当前项目

---

## 边界情况

- 多技术栈项目（如 monorepo 同时有 Python 和 Node.js）→ 跳过技术栈异物检测，只做通用检测和大文件检测
- 项目根目录文件极多（>500 个）→ 只扫描根目录和一级子目录，不递归深层
- 无 `.gitignore` → 仍然执行，但在报告中提示"建议添加 .gitignore"
