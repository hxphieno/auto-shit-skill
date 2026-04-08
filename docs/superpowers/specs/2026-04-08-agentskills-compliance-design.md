# AgentSkills Spec Compliance — Design

**Date:** 2026-04-08
**Project:** auto-shit-skill
**Spec:** https://agentskills.io/specification

## Goal

Bring the project structure into full compliance with the AgentSkills open standard without touching any skill logic or content.

## Current Structure

```
auto-shit-skill/
├── LICENSE
├── README.md
├── version.json
└── skills/
    └── auto-shit/
        ├── SKILL.md
        ├── style.md          ← non-standard location
        └── modules/          ← non-standard directory name
            ├── flush-dot-claude.md
            ├── flush-memory.md
            ├── flush-plans.md
            ├── flush-skills.md
            ├── flush-worktrees.md
            ├── scan-context.md
            └── scan-debris.md
```

## Target Structure

```
auto-shit-skill/
├── LICENSE
├── README.md
├── version.json
└── skills/
    └── auto-shit/
        ├── SKILL.md          ← updated frontmatter
        └── references/       ← renamed from modules/, style.md moved in
            ├── style.md
            ├── flush-dot-claude.md
            ├── flush-memory.md
            ├── flush-plans.md
            ├── flush-skills.md
            ├── flush-worktrees.md
            ├── scan-context.md
            └── scan-debris.md
```

## Changes

### 1. Rename `modules/` → `references/`

The AgentSkills spec defines three standard optional directories: `scripts/`, `references/`, and `assets/`. All files in `modules/` are markdown documentation loaded on demand — semantically they are references, so `references/` is the correct name.

### 2. Move `style.md` into `references/`

`style.md` is currently at the skill root alongside `SKILL.md`. The spec recommends the root stay focused (`SKILL.md` + standard subdirectories). `style.md` is reference material read on demand, so it belongs in `references/`.

### 3. Update path references in `SKILL.md`

All six `Read modules/...` instructions in `SKILL.md` must be updated to `Read references/...`. This includes the routing table and the "全量清理" section.

### 4. Add `compatibility` and `metadata` to `SKILL.md` frontmatter

```yaml
compatibility: Designed for Claude Code (or similar agent environments)
metadata:
  author: hxphieno
  version: "1.0.0"
```

## Out of Scope

- `version.json` — Claude Code plugin system field, not governed by AgentSkills spec
- `README.md` — no changes needed
- `LICENSE` — no `license` frontmatter field added (user preference)
- All skill content and logic — zero changes to behavior
