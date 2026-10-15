# Handoff: Patintero: Styles

Start a new conversation in this folder with `/caveman ultra`, then: **"Read HANDOFF.md, CLAUDE.md and
AGENTS.md, then continue."** Rules, workflow and the full game design live in `AGENTS.md`; this file is only
the current state. Agents update it after every change (AGENTS.md §1).

## Project at a glance
- First-person Roblox Patintero game with rollable Styles. Luau `--!strict`.
- Repo: `D:\RobloxProjects\PatinteroRobloxVerr`, GitHub `ExodusNeo/patintero-roblox` (`gh` logged in as ExodusNeo).
- **Roblox Studio is the source of truth** (via the Roblox Studio MCP). `src/` is a git mirror synced from Studio.
- Places (one place file published to both): **Patintero Hub** `88319696116229` (start place) and
  **Patintero** match `70710330155642`. After code changes, publish to the hub **and** "Publish to Roblox As…"
  the match place.
- Studio MCP `studio_id` changes whenever Studio reconnects: call `list_roblox_studios` first.

## After every change (mandatory, see AGENTS.md §1)
1. Sync Studio → `src/`: `node tools/sync-receiver.js .` in the background, then `execute_luau` (Edit) the
   contents of `tools/studio-sync-sender.luau`. Delete `src/` files of scripts removed in Studio by hand.
2. Rebuild the graph + Obsidian vault from the repo root: `graphify update .` then `graphify export obsidian`.
3. Update this file.
4. Review `git diff`, then open a PR: commit on a `feat/*`/`fix/*` branch, push it, `gh pr create` to `main`
   (or push to the branch's still-open PR). Never push `main`; the user merges.

## Obsidian vault
- Vault: `graphify-out/obsidian/` (one note per script/function, links = calls/requires, plus `graph.canvas`).
  Registered in Obsidian (`%APPDATA%\obsidian\obsidian.json`). `graphify-out/` is local and not committed.
- graphify has two local Luau patches in site-packages that a `pip install --upgrade graphifyy` removes
  (Luau grammar + Roblox `require` resolution). If `.luau` files start reporting syntax errors or
  `script_parent_*` nodes appear, the patches are gone.
- Five files produce no notes (`Config`, `Types`, `StyleAnimations`, `Runtime.client`, `studio-sync-sender`):
  they hold data/types or top-level code only. Expected.

## Current state (2026-10-16)
- `main` at `e1169a3`: **PR #14 merged** (covered-court hub with one 4 V 4 lobby + short-handed start, weekly
  TUBIG board, run wind + `BodyPose`, spectate + TUBIG revive, server movement check, XP/levels + daily spins,
  MVP, crowd loop, line-hop whoosh, `MatchLoop` funnel, English style names, first-time tutorial). Details per
  feature in AGENTS.md §5.
- **Open: PR #15** (`feat/interactive-tutorial`) — the tutorial reworked to
  be learn-by-doing: 7 steps that complete on the action (sprint, slide, Zone 2 past a guard, a skill, Safehouse,
  TUBIG with fanfare, guard practice tagging a runner), guards that track you along their line, a step card +
  world beacon (`TutorialController`), +3 spins on finishing. New remote `PracticeTag`, type `TutorialStepInfo`.
  - Verified in Studio (`StudioMode = "Tutorial"`): every step completes on its action (walking into Zone 1
    without sprinting does not), guards spawn at step 3 and tag, guard practice tag → complete, `TutorialDone`,
    +3 spins; card and beacon screenshotted. Fixed during the test: a tag on the way home used to send you home
    and finish TUBIG; it now sends you to the Safehouse (that fix was read-checked, not replayed).
- Live data note: the weekly board has 4 Tubigs on ExodusNeo from Studio tests (before Studio writes were
  blocked); remove with `RemoveAsync("1819520599")` on this week's scope if unwanted.
- Not verified anywhere yet (live only): hub → match / tutorial → hub teleports, reserved servers, funnel data.

## Next steps / open items
- Review and merge PR #15.
- Save the place (Ctrl+S), publish the hub and republish over the match place, so the wind/arms go live.
- Paste the `CREDITS.md` list into the game description (CC BY props require attribution).
- Republish over the match place after the hub changes, then test the hub → match → hub loop live with the
  owner test bleacher (teleports don't work in Studio). Live-check the tutorial with a fresh account (or clear
  `tutorialDone`/`seenGuide` in your saved data). Live-check: funnel `MatchLoop` in Creator Dashboard
  Analytics, weekly board filling, daily spins on a new day.

## Future work (not built yet)
- **NPC guard bots** to fill empty guard slots (line-locked AI that tags; needs Team/role support for non-player
  characters in `PlayerStateService`/`TagService`), and a **practice court** in the hub with those NPCs.
- **Badges** (first Tubig, 10 tags, Legendary roll): create the badges in Creator Dashboard, then award with
  `BadgeService:AwardBadgeAsync` from MatchService/StyleService.
- **Monetization**: spin pack (developer product + idempotent `ProcessReceipt`), "2x spins" game pass, private
  servers. Needs product/pass ids from Creator Dashboard; consider ProfileStore session locking first
  (DataService has a `shortcut:` note: last write wins).
- **Level cosmetics** (trail / slide-dust / chalk colors unlocked per level).
- **TUBIG replay** / kill-cam style replay.
- Footsteps on asphalt/court (not checked whether Roblox's default character sounds play in this build).
