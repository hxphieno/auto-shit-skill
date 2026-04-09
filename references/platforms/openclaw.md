# OpenClaw 平台路径常量

本文件定义 OpenClaw 环境下的路径常量，供各清理模块通过 Read 加载后使用。

---

## 路径常量

| 变量 | 值 | 说明 |
|------|------|------|
| STATE_DIR | `${OPENCLAW_STATE_DIR:-~/.openclaw}` | 主状态目录，可通过环境变量覆盖 |
| MEMORY_DIR | `~/.openclaw/workspace/memory/`（+ `workspace-<profile>/memory/`） | Memory 文件目录，由 `session-memory` bundled hook 生成（来源 `src/hooks/bundled/session-memory/handler.ts:80`） |
| MEMORY_INDEX | `~/.openclaw/workspace/MEMORY.md` | Memory 索引文件 |
| SESSION_DIR | canonical: `~/.openclaw/agents/<agentId>/sessions/*.jsonl`；workspace 内联: `~/.openclaw/workspace/.openclaw/sessions/*.jsonl` | Session transcript 双路径（来源 `src/config/sessions/paths.ts:14-16`，`src/auto-reply/reply/get-reply-fast-path.ts:220`） |
| CONFIG_FILE | `~/.openclaw/openclaw.json`（JSON5 兼容） | 主配置文件 |
| PLUGINS_DIR | `~/.openclaw/extensions/` | 第三方插件安装目录（来源 `src/plugins/install.ts:421-438`） |
| PLUGINS_INSTALLS_KEY | `plugins.installs` | `openclaw.json` 中已注册插件列表的字段路径（来源 `src/plugins/update.ts:266`） |
| CRON_STORE | `~/.openclaw/cron/jobs.json` | 持久化 cron 任务存储 |
| CRON_RUNS | `~/.openclaw/cron/runs/` | Cron 运行日志目录，每个 job 一个 `<job-id>.jsonl` |
| LOGS_DIR | `~/.openclaw/logs/` | 系统日志目录（注意：`resolveGatewayStateDir()` 可能返回不同路径。`OPENCLAW_PROFILE` 存在时，gateway state dir 为 `~/.openclaw-<profile>/`，日志目录随之变化。来源 `src/daemon/paths.ts:34-43`） |
| LEGACY_DIR | `~/.clawdbot/` | 旧品牌状态目录（来源 `src/config/paths.ts:21` `LEGACY_STATE_DIRNAMES`） |
| LOCK_FILE_PATTERN | `/tmp/openclaw-<uid>/gateway.*.lock` | Gateway 锁文件（文件名格式 `gateway.<sha256>.lock`，sha256 为 configPath 的前 8 字符。同一系统可能有多个锁文件。锁文件内容为 JSON `{pid, createdAt, configPath, startTime}`。来源 `src/infra/gateway-lock.test.ts:50-55`） |
| MCP_CONFIG_KEY | `mcp.servers` | `openclaw.json` 中 MCP 服务器配置的键名（来源 `src/config/mcp-config.ts:14-54`） |
| MEDIA_DIR | `~/.openclaw/media/` | 媒体文件存储目录（来源 `src/media/store.ts:15`） |
| INSTRUCTION_FILES | `AGENTS.md` / `SOUL.md` / `IDENTITY.md` / `USER.md` / `TOOLS.md` / `HEARTBEAT.md` / `BOOTSTRAP.md` | Workspace 配置文件集（来源 `src/agents/workspace.ts:26-33`） |
| DOCTOR_CMD | `openclaw doctor --fix` | 内置诊断修复命令 |

## 路径解析

### Workspace 定位

- 默认：`~/.openclaw/workspace/`
- 自定义 profile：`~/.openclaw/workspace-<profile>/`（通过 `OPENCLAW_PROFILE` 环境变量创建，来源 `src/agents/workspace.ts:18-20`）
- 完全自定义：由 `openclaw.json` 中 `agents.defaults.workspace` 或 `agents.entries.<id>.workspace` 决定（来源 `src/agents/workspace.ts:22`）

注意：`OPENCLAW_WORKSPACE_DIR` 仅用于 docker e2e 测试，非生产环境变量。

### Session 定位

- Canonical 路径：`~/.openclaw/agents/<agentId>/sessions/`（由 `resolveSessionTranscriptsDirForAgent()` 解析）
- Workspace 内联路径：`~/.openclaw/workspace/.openclaw/sessions/`
- 需扫描所有 `agents/*/sessions/` 和 `workspace*/.openclaw/sessions/` 目录

### 环境变量覆盖

| 变量 | 作用 | 生产环境 |
|------|------|----------|
| `OPENCLAW_STATE_DIR` | 覆盖整个 `~/.openclaw/` 基准目录 | 是 |
| `OPENCLAW_CONFIG_PATH` | 覆盖配置文件路径 | 是 |
| `OPENCLAW_OAUTH_DIR` | 覆盖 OAuth 目录 | 是 |
| `OPENCLAW_HOME` | 覆盖 home 目录基准 | 是 |
| `OPENCLAW_PROFILE` | 产生 `workspace-<profile>/` 目录 | 是 |
| `OPENCLAW_LOG_PREFIX` | 改变日志文件前缀（默认 `gateway`） | 是 |
| `OPENCLAW_WORKSPACE_DIR` | 覆盖 workspace 目录 | 否（仅 docker e2e 测试） |

### Cron 管理

OpenClaw 通过 CLI 命令管理 cron（需 gateway 运行中）：
- `openclaw cron add --name <name> --message <text> --cron <expr>` — 添加任务（来源 `src/cli/cron-cli/register.cron-add.ts:69-107`）
- `openclaw cron remove --name <name>` — 删除任务
- `openclaw cron list` — 列出所有任务（来源 `src/cli/cron-cli/register.cron-simple.ts:43`）

**禁止直接读写 `jobs.json`** — 该文件由 gateway 进程管理，直接修改会导致状态不一致。
