# flush-media

OpenClaw 媒体文件清理。仅适用于 OpenClaw 平台。

---

## 平台限制

本模块仅在 OpenClaw 平台可用。Claude Code 环境下触发时，回复："这个功能仅适用于 OpenClaw 环境。"

---

## 输入

- `~/.openclaw/media/`（来源 `src/media/store.ts:15`）

---

## 前置检查

1. 确认 PLATFORM 为 OpenClaw。
2. 检查 `$OC_STATE/media/` 是否存在。不存在 → 输出 `未发现媒体文件目录` 并结束。

---

## 步骤 1：按 mtime 分桶扫描

使用 Bash 按 mtime 分桶统计：

```bash
media_dir="$OC_STATE/media"
now=$(date +%s)
echo "=== 3天内 ==="
find "$media_dir" -type f -mtime -3 2>/dev/null | wc -l
echo "=== 3-7天 ==="
find "$media_dir" -type f -mtime +3 -mtime -7 2>/dev/null | wc -l
echo "=== 7-30天 ==="
find "$media_dir" -type f -mtime +7 -mtime -30 2>/dev/null | wc -l
echo "=== 30天以上 ==="
find "$media_dir" -type f -mtime +30 2>/dev/null | wc -l
echo "=== 总大小 ==="
du -sh "$media_dir" 2>/dev/null
```

## 步骤 2：展示分桶结果

展示每个时间段的文件数和总大小。3 天以内的文件标记 🕐（3 天保护规则）。

## 步骤 3：用户选择清理范围

询问用户要清理哪个时间段的文件。选项：
- 清理 30 天以上
- 清理 7 天以上
- 清理 3 天以上（排除 🕐 标记的，除非用户明确说"加上"）
- 全部清理

## 步骤 4：执行清理

用户确认后，使用 `find ... -delete` 删除选定时间段的文件。

---

## 输出格式

```
[flush-media 完成]
- 扫描了 {N} 个媒体文件（共 {X} MB）
- 清理了 {M} 个文件，释放 {Y} MB
```

---

## 边界情况

- 媒体目录不存在 → 输出提示并结束
- 媒体目录为空 → 输出 `媒体目录为空，无需清理`
- 3 天保护规则适用
