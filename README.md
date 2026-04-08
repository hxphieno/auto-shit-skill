# auto-shit

> Claude Code 环境卫生 skill。清理 Claude Code 在工作过程中积累的认知与环境垃圾。

触发词：`该拉屎了` / `shit` / `拉屎` → 体检；`冲水` / `flush` → 清理；`大扫除` / `全冲` → 全量清理。

---

## 安装

### 第一步：在 `~/.claude/settings.json` 中注册来源

找到 `extraKnownMarketplaces` 字段（没有就新建），加入：

```json
"extraKnownMarketplaces": {
  "auto-shit-skill": {
    "source": {
      "source": "github",
      "repo": "hxphieno/auto-shit-skill"
    }
  }
}
```

### 第二步：启用 plugin

找到 `enabledPlugins` 字段（没有就新建），加入：

```json
"enabledPlugins": {
  "auto-shit-skill@auto-shit-skill": true
}
```

### 第三步：重启 Claude Code

CC 重启后自动从 GitHub 拉取，之后每次启动自动检查更新。

---

## 触发词一览

| 触发词 | 行为 |
|--------|------|
| `该拉屎了` / `shit` / `拉屎` / `autoshit` | 快速体检：扫描所有维度，输出摘要，不修改任何文件 |
| `冲水` / `flush` | 按模块执行清理 |
| `便秘了` / `堵了` / `体检` / `scan` | 深度诊断 |
| `大扫除` / `全冲` | 全量清理，每步等待确认 |
| `定点拉屎` | 注册定时体检任务 |
| `别拉了` / `取消定时` | 取消定时任务 |
| `查异物` / `扫残留` | 扫描项目残留文件 |

## 清理范围

- Memory 文件（过时/无关条目）
- Session transcripts（已结束的旧会话）
- Plans/Specs 文档（已完成的旧文档）
- Plugin cache（孤儿/重复缓存）
- .claude/ 配置（冗余配置项）
- Git worktrees（已删除分支的残留目录）

> 只清理 Claude Code 自身环境，不碰用户代码。
