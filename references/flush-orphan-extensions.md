# flush-orphan-extensions

OpenClaw 废弃扩展目录清理。仅适用于 OpenClaw 平台。

---

## 平台限制

本模块仅在 OpenClaw 平台可用。Claude Code 环境下触发时，回复："这个功能仅适用于 OpenClaw 环境。"

---

## 输入

- `~/.openclaw/extensions/<plugin-id>/`（来源 `src/plugins/install.ts:421-438`）
- `~/.openclaw/openclaw.json` 中 `plugins.installs` 字段（来源 `src/plugins/update.ts:266`）

---

## 前置检查

1. 确认 PLATFORM 为 OpenClaw。
2. 检查 `$OC_STATE/extensions/` 是否存在。不存在 → 输出 `未发现扩展目录` 并结束。
3. 读取 `$OC_STATE/openclaw.json`，解析 `plugins.installs` 字段获取已注册插件列表。

---

## 步骤 1：扫描扩展目录

列出 `$OC_STATE/extensions/` 下所有子目录。对每个目录读取 `openclaw.plugin.json` 获取 plugin id。

## 步骤 2：交叉对比

将每个 extension 目录的 plugin id 与 `plugins.installs` 列表对比：
- 在列表中 → 已注册（正常）
- 不在列表中 → 孤儿扩展

## 步骤 3：展示清单

列出所有孤儿扩展：
- plugin id
- 目录路径
- 目录大小（`du -sh`）

## 步骤 4：用户确认

展示孤儿清单，等待用户逐条确认后删除。

## 步骤 5：执行清理

用户确认后，`rm -rf` 对应扩展目录。

---

## 输出格式

```
[flush-orphan-extensions 完成]
- 扫描了 {N} 个扩展目录
- 发现 {M} 个孤儿扩展
- 清理了 {K} 个，释放 {X} MB
```

---

## 边界情况

- extensions/ 目录不存在 → 输出提示并结束
- openclaw.json 不存在或无法解析 → 输出错误并结束
- 所有扩展均已注册 → 输出 `扩展目录干净，无需清理`
- openclaw.plugin.json 缺失 → 标记该目录为"元数据缺失"，额外提示用户