@AGENTS.md

## Claude Code notes
- Get Studio ids with `mcp__Roblox_Studio__list_roblox_studios` before any Studio call. Two places
  may be open: **Patintero Hub** (`88319696116229`) and **Patintero** match (`70710330155642`).
  Make code changes in both (or in one, then the user republishes it over the other).
- Plugins enabled for this project (`.claude/settings.json`): `ponytail` (lean changes), `roblox-skills`.
- **Always document features:** any new feature, mechanic, control, tunable or rule change (or removal)
  goes into AGENTS.md §5 (and §4 for attributes) in the same commit/PR — automatically, without being asked.
- **After every requested change:** sync Studio → `src/`, rebuild the graphify graph + Obsidian vault and
  update `HANDOFF.md`, then open a PR for it on a `feat/*`/`fix/*` branch (never push `main`; the user merges)
  (AGENTS.md §1), automatically, without being asked.
- **Always** use ponytail (`ponytail:ponytail` skill) and reply in caveman ultra (user runs `/caveman ultra`;
  ask for it if it isn't active) — AGENTS.md §2.
- **No unrequested in-game explanations:** implement requested changes without adding player-facing
  text that explains the change (see AGENTS.md top).
- **Always** invoke the matching `roblox-skills:*` skill(s) from the table in AGENTS.md §3 with the
  Skill tool before working on a task, every time, and follow ponytail's smallest-complete-change rules.
