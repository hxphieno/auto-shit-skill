#!/bin/bash
# auto-shit-skill: 平台环境验证脚本
# 输出 CC_EXISTS, OC_EXISTS, LEGACY_EXISTS, OC_STATE
# 供模型自识别结果的交叉验证

setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null

# 检测 Claude Code 环境
CC_EXISTS=$([ -d ~/.claude ] && echo 1 || echo 0)

# 检测 OpenClaw 环境（尊重 OPENCLAW_STATE_DIR 覆盖）
OC_STATE="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OC_EXISTS=$([ -d "$OC_STATE" ] && echo 1 || echo 0)

# 检测遗留环境
LEGACY_EXISTS=$([ -d ~/.clawdbot ] && echo 1 || echo 0)

echo "CC_EXISTS=$CC_EXISTS OC_EXISTS=$OC_EXISTS LEGACY_EXISTS=$LEGACY_EXISTS OC_STATE=$OC_STATE"
