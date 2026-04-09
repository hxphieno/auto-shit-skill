# flush-workspaces

OpenClaw 废弃工作区清理。仅适用于 OpenClaw 平台。

---

## 平台限制

本模块仅在 OpenClaw 平台可用。Claude Code 环境下触发时，回复："这个功能仅适用于 OpenClaw 环境。"

---

## 输入

- `~/.openclaw/workspace-<profile>/`（通过 `OPENCLAW_PROFILE` 环境变量创建，来源 `src/agents/workspace.ts:18-20`）
- `~/.openclaw/openclaw.json` 中 `agents.entries` 配置

---

## 前置检查

1. 确认 PLATFORM 为 OpenClaw。
2. 扫描 `$OC_STATE/workspace-*/` 目录。若无任何 workspace-* 目录 → 输出 `未发现额外工作区` 并结束。

---

## 步骤 1：枚举工作区

列出所有 `$OC_STATE/workspace-*/` 目录，提取 profile 名称。

## 步骤 2：三重判断

对每个 workspace-<profile>/ 目录，执行三重检测：

### 检测 A：配置注册状态
读取 `openclaw.json` 中 `agents.entries`，检查是否有对应 profile 的 workspace 配置。

### 检测 B：近期活动
- 检查 `workspace-<profile>/.openclaw/sessions/` 下最新 session 的 mtime
- 检查 `workspace-<profile>/memory/` 下文件的 mtime
- 3 天保护规则适用

### 检测 C：综合判断
- 配置未注册 + 无近期活动 → 标记为"疑似废弃"（注意：不能自动标 ✗）
- 配置未注册 + 有近期活动 → 标记为"配置缺失但仍活跃"
- 配置已注册 → 标记为"正常"

**重要：** `workspace-<profile>/` 目录可能由 `OPENCLAW_PROFILE` 环境变量创建但从未在 `agents.entries` 中注册。仅凭配置未注册不能判定为废弃。

## 步骤 3：展示清单

列出所有"疑似废弃"的工作区，包含：
- profile 名称
- 目录大小（`du -sh`）
- 最后活动时间
- 判断依据

## 步骤 4：用户确认

逐个确认是否删除。**不提供批量删除选项**。

## 步骤 5：执行清理

用户确认后，删除对应 workspace 目录。

---

## 输出格式

```
[flush-workspaces 完成]
- 扫描了 {N} 个额外工作区
- 发现 {M} 个疑似废弃
- 清理了 {K} 个，释放 {X} MB
```

---

## 边界情况

- 无 workspace-* 目录 → 输出提示并结束
- 所有工作区均正常 → 输出 `所有工作区状态正常`
- workspace 内有未提交的 git 更改 → 警告并跳过
- 3 天保护规则适用