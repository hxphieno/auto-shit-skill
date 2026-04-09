# 拉屎.skill 🚽

> "人也是要带薪拉屎的，更何况AI呢"

<div align="center">
  <a href="https://claude.ai"><img src="https://img.shields.io/badge/Claude-Built_with_AI-c96442?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJhMTAgMTAgMCAxIDAgMCAyMCAxMCAxMCAwIDAgMCAwLTIwbTAgMS44YTEuMiAxLjIgMCAwIDEgLjg1LjM1bDEuNSA0LjVhLjYuNiAwIDAgMCAuMzUuMzVsNC41IDEuNWExLjIgMS4yIDAgMCAxIDAgMi4yN2wtNC41IDEuNWEuNi42IDAgMCAwLS4zNS4zNWwtMS41IDQuNWExLjIgMS4yIDAgMCAxLTIuMjcgMGwtMS41LTQuNWEuNi42IDAgMCAwLS4zNS0uMzVsLTQuNS0xLjVhMS4yIDEuMiAwIDAgMSAwLTIuMjdsNC41LTEuNWEuNi42IDAgMCAwIC4zNS0uMzVsMS41LTQuNUExLjIgMS4yIDAgMCAxIDEyIDMuOCIvPjwvc3ZnPg==&labelColor=333" alt="Built with Claude"></a>
  <img src="https://img.shields.io/badge/Claude_Code-v2.1.92+-blueviolet" alt="Requires Claude Code v2.1.92+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</div>

---

你有没有遇到过这种情况：

明明是个小需求，Claude 却像一个记性越来越差的老同事——之前谈好的规范忘了，上次清理的垃圾又堆回来了，context 里塞满了过期的 plan、用了一半的 worktree、不知道哪来的 memory 条目。

**Claude Code 的工作环境，也需要定期排毒。**

这个 skill 做的，就是帮你的 Claude Code 养成上厕所的习惯。

---

## 这能解决什么问题

Claude Code 在工作过程中会积累大量可能再也不会用到的文件：

- 📝 Memory 里的过时条目（三个月前的 bug 修复经验早该归档了）
- 🗂️ Plans 目录里躺着的已完成文档（做完了还挂着干什么）
- 🌿 Git worktrees 里的僵尸目录（分支删了，目录还在）
- 🔌 Plugin cache 里的孤儿缓存（插件都卸了，cache 还没走）
- ⚙️ .claude/config 里的冗余配置（历史遗留，无人认领）
- 📜 Session transcripts（早结束的会话，还占着位置）

这些东西不影响你写代码，但会影响 Claude 的判断质量以及token消耗。

**拉屎.skill 只清理 Claude Code 自身的环境，不碰你的项目代码。**

---

## 安装

```bash
# 全局安装（所有项目都能用，推荐）
git clone https://github.com/hxphieno/auto-shit-skill ~/.claude/skills/auto-shit-skill
```

或安装到当前项目：

```bash
mkdir -p .claude/skills
git clone https://github.com/hxphieno/auto-shit-skill .claude/skills/auto-shit-skill
```

安装后重启 Claude Code 即生效，无需修改任何配置文件。

> 💡 嫌手动麻烦？让 AI 全程代理安装约消耗 1.3k tokens。
>
> **openClaw 适配进行中**
>
> 项目中的提示词是针对 Claude Code 优化的。我们尝试直接在 openClaw 上运行，目前测试中——有时工作良好，有时效果不太理想。适配优化正在推进，下个版本火速上线。

---

## 项目结构

```
auto-shit-skill/
├── references/
│   ├── flush-dot-claude.md
│   ├── flush-memory.md
│   ├── flush-plans.md
│   ├── flush-skills.md
│   ├── flush-worktrees.md
│   ├── scan-context.md
│   ├── scan-debris.md
│   └── style.md
├── .gitignore
├── LICENSE
├── README.md
├── SKILL.md
└── version.json
```

---

## 怎么用

直接在对话框里说触发词就行，不需要记命令格式。

| 你说什么 | 会发生什么 |
|----------|------------|
| `shit` / `该拉屎了` / `拉屎` / `autoshit` | 快速检查：扫描所有维度，输出摘要报告，**不修改任何文件** |
| `flush` / `冲水` | 按模块逐项执行清理，有问题的地方停下来问你 |
| `便秘了` / `堵了` / `体检` / `scan` | 深度诊断模式，比快速检查更细 |
| `大扫除` / `全冲` | 全量清理，每一步都等你确认再动 |
| `定点拉屎` | 注册定时检查任务，到点自动跑 |
| `别拉了` / `取消定时` | 取消定时任务 |
| `查异物` / `扫残留` | 专门扫描项目里的残留文件 |

**建议：** 先跑一次 `shit` 看看报告，确认没问题再用 `flush` 清理。

---

## 效果示例

输入 `shit`，你会看到类似这样的检查报告：

```
[如厕结果]

Memory: 0 条
  空的，留着蹲/

Sessions: 6 个 transcript
  - a1b2c3d4.jsonl (5.8MB)  - 当前项目完整开发史 → 归档价值高，保留
  - e5f6a7b8.jsonl (284KB)  - 无关探索记录 → 与当前项目无关 ✗
  - c9d0e1f2.jsonl (136KB)  - 旧操作记录 ✗
  - a3b4c5d6.jsonl (144KB)  - 空跑测试，无实质内容 ✗
  - e7f8a9b0.jsonl  (32KB)  - 旧调试记录 ✗
  - [当前 session]          → 活跃保护，强制保留

Plans: 2 份
  - 2026-04-07-project-design.md   "项目设计文档" → 当前活跃，保留
  - 2026-04-08-implementation.md   "实现计划"     → 已完成 ✗

Skills: 0 个幽灵配置，hooks 均存在
Plugin Cache: 4 个副本，均为正常安装插件
settings.local.json: 含历史一次性权限（无害）
Worktrees: 非 git 仓库，跳过

---

建议冲水清单：
  1. e5f6a7b8.jsonl (284KB)
  2. c9d0e1f2.jsonl (136KB)
  3. a3b4c5d6.jsonl (144KB)
  4. e7f8a9b0.jsonl  (32KB)
  5. 2026-04-08-implementation.md

直接说 "冲水" 清理以上全部，或告诉我要增减哪些项目。
```

---

## 清理范围

```
~/.claude/
├── memory/          ← 过时条目、无关记录
├── sessions/        ← 已结束的旧会话 transcript
├── plans/           ← 已完成的 plan/spec 文档
└── plugins/cache/   ← 孤儿缓存、重复缓存

.claude/ (项目级)
├── settings.json    ← 冗余配置项
└── worktrees/       ← 已删除分支的残留目录
```

---

## 进阶

### 自定义输出风格

本项目核心功能是扫描和清理 Claude Code 的环境文件。风格定义独立于功能实现，可以自由定制。

如需修改输出风格（改为严肃风格、不同语言、不同格式等），直接编辑 `references/style.md` 文件即可。该文件包含所有输出模板和提示词，不涉及核心清理逻辑的修改。

---

## 日常提醒

不管你是否使用这份 Skill，都请每天记得要及时地上厕所！

