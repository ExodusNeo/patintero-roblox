# Patintero: Styles — Agent Guide

First-person Roblox game inspired by the Filipino street game **Patintero**, with
rollable **Styles** (rarity-weighted, each with a passive + two skills) in the spirit of
*Untitled Boxing Game*. Language: Luau (`--!strict`).

---

## 1. Workflow: Studio MCP is the source of truth

- The live Studio place (**Patintereoreoreoro**, placeId `88319696116229`) is authoritative.
  Read, edit and test through the **Roblox Studio MCP** tools, not Rojo:
  - Discover: `list_roblox_studios` (get `studio_id`), `search_game_tree`, `script_search`, `script_grep`.
  - Read/edit: `script_read`, `multi_edit` (also creates scripts — pass `className`).
  - Run/verify: `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output`, `screen_capture`.
- `src/` + `default.project.json` are a **Rojo mirror for git only**. It may lag Studio.
  Before committing, sync Studio → `src/`: run `node tools/sync-receiver.js .` in the background, then
  `execute_luau` (Edit) the contents of `tools/studio-sync-sender.luau`; review `git diff`, commit.
  (Deleted scripts are not removed from `src/` by the sync — delete those files by hand.)
  Never `rojo serve` over Studio without syncing first.
- Edits only persist when the user saves the place in Studio (Ctrl+S / publish). Remind them after big changes.
- Verify every gameplay change with a playtest: `start_stop_play` → `get_console_output` → stop.
- `.codegraph/` (CodeGraph index) only reflects `src/` on disk; use it for disk-side work only.

### Two places, one place file
- The experience has a **Hub** place (start place, `88319696116229`) and a **Match** place.
  The *same* place file is published to both; `Modules.GameMode` picks the side from `game.PlaceId`
  (`Config.Places`). Each server deletes the other side's map on start (`Workspace.Hub` /
  `Workspace.PatinteroCourt` + court `SpawnLocation`).
- After every change: publish to the Hub place **and** "Publish to Roblox As…" the Match place.
- Studio playtests default to the hub. To test the court, set Workspace attribute
  `StudioMode = "Match"` (clear it afterwards). Teleports never work in Studio; test them live.
- Match place Access setting should be *Secure within universe only* (Creator Dashboard).

## 2. Cost discipline (plugins)

- **ponytail** plugin is on for this project: smallest complete change, reuse before writing,
  no speculative abstractions. Use `/ponytail-review` before committing and `/ponytail-debt`
  to list `shortcut:` comments.
- Read only the scripts a change touches; prefer `script_grep` over reading whole files.
- Don't re-read a script you just edited.

## 3. Roblox skills — always apply the matching skill

**Rule:** before reading, writing, reviewing or debugging code, load every skill below that matches
the task (if the skill tool is available) and follow it. This applies to small fixes too, not
only new systems. If several rows match, load all of them. If none match, say so and continue.

| Task | Skill |
| --- | --- |
| Where code lives, client/server split, lifecycle | `roblox-skills:roblox-architecture` |
| Rounds, teams, combat, currency, progression | `roblox-skills:roblox-game-systems` |
| Saving spins / styles | `roblox-skills:roblox-data-stores` |
| Remotes, validation, rate limits | `roblox-skills:roblox-networking`, `roblox-skills:roblox-security` |
| Keybinds, camera, first person | `roblox-skills:roblox-input` |
| Movement, humanoid, animations | `roblox-skills:roblox-characters-animation` |
| Dashes, raycasts, physics | `roblox-skills:roblox-physics` |
| HUD, spin menu, mobile layout | `roblox-skills:roblox-ui` |
| Map, lighting, VFX | `roblox-skills:roblox-world-building` |
| Sounds | `roblox-skills:roblox-audio` |
| Lag / FPS | `roblox-skills:roblox-performance` |
| Reviews before release | `roblox-skills:roblox-code-review` |
| Driving Studio from the agent | `roblox-skills:roblox-studio-mcp` |

## 4. Code conventions

- Every script starts with `--!strict`.
- Shared types: `ReplicatedStorage.Shared.Modules.Types`. Tunables: `...Modules.Config`.
  Style roster: `...Modules.Styles` (pure data, readable by client and server).
- Server logic = Services in `ServerScriptService.Server.Systems`, started by `Server.Runtime`.
- Client logic = Controllers in `StarterPlayerScripts.Client.Controllers`, started by `Client.Runtime`.
- Remotes are declared once in `...Modules.Remotes`.
- **Never trust the client**: validate type, range, cooldown, team and distance on every remote.
  Client-side prediction is fine for the caster's own movement (dash/blink); anything that
  affects other players or scoring is decided on the server.
- Runtime state the client renders goes on attributes:
  - Player: `Spins` (number), `Style` (style id), `Team`, `Teleporting`.
  - Character: `HasteMult`, `SlowMult`, `ReachBonus`, `TagImmune` (timed, set by `StyleService`).
- Clean up connections on character removal; use `UnreliableRemoteEvent` for cosmetics.
- Commits: Conventional Commits (`feat(scope): …`, `fix(scope): …`), one per finished system.

---

## 5. Game design

### Hub (third person)
- Players join the hub plaza. Four queue pads need 2 / 4 / 6 / 8 players (`PadSize` attribute on
  parts in `Workspace.Hub.Pads`; add or move pads freely). A full pad counts down
  (`Config.Hub.CountdownTime`), cancelled if anyone steps off, then `HubService` reserves a match
  server and `TravelService` teleports the group.
- Spinning for Styles happens **only in the hub** (G menu). Skills (Q/E) can be tried in the hub.
- Data is saved and released before every teleport (`DataService.Release`) so the next server
  never loads stale spins; the `Teleporting` player attribute blocks spins/queueing meanwhile.

### Match (first person) — Core loop (Patintero)
- The match server waits for the party the hub sent (`expectedPlayers` teleport data, max
  `Config.Match.ArrivalTimeout` s), plays 2 rounds, then teleports everyone back to the hub.
- Two teams per round: **Passers** (runners) and **Guards** (taggers). Sides swap after each round; 2 rounds per match.
- Guards are locked to chalk lines: `Line1`, `Line2`, `Line3` (across the court) and the
  `Patotot` (center line along the court). They tag with left click / F.
- Passers run Home → Zone 1 → Zone 2 → Safehouse (outbound, +1 per zone in order),
  then back to Home for **"TUBIG!"** (+5). Zones must be cleared in order (no farming).
- A tagged Passer is out for the round and sent to the sideline. Round ends at time-out or when
  all Passers are out.
- First person is forced (`LockFirstPerson`). Shift = sprint, C/Ctrl = slide, stamina-limited.

### Styles (rolled with Spins)
- Every player has one equipped Style. **Spin** (hub, menu key `G`) rolls a new one by rarity weight;
  the result replaces the current Style.
- Rarities: Common 55%, Rare 30%, Epic 12%, Legendary 3% (see `Config.Styles`).
- Spins: start with 10; +1 per round played, +1 per Tubig. Saved in DataStore with the Style.
- Each Style = passive stat modifiers (speed, stamina, reach) + **Q** and **E** skills.
- Skill kinds: `Dash`, `Blink`, `Haste`, `SecondWind`, `LongArm`, `Slow` (area, enemies only;
  `mult = 0` is a freeze), `Veil` (tag-immune + see-through). Roster lives in `Styles.luau`.
