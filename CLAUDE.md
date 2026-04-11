# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code / OpenClaw skill that cleans up accumulated garbage in the agent's persistent environment (stale memory, old sessions, abandoned worktrees, ghost skill configs, outdated plans). It never touches user project code.

No build system, no dependencies, no tests. Development is editing Markdown files and testing trigger phrases manually.

## Architecture

The skill is entirely specification-driven:

- **`SKILL.md`** — the skill entry point. Contains frontmatter registration, trigger phrase routing, and the quick-scan Bash script. When a trigger fires, SKILL.md either handles it directly or delegates by calling `Read references/<module>.md` and executing its instructions.
- **`references/`** — standalone specification files. Each describes input paths, detection logic, user confirmation UX, and output format for one cleanup domain. They are not executable — SKILL.md reads them and implements their logic using CC tools.
- **`references/style.md`** — output templates and visual markers (✓ / ✗ / 🕐). All modules must render output through these templates.
- **`scripts/`** — Bash scripts for platform detection and file collection. `scan-cc.sh` and `scan-openclaw.sh` collect platform-specific state; `scan-common.sh` collects cross-platform state (plans, git). SKILL.md calls these instead of inlining Bash.
- **`references/platforms/`** — Platform constant files (`cc.md` and `openclaw.md`). Each module reads the appropriate platform file to get path constants.
- **`version.json`** — semantic version metadata consumed by the CC plugin system.

### Trigger → Module mapping

| Trigger | Action |
|---------|--------|
| `shit` / `拉屎` / `auto-shit` | Quick scan inline in SKILL.md (no module read) |
| `冲水` / `flush` | Ask which module, then `Read references/flush-*.md` |
| `便秘了` / `scan` | `Read references/scan-context.md` |
| `大扫除` / `全冲` | All 6 modules sequentially, pause between each |
| `定点拉屎` | Register durable cron via CronCreate |
| `别拉了` | Cancel via CronList + CronDelete |
| `冲旧图` | OpenClaw: `Read references/flush-media.md` (媒体文件清理) |
| `退旧房` | OpenClaw: `Read references/flush-workspaces.md` (废弃工作区清理) |
| `拔废管` | OpenClaw: `Read references/flush-orphan-extensions.md` (废弃扩展清理) |

### Safety rules (must be preserved in all edits)

1. Destructive operations require explicit user confirmation — scanning is always non-destructive.
2. **3-day protection**: files with mtime < 3 days are marked 🕐 and excluded from auto-cleanup recommendations. Users can override with "加上 N".
3. `flush-state` must skip `scheduled_tasks.json` entries prefixed `[auto-shit-cron]` to avoid self-deletion.
4. Never modify the active session context or currently-used config files.

## Adding a New Cleanup Module

1. Create `references/flush-<domain>.md` following the pattern of existing flush files (input paths → pre-checks → detection phases → output via style.md → confirmation gate). Modules can be platform-specific (referencing `references/platforms/cc.md` or `references/platforms/openclaw.md`) or cross-platform.
2. Add a trigger row to the `冲水` routing table in `SKILL.md`.
3. Add the module to the `大扫除` sequential list in SKILL.md.
4. Bump `version.json`.

## Shell Compatibility

All Bash in SKILL.md must run on both zsh and bash (macOS primary). Start every script with:

```bash
setopt nullglob 2>/dev/null || shopt -s nullglob 2>/dev/null
```

Use `stat -f %m` (macOS) with `|| stat -c %Y` (Linux) fallback for mtime. Add `2>/dev/null` to all glob expansions.

## Project Hash Path

CC stores per-project state at `~/.claude/projects/<hash>/` where hash is derived from the working directory:

```bash
echo "$(pwd)" | sed 's/[^a-zA-Z0-9]/-/g'
```

The quick-scan script resolves this with `ls -d ~/.claude/projects/$(...)* | head -1`.
