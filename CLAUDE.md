@AGENTS.md

## Claude Code notes
- Get Studio ids with `mcp__Roblox_Studio__list_roblox_studios` before any Studio call. Two places
  may be open: **Patintero Hub** (`88319696116229`) and **Patintero** match (`70710330155642`).
  Make code changes in both (or in one, then the user republishes it over the other).
- Plugins enabled for this project (`.claude/settings.json`): `ponytail` (lean changes), `roblox-skills`.
- **Always** invoke the matching `roblox-skills:*` skill(s) from the table in AGENTS.md §3 with the
  Skill tool before working on a task, every time, and follow ponytail's smallest-complete-change rules.
