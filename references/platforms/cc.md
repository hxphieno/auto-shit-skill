# Claude Code 平台路径常量

本文件定义 Claude Code 环境下的路径常量，供各清理模块通过 Read 加载后使用。

---

## 路径常量

| 变量 | 值 | 说明 |
|------|------|------|
| STATE_DIR | `~/.claude` | CC 全局状态目录 |
| MEMORY_DIR | `~/.claude/projects/<hash>/memory/` | Memory 文件目录，hash 为项目路径转换 |
| MEMORY_INDEX | `~/.claude/projects/<hash>/MEMORY.md` | Memory 索引文件 |
| SESSION_DIR | `~/.claude/projects/<hash>/*.jsonl` | Session transcript 文件 |
| CONFIG_FILE | `~/.claude/settings.json` | 全局配置文件 |
| LOCAL_CONFIG | `.claude/settings.local.json` | 项目级本地配置 |
| PLUGINS_DIR | `~/.claude/plugins/` | 插件目录（含 cache/ 和 marketplaces/） |
| SCHEDULED_TASKS | `.claude/scheduled_tasks.json` | 持久化定时任务 |
| MCP_CONFIG_KEY | `mcpServers` | settings.json 中 MCP 服务器配置的键名 |
| INSTRUCTION_FILES | `CLAUDE.md`（四层层级：Managed → User → Project → Local） | 指令配置文件 |

## 路径解析

项目 hash 算法：

```bash
hash=$(echo "$(pwd)" | sed 's/[^a-zA-Z0-9]/-/g')
proj=$(ls -d ~/.claude/projects/${hash}* 2>/dev/null | head -1)
```

`$proj` 即为当前项目对应的 CC 状态目录，memory/ 和 *.jsonl 都在此目录下。
