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
- Branch `main` at `47613ff` (PR #13 "Kanto Night" UI merged). No open PRs.
- **Uncommitted, already in Studio and synced to `src/`** — the hub rebuild:
  - Hub at dusk with `HubStreet` (night lighting, prop spots, Sketchfab props placed by `HubStreet.Dress`).
  - Lobbies moved onto covered-court bleachers (Red/Blue sections per 2/4/6/8 lobby; the side you sit on is
    your team), auto-walk to a free seat (`SeatWalk` attribute), owner test bleacher.
  - Court floor texture (`assets/court/court_half.png`), covered court + bleachers in `FilipinoStreetEnvironment`.
  - Modified: `HubService`, `MatchService`, `FilipinoStreetEnvironment`, `MovementController`, `AGENTS.md`,
    `CLAUDE.md`, `tools/sync-receiver.js`. New: `HubStreet.luau`, `CREDITS.md`, `HANDOFF.md`,
    `assets/court/`, `assets/models/`, `tools/blender/{court_texture,hub_props,preview_hub}.py`.
- **Uncommitted, in Studio and synced** — run wind + role arms (match, AGENTS.md §5 *Presentation*):
  - `FirstPersonController`: wind streaks past both sides of the view + `RunWind` loop, scaled by speed.
  - New `BodyPose` controller (was `RoleArms`): Passers pump arms side to side while running, Guards hold arms
    wide (blocking); steps aside for style animations and Action tracks (tag swipe). Slide pose: body drops
    `SLIDE_DROP` (= camera dip), leans back, leg out; others see it via the `CosmeticAction` relay, now a
    reliable `RemoteEvent` carrying the slider's `UserId`; `PlayerStateService` validates it (Slide only, rate
    limit, 30-stud range). First person shows forearms + hands, legs while sliding.
  - Small hooks: `SkillEffects.TEX` exported, `StyleAnimator.IsPlaying`, `SoundController.UpdateRunWind`,
    `FirstPersonController.SetSliding` → `BodyPose.SetSliding`.
  - Verified: solo playtest (poses measured, body drop = camera dip, screenshots) and 2-client tests (slide
    pose seen by the other client; relay drops too-soon / too-far / unknown events; third-person screenshots of
    guard arms, runner pump and slide; no errors).
- **Uncommitted, in Studio and synced** — game improvements batch (AGENTS.md §5 Hub + Match):
  - Hub: short-handed lobby start (2+ seated, 30 s), weekly TUBIG board (`LeaderboardService`, never written
    from Studio), funnel steps (`FunnelService`).
  - Match: spectate when tagged, Tubig revives a teammate, server movement check (rubber-bands too-fast
    Passers), XP/levels + daily spins (`ProgressionService`, `DataService` saves `xp`/`lastDaily`/`seenGuide`),
    MVP at match over, first-match "HOW TO PLAY" card, match crowd loop, line-hop whoosh.
  - New remotes `PasserRevived`, `LevelUp`; new attributes `Tagged`, `XP`, `Level`, `SeenGuide`.
  - Verified in Studio: solo (guide card, XP/Level, 60-stud teleport rubber-banded, no false positive on
    sprint/slide), 3 clients (spectate follows teammate, Tubig revive + callout, MVP), 2 clients in the hub
    (board renders, 2/4 lobby starts after 30 s; ReserveServer is 403 in Studio as expected). No errors.
  - The live weekly board has 4 Tubigs on ExodusNeo from today's Studio tests (before Studio writes were
    blocked); remove with `RemoveAsync("1819520599")` on this week's scope if unwanted.
- **Uncommitted, in Studio and synced** — follow-up batch:
  - One 4 V 4 lobby (`PadSizes = { 8 }`): the 2/4/6 bleacher sections were deleted from the saved hub and the
    8-player pair moved to the middle of the bleachers (z 136).
  - First-time tutorial (`TutorialService`, `StudioMode = "Tutorial"` in Studio) replaces the HOW TO PLAY card;
    `SeenGuide` became `TutorialDone` (old data key still read).
  - English display names for styles/skills (ids unchanged), "the center line" instead of Patotot.
  - Verified in Studio: tutorial end to end (dummy tag → back to step 1 → finish → `TutorialDone`), dummies
    look right; style names show in the skill bar. Not verified: the hub → tutorial → hub teleports (live only).
- 2026-10-15: created the Obsidian vault; made the sync receiver skip unchanged files (it used to rewrite every
  file with LF endings, so git showed all of `src/` as modified); added rules to AGENTS.md/CLAUDE.md: sync +
  vault + handoff update after every change, always ponytail, always caveman ultra.

## Next steps / open items
- Commit the hub rebuild on a `feat/*` branch and open a PR to `main` (base PRs on `main`, never stacked).
  `tools/blender/__pycache__/` should go in `.gitignore` before committing.
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
