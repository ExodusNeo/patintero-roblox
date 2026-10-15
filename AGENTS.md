# Patintero: Styles — Agent Guide

First-person Roblox game inspired by the Filipino street game **Patintero**, with
rollable **Styles** (rarity-weighted, each with a passive + two skills) in the spirit of
*Untitled Boxing Game*. Language: Luau (`--!strict`).

> **Keep this file current (mandatory).** Every new feature, mechanic, rule change, control,
> tunable or removed feature must be written into this file (usually §5 Game design, plus §4 for
> new attributes/conventions) **in the same commit / PR as the code**. A feature is not done until
> it is documented here. Update or delete lines that are no longer true — never leave stale docs.
>
> **No unrequested in-game explanations.** When the user asks for a change, implement it — don't
> add UI text that explains or announces the change to players (e.g. "You keep one style").
> Only add player-facing text the user actually asked for.

---

## 1. Workflow: Studio MCP is the source of truth

- The live Studio places are authoritative: **Patintero Hub** (start place, `88319696116229`) and
  **Patintero** (match place, `70710330155642`). Read, edit and test through the
  **Roblox Studio MCP** tools, not Rojo:
  - Discover: `list_roblox_studios` (get `studio_id`), `search_game_tree`, `script_search`, `script_grep`.
  - Read/edit: `script_read`, `multi_edit` (also creates scripts — pass `className`).
  - Run/verify: `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output`, `screen_capture`.
- `src/` + `default.project.json` are a **Rojo mirror for git only**. It may lag Studio.
- **After every change the user asks for (mandatory, without being asked), sync and rebuild the vault:**
  1. Sync Studio → `src/`: run `node tools/sync-receiver.js .` in the background, then `execute_luau` (Edit)
     the contents of `tools/studio-sync-sender.luau`. The receiver only rewrites files whose source changed.
     Deleted scripts are not removed from `src/` by the sync — delete those files by hand.
  2. Rebuild the code graph and Obsidian vault from the repo root: `graphify update .` then
     `graphify export obsidian` (vault: `graphify-out/obsidian/`, local only, not committed).
  3. Update `HANDOFF.md` (*Current state* and *Next steps*: what changed, what is uncommitted, open items),
     so a new conversation can pick up from it.
  4. Review `git diff`, then open a pull request for the change (the user asked for a PR per change, so this
     needs no extra request): commit on a `feat/<topic>` or `fix/<topic>` branch made from an up-to-date `main`
     (Conventional Commits), push the branch, and open a PR to `main` with `gh`. If that branch's PR is still
     open, push to it instead; if it was merged, start a new branch. Never push to `main`; the user merges PRs.
  Never `rojo serve` over Studio without syncing first.
- Edits only persist when the user saves the place in Studio (Ctrl+S / publish). Remind them after big changes.
- Verify every gameplay change with a playtest: `start_stop_play` → `get_console_output` → stop.
- **Multiplayer tests** (no clicking needed): from Edit, `task.spawn` a call to
  `StudioTestService:ExecuteMultiplayerTestAsync(2, args)`. The server and each client then appear in
  `list_roblox_studios` (name `null`; `get_studio_state` shows which is focused on Server).
  Drive them with `execute_luau` (Server/Client), end with `StudioTestService:EndTest(...)` on the server.
  Manual equivalent: testing dropdown → **Server & Clients** → Play (F7) → End Session.
- `.codegraph/` (CodeGraph index) only reflects `src/` on disk; use it for disk-side work only.

### Blender assets (Blender MCP) — `tools/blender/`, `assets/`
- **Style animations** are authored in `tools/blender/style_anims.py` (the source of truth: keyframes in
  Roblox joint space, see its header). In Blender: `exec` `rig.py` (default R15 rig, exact joint layout
  from Studio, in its own `PatinteroAnim` scene), then `style_anims.py` → `build_actions()` (one action
  per animation, saved in `assets/blender/StyleAnimations.blend`) and `export_luau(...)` to regenerate
  `src/shared/Modules/StyleAnimations.luau`. `preview.py` → `sheet([(name, keyIndex), ...])` lines up
  posed rig copies for one-render pose checks (the rig faces +Y; view it from the front). Push the
  regenerated module into Studio (it is generated: never hand-edit it).
  Grounded poses use `stance(drop, r=(fwd, out), l=(fwd, out), px, pz)` / `leg(side, drop, fwd, out)`: an exact
  2-bone IK that keeps the feet flat and planted while the root drops or shifts. Use them for any pose with
  feet on the ground, otherwise the feet sink or float.
- **Effect sprites** come from `tools/blender/fx_textures.py` (white-on-transparent PNGs in `assets/fx/`),
  uploaded with the Studio MCP `upload_image` tool (serve `assets/fx` on localhost); the ids live in
  `SkillEffects.TEX`. Re-upload and update the ids if a sprite changes.
- **Hub props (Sketchfab)**: `tools/blender/hub_props.py` (run in Blender with the Sketchfab add-on logged in;
  its token is reused, never stored) downloads the `PROPS` list (CC Attribution or CC0 only: no NonCommercial,
  NoDerivatives or Sketchfab Standard), scales them to studs (1 m = 3.2 studs), origins at the bottom center,
  decimates the heavy ones, caps textures at 1024 and splits each prop by material (Roblox gives a MeshPart one
  texture): an Empty `Prop_<Key>` holding `Prop_<Key>_<n>` meshes, exported as `assets/models/HubProps.fbx`, plus
  `HubProps_colors.json` (base colors of untextured parts). Roblox can't take a Blender file directly: the owner
  imports the FBX once (File → Import 3D), then the templates live in `ServerStorage.HubProps` (untextured parts
  colored from the JSON) and `HubStreet.Dress` places copies. Every model is credited in `CREDITS.md`; paste that
  list into the game description (CC BY requires attribution).
- **Court floor** (hub): `tools/blender/court_texture.py` paints one half court on worn concrete (green court,
  red key and border, white lines, FIBA layout scaled to studs) into `assets/court/court_half.png`; both floor
  halves use it (`HubService.COURT_TEXTURE`; each half turned so the image top, the center line, meets in the middle). From Cowork, Blender can serve the
  repo on localhost (a threaded `http.server`) for `upload_image` and for pulling `src/` files into Studio.
- **Previewing a Studio build** when Studio's viewport can't be captured (window in the background):
  `tools/blender/preview_hub.py` rebuilds BaseParts that Studio POSTs as JSON (see its header) in a `HubPreview`
  scene and renders camera shots given in Roblox coordinates. It doesn't draw SurfaceGuis. (Checked in Studio: a
  Top-face Decal's image top points at the part's +Z, and a Top-face SurfaceGui's width runs along the part's Z.)
- **UI art ("Kanto Night")** is the hand-drawn art of the Figma file "Patintero UI" (Direction B): chalk
  strokes, key boxes, torn patches, paint plates, the streetlamp light. The Figma SVGs live in
  `assets/ui/kanto/src/`; `python tools/ui_kanto.py` turns them into white, tintable PNGs in `assets/ui/kanto/`
  (headless Chrome). Uploaded the same way; ids live in `UIKit.Art` (the pad signs in `HubService` reuse the
  Patch / TeamMark ids). The skill-kind icons and the glow still come from `tools/blender/ui_assets.py`
  (`UIKit.Icon` / `UIKit.Image`; the shockwave ring reuses the `fx_ring` effect sprite).
- Disk → Studio for generated/new files: serve `src/` on localhost and `HttpService:GetAsync` each file
  into its ModuleScript from an Edit-mode `execute_luau` (HttpEnabled on briefly, then restored).

### Two places, one place file
- The experience has a **Hub** place (start place, `88319696116229`) and a **Match** place.
  The *same* place file is published to both; `Modules.GameMode` picks the side from `game.PlaceId`
  (`Config.Places`). Each server deletes the other side's map on start (`Workspace.Hub` /
  `Workspace.PatinteroCourt` + court `SpawnLocation`).
- After every change: publish to the Hub place **and** "Publish to Roblox As…" the Match place.
- Studio playtests default to the hub. To test the court, set Workspace attribute
  `StudioMode = "Match"` (clear it afterwards), or `"Tutorial"` for the first-time tutorial. Teleports never
  work in Studio; test them live.
- Match place Access setting should be *Secure within universe only* (Creator Dashboard).

## 2. Cost discipline (plugins)

- **Always use ponytail** on this project (load the `ponytail:ponytail` skill at the start of every task):
  smallest complete change, reuse before writing, no speculative abstractions. Use `/ponytail-review`
  before committing and `/ponytail-debt` to list `shortcut:` comments.
- **Always reply in caveman ultra.** It is user-invoked only (agents can't load it): if it isn't active at the
  start of a session, ask the user to run `/caveman ultra`.
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
  - Player: `Spins` (number), `Style` (style id), `Team` (current role), `Side` (`Red`/`Blue` match team), `Teleporting`,
    `Tagged` (out this round), `XP` / `Level` (`ProgressionService`), `TutorialDone` (finished the tutorial or a match; saved,
    the old data key `seenGuide` still counts).
  - Character: `HasteMult`, `SlowMult`, `ReachBonus`, `TagImmune` (timed, set by `StyleService`);
    `SeatWalk` (Vector3, hub: the point `HubService` is walking you to on the way to a lobby seat).
- Clean up connections on character removal; use `UnreliableRemoteEvent` for frequent cosmetics. Exception:
  `CosmeticAction` (slides) is a reliable `RemoteEvent` because other clients pose the slide from it; the
  server only relays `"Slide"`, at most once per `0.8 × SlideCooldown`, within 30 studs of the sender.
- Commits: Conventional Commits (`feat(scope): …`, `fix(scope): …`), one per finished system.

---

## 5. Game design

### Hub (third person)
- A Filipino barangay street at dusk (`HubService.BuildHub` + `HubStreet`, saved as `Workspace.Hub`): welcome
  arch "Maligayang Pagdating sa Barangay Patintero" past the spawn (two uplights on the sign); houses with a grime
  band, grilled windows (some lit), wall lamps, balconies with laundry and hand-painted signs ("BAWAL UMIHI
  DITO!", ...); Aling Nena's sari-sari store in its own gap in the right-hand row (grilled storefront, counter,
  lit shelves, awning with snack strips, painted sign); concrete poles with sodium streetlamps, spaghetti wires,
  service drops and banderitas, all past the arch (poles at z = -28 / 22 / 72); patched asphalt,
  manholes and a painted speed hump; gutters with grates, yellow/white curbs; invisible boundary walls and an
  invisible spawn. Houses, the store and the road carry `PropSpot` attachments (`Kind`: Meter, Aircon, Plant,
  Drum, Bin, LPG, Monobloc, TableSet, Jeepney, Tricycle) where `HubStreet.Dress` puts the imported props (anchored,
  scaled to their height, bottom on the spot; vehicles parked on the right-hand side of their lane).
  `HubStreet.SetupNightLighting` runs on hub start (blue hour, cool ambient, haze, bloom); the match keeps its
  golden hour. The far end opens onto a plaza with the
  **barangay covered court** (`HubService.BuildCourtPlaza`, model `CourtPlaza`): painted court floor, a hoop at
  each end, steel columns and arched trusses under a GI-sheet roof, floodlights, a "BARANGAY PATINTERO COVERED
  COURT" tarpaulin over the entrance, and concrete bleachers along both sidelines (Red risers on one, Blue on
  the other; `FilipinoStreetEnvironment.BuildCoveredCourt` / `BuildCourtBleachers`).
- **Lobby** = one 4 V 4 bleacher section pair in the middle of the bleachers (`Config.Hub.PadSizes = { 8 }`; one
  lobby so the few players online gather in one place; `BuildCourtPlaza` lays out a pair per size):
  each has a Red section on one sideline facing its Blue section straight across the court, with half the
  lobby's seats each. Each section is a zone part in `Workspace.Hub.Pads` (attributes `PadSize`, `Lobby`, `Side`,
  `Title`; its `Seat`s are children) with a chalk box on the floor, the name on the riser and a sign. When every
  seat of a lobby is taken it counts down (`Config.Hub.CountdownTime`), cancelled if anyone stands up, then
  `HubService` reserves a match server and `TravelService` teleports the group. **The side you sit on is your
  team**: the teleport data carries `sides` (userId → `Red`/`Blue`) and `MatchService.assignTeams` keeps it.
  **Short-handed start**: a lobby that isn't full starts its countdown anyway once `Config.Hub.MinToStart` (2)
  players have sat there for `Config.Hub.FillTimeout` (30 s); the sign shows `n/size · Ns` while it waits, and
  `assignTeams` evens out the sides.
- **Weekly TUBIG board** (`HubService.buildLeaderboard` + `LeaderboardService`, model `Workspace.Hub.WeeklyBoard`,
  built at runtime beside the spawn): top `Config.Hub.LeaderboardSize` Tubig scorers this week (Monday 00:00 UTC),
  from the OrderedDataStore `Config.Data.WeeklyTubigStore` (scope = week number), refreshed every
  `LeaderboardRefresh` s. Matches add each Tubig (`LeaderboardService.RecordTubig`; never from Studio).
- **Lobby seats** (`HubService.updateSeats`): stepping into a section's zone hands you the nearest free seat on
  that side (a full side leaves you standing; walk to the other one); your avatar walks there on its own (character attribute `SeatWalk`; `MovementController` calls
  `MoveTo` every frame instead of feeding your input, and blocks jumping) and sits within `SIT_RANGE` of the walk
  target or the seat, or is snapped in after `WALK_TIMEOUT`. (The game runs Roblox's native controls: there is
  no `PlayerScripts.PlayerModule` to disable.)
  Only seated players count toward the lobby. Jumping out of the seat leaves the queue, and you aren't seated
  in that lobby again until you step out of its zones. Seats have `CanTouch` off (only the queue seats people).
  No glow anywhere: lobbies are marked by chalk, the riser name and the sign.
- **Owner test bleacher** (`Workspace.Hub.Pads.PadTestRed`, beside the spawn): a one-seat Red section with `PadSize`
  1 + `OwnerOnly`, so only the game's owner (`game.CreatorId`; anyone in Studio) can queue on it. It lets the
  owner run the full hub → match → hub loop alone in the live game; the match server starts with
  `min(MinPlayersToStart, expectedPlayers)` players.
- Spinning for Styles happens **only in the hub**. Skills (Q/E) can be tried in the hub.
- Data is saved and released before every teleport (`DataService.Release`) so the next server
  never loads stale spins; the `Teleporting` player attribute blocks spins/queueing meanwhile.

### Styles menu (hub; G / gamepad B to close, or the top-left STYLES button) — `SpinController`
- A full-screen night scene laid out on the Figma mockup's 1366x768 and scaled into the core-UI safe
  area; the world behind is blurred (`UIKit.blur`) under a near-black backdrop. Opening snaps it in and
  draws the chalk underline under the name.
- Right: the player's own avatar (ViewportFrame + WorldModel, scripts stripped, lit warm from above) under a
  sodium streetlamp: lamp glow, light cone, light pool and a ground shadow. It loops the style's showcase
  idle (`<id>_Pose`); the preview camera frames the avatar from its bounding box (tall hats and weapons
  included) with headroom, feet on the light pool.
- Left: rarity (in its color) + "equipped", the style name huge in Sarpanch with a chalk underline that fits
  the name (Epic/Legendary get a cold light passing through it), description, Q/E rows (chalk key box with
  the amber key, skill-kind icon, name, cooldown), Speed / Stamina / Reach numbers, a chalk divider, the
  roll **odds** per tier in two columns (from `Config.Styles.RarityWeights`) with every style in each tier,
  and SPIN on an amber paint plate with "N left" (greyed paint at 0 spins).
- Spin: names shuffle and tick while the streetlamp flickers; Epic/Legendary get a beat of darkness (the
  lamp cuts out) and a shake first. The reveal lands with the lamp flaring in the rarity color, a shockwave
  ring behind the avatar, a flash, a snap of the name/rarity and the underline redrawn; Legendary adds a
  second white ring, a shake and a blur pulse. The result (name, "equipped", skill bar) stays hidden until
  the reveal even though the server sets `Style` instantly. The skill bar and STYLES button are hidden while
  the menu is open. The STYLES button (torn patch, own ScreenGui in the safe area) shows the spin count in
  amber, which snaps when spins are earned.

### Match (first person) — Core loop (Patintero)
- The match server waits for the party the hub sent (`expectedPlayers` teleport data) and until no
  one has joined for `Config.Match.JoinSettleTime` (max `ArrivalTimeout`), plays 2 rounds, then
  teleports everyone back to the hub. Players who arrive after teams are set spectate.
- Two teams per match, **Red** and **Blue** (player attribute `Side`, assigned at match start from the hub
  bleacher side each player sat on; anyone without one fills the smaller side, and a side more than one over
  gives its extras away): Red starts as Passers, Blue as Guards, and they swap roles for round 2. Every point (zone advance, Tubig, tag) goes
  to the scorer's side, so the match winner is a team of players: the HUD shows `RED: x | BLUE: y`
  (your side underlined) and the match-over banner names the winning side (or a draw).
- Guards are locked to chalk lines: `Line1`, `Line2`, `Line3` (across the court) and the
  `Patotot` (center line along the court; players see "the center line"). They tag with click / F. A lone guard gets the mid line
  (`Line2`); **line hop** (R / HOP) moves a guard to the next free line (`Config.Tagging.LineSwitchCooldown`).
- Passers run Home → Zone 1 → Zone 2 → Safehouse (outbound, +1 per zone in order),
  then back to Home for **"TUBIG!"** (+5). Zones must be cleared in order (no farming).
- A tagged Passer is out and sent to the sideline (player attribute `Tagged`), and watches an untagged teammate
  in third person (`FirstPersonController` spectate) until back in. **A Tubig brings back one tagged teammate**
  (`MatchService.reviveTeammate`: the first tagged Passer in roster order returns to Home with a fresh lap;
  `PasserRevived` → "Back in" callout). Round ends at time-out or when all Passers are out.
- **Movement check** (server): a Passer who covers more ground than `Config.Match.MaxRunSpeed` × time +
  `MaxBurst` since the last 0.2 s check or over ~1 s is moved back to where they were and gets no zone progress
  from that check (`MatchService.movedTooFast`; server teleports reset it). Zone order was already enforced.
- **Progression** (`ProgressionService`, both places): XP for zones, Tubig, tags, each round played and a win
  (`Config.Progression`); `Level = 1 + floor(sqrt(XP / XPLevelBase))`, shown in the player list (leaderstats)
  with a "Level N" callout on level-up (`LevelUp`). **Daily spins**: the first join of each UTC day adds
  `Config.Progression.DailySpins` (`DataService`).
- **MVP**: at MatchOver the player with the most points this match is named under the winner callout
  ("MVP name · N pts", `MatchState.mvpName`/`mvpPoints`).
- **First-time tutorial** (`TutorialService`): a hub player whose `TutorialDone` loads false is sent alone to a
  reserved match-place server (teleport data `tutorial = true`); there `MatchService` runs `TutorialService.Run`
  instead of matches. Each of the 7 steps completes on the action itself: sprint into Zone 1 (speed above
  WalkSpeed + 4), slide (the `CosmeticAction` "Slide"), reach Zone 2 past a guard, use a skill (`UseSkill`), the
  Safehouse, home for TUBIG (fires `TubigScored`: whistle, fanfare, cheer), then **guard practice**: you guard Line 2
  and tag a jogging practice runner (CollectionService tag `PracticeRunner`; `TagController` sends `PracticeTag`,
  the server checks reach). From step 3 two dummy guards (arms wide, Blue shirts) slide along Line1 / Line2 toward
  you when you're within 22 studs of their line; within 4.5 studs they send you back to the start of the leg (Home
  on the way out, the Safehouse on the way back), keeping the step. `TutorialController` draws the step card
  (left of center: STEP n OF 7, title, what to do, chalk key caps, a tick per step; a finished step snaps its tick
  amber with a chime, a tag shakes the card) and a beacon at the target (sodium light pillar, pulsing chalk ring,
  name). The HUD clock reads TUTORIAL. Finishing sets `TutorialDone`, gives `Config.Progression.TutorialSpins` (3)
  and returns you to the hub. A failed data load counts as done (no tutorial loop in an outage).
- **Analytics funnel** `MatchLoop` (`FunnelService`): 1 Joined hub, 2 Sat in lobby, 3 Match started, 4 Match
  finished, 5 Back in hub; the session id travels in teleport data (`funnels`).
- Map: the court on a barangay street with house rows on all four sides (`CourtService.BuildNeighborhood`),
  poles, banderitas strung pole-to-pole, sari-sari store, hoop, walls; packed-earth ground.

### Movement (both places) — `MovementController`, tunables in `Config.Movement`
- Heavy, momentum-based running: raw input (`Humanoid.MoveDirection`, written by Roblox's native
  controls) is eased toward its target and re-applied with `Humanoid:Move()` at render priority
  Input+1. ~`AccelTime` to full speed, ~`DecelTime` to skid to a stop, speed lost on sharp turns,
  `AirControl` in the air.
- Sprint builds up gradually (`SprintRampRate`); first person: strafe `StrafeMult`, backpedal `BackpedalMult`.
- Jumps are low (`JumpHeight`) and cost stamina (`JumpStaminaCost`); hard landings (>`HardLandingSpeed`)
  briefly slow the stride. Stamina max scales with the style's `staminaMult`.
- Slide (C/Ctrl) and stamina-limited sprint (Shift) as before; first person is forced in matches.

### Avatar height (both places) — `AvatarService`, tunable `Config.Avatar.Height`
- Every R15 character is uniformly scaled (`Model:ScaleTo`) to the same standing height once its
  appearance loads (`CharacterAppearanceLoaded`), so tall or tiny avatars get no reach, hitbox or
  visibility edge. Height is measured from the rest pose via the R15 rig attachments (works with both
  Motor6D and AnimationConstraint joints); accessories don't count. R6 rigs are left alone.

### Controls (keyboard / gamepad / touch) — ContextActionService, touch spots in `TouchLayout`
| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Run | Shift | L3 | RUN |
| Slide | C / Ctrl | B | SLIDE |
| Skill Q / E | Q / E | X / Y | skill-name buttons |
| Tag (guards) | Click / F | R2 | TAG |
| Line hop (guards) | R | R1 | HOP |
| Styles menu (hub) | G | — | STYLES button |

### Styles (rolled with Spins)
- **Players keep exactly one style.** A spin replaces it; there is no collection and no way to
  re-equip an earlier style except rolling it again.
- Rarities: Common 55%, Rare 30%, Epic 12%, Legendary 3% (see `Config.Styles`).
- Players see English names; the ids (used in data, animations and effects) stay Filipino: Tsinelas = Quickstep,
  Kanto = Streetwise, Bantay = Sentinel, Sipa = Leapfrog, Tumbang = Tin Can, Habagat = Typhoon, Anino = Phantom,
  Bathala = Sovereign. Skills: "Sprint!" (was Takbo!), "Can Shock" (was Lata Shock). UI text stays English except
  "Patintero" and the "TUBIG!" call; the street signs keep their Filipino as setting.
- Spins: start with 10; +1 per round played, +1 per Tubig. Saved in DataStore with the Style.
- Each Style = passive stat modifiers (speed, stamina, reach) + **Q** and **E** skills, each with its own
  custom animation and effects, plus a looping showcase idle (see *Style animations & effects*).
- Skill kinds: `Dash`, `Blink`, `Haste`, `SecondWind`, `LongArm`, `Slow` (area, enemies only;
  `mult = 0` is a freeze), `Veil` (tag-immune + see-through). Roster lives in `Styles.luau`.

### Environment builders — `FilipinoStreetEnvironment` (match court, shared pieces) and `HubStreet` (hub street)
- `BuildStreet`, `BuildHouseRow`, `BuildBarangayArch`, `BuildSariSariStore`,
  `BuildUtilityPolesAndWires`, `BuildBanderitas` (share one pole layout), hoop, walls, lighting,
  `BuildCoveredCourt`, `BuildCourtBleachers`.
  Both maps are saved in the place; the builders only run when a map is missing (or by hand in edit mode).
- `SetupGoldenHourLighting` (runs on every server start): sunset `ClockTime`, warm atmosphere, bloom,
  a warm `ColorCorrectionEffect` grade, sun rays, and `EnvironmentDiffuseScale = 0.45` so shade stays
  warm instead of sky-blue. Asphalt is a warm grey-brown (104, 96, 90).
- `OptimizeDecor(root)` runs on every built map (and was run on the saved ones): all map parts get
  `CanTouch = false`, non-solid decor gets `CanQuery = false` (flags/wires never block tag line of sight
  or Blink raycasts), parts under 1.5 studs get `CastShadow = false`. Run it after adding map pieces by hand.
- Lobby signs are dressed at start (`HubService.dressSign`): torn dark patch, a chalk mark in the side's color,
  Sarpanch lettering.

### Style animations & effects (client) — `StyleAnimator`, `SkillEffects`, data in `StyleAnimations`
- 32 Blender-made animations: `<styleId>_Q`, `<styleId>_E` (one-shots), `<styleId>_Pose` (looping showcase
  idle in the Styles menu) and `<styleId>_Beat` (the idle's signature move). `StyleAnimator.Play(character, name)` / `Stop` overrides joint
  `Transform`s right after the Animator (`PreSimulation`), blending in/out (0.14 s / 0.15 s) over the
  current animation; joints no Animator drives blend from rest. Works on Motor6D and AnimationConstraint
  rigs and on the ViewportFrame preview. **Nothing is uploaded**: the caster plays its own cast instantly,
  every other client plays it on `SkillCast` (Studio-registered temp animation ids don't work live, so
  real Animation assets would otherwise have to be uploaded by hand).
- Showcase idles are fighting-game character-select stances: feet planted, slow breathing and weight
  shift, eyes on the camera (no hops, dances or levitation). `_Pose` is the constant breathing/bob loop;
  `StyleAnimator` blends the `_Beat` (signature move, starts and ends on the idle's rest stance) in over it
  1.5 s after the idle starts, then every 5–9 s (random).
  Tsinelas: ready on the balls of the feet, light bounce, glance down the line; Kanto: arms crossed,
  weight back, chin up, a slow "come on" tilt; Bantay: low wide guard, eyes track then snap to a runner;
  Sipa: bladed guard, rocking weight, a sharp knee check; Tumbang: lead arm sighting, throwing arm cocked,
  a pump fake; Habagat: centered, palms rise to the chest and press down; Anino: low crouch, hand on the
  asphalt, a sharp head tilt; Bathala: tall and still, an open palm slowly rises to halt the camera.
- Skills: anticipation → snap → short hold → settle, low and heavy, no celebrating. Tsinelas sprinter's
  drive / Takbo! (set, explosive first drive); Kanto shoulder charge / Second Wind (hands on knees, one
  deep breath); Bantay fencing Lunge / Long Arm (arms snap wide); Sipa scissor hop-kick / Takbo! (three knee
  strikes); Tumbang diving reach / Lata Shock (cocked arm whips through); Habagat Gale Step (tight pivot
  spin) / Monsoon (gather, rise, drive into the ground); Anino low shadow run / Shadow Veil (cloaked
  crouch); Bathala Divine Step (onto the toes, one arm sweeps out) / Divine Halt (one palm thrust).
  Everything plays `TEMPO` (1.15) times slower than authored, for a measured, unhurried pace; strikes ease
  in with Cubic Out. Impact beats match `SkillEffects`' delays (noted per skill in `style_anims.py`, written
  in authored time and stretched by `SkillEffects`' own `TEMPO`); change both together.
- `SkillEffects.Play(styleId, slot, skill, casterCharacter, position)`, effect per `<styleId>_<slot>`, colored
  by the style's `THEME`: dust, speed lines, trails, ground rings (flat particle sprites), slash crescent,
  glowing hands, star/leaf/feather bursts, afterimages, a thrown tin can + shock ring (Lata Shock), rain
  over the Monsoon radius, smoke bomb + wisps (Shadow Veil), light pillars and a spreading clock rune
  (Bathala). Impact moments are delayed to match the animation (e.g. Lata Shock lands at ~0.37 s).

### Presentation (client) — audio, VFX, HUD
- **Audio** (`SoundController`, classic `Sound` + SoundGroups Master → SFX / UI / Ambience / Music; all ids
  in `SOUND_CONFIGS`): hub-only acoustic music (`HubMusic`) under the street ambience; in the match a distant
  neighborhood crowd loop (`MatchCrowd`) instead of music; a whoosh when your line hop lands (`TagController`); whistles for the
  countdown, round start and round end; clock ticks each second in a round's last 10 s; crowd cheer on
  Tubig and at match over; a heartbeat that fades in and quickens below ~35% stamina; UI clicks.
  3D one-shots play from an `Attachment` on Terrain.
- **Skills** (`StyleController`): each skill kind has its own cast sound (`SKILL_SFX`); the animation and
  effects are per style (below). Characters with `SlowMult` get an icy `Highlight` for everyone else;
  your own screen gets an icy tint.
- **Spins** (`SpinController`): ticks that drop in pitch as the roll slows; the reveal plays a chime
  (Common/Rare), fanfare (Epic) or boom + fanfare (Legendary) with the motion described in *Styles menu*.
- **Guard tag swipe** (`TagController`): a tag attempt plays the `Animate` script's `toolslash` animation on
  your own character (replicates, so everyone sees the swing); in first person your right arm is shown
  only while the swipe plays.
- **Run wind** (`FirstPersonController`, match): thin wind streaks fly back past both sides of the view and a
  wind loop (`RunWind`, `SoundController.UpdateRunWind`) rises in volume and pitch with horizontal speed (none
  below ~14 studs/s, full at 30). The streaks are two invisible emitters riding in front of the camera.
- **Body poses** (`BodyPose`, match, writes joint Transforms after the Animator like `StyleAnimator`):
  - Role arms, every character on every client (nothing replicated): Passers pump their arms as they run
    (elbows bent, each hand swinging in across the chest as it comes forward, scaled by speed); Guards hold
    their arms wide at shoulder height, forearms bent in, blocking, leaning with the strafe. Steps aside while a
    style animation or an Action-priority track (the tag swipe) plays.
  - Slides: the body drops `BodyPose.SLIDE_DROP` studs (the first-person camera dips the same, same blend
    rate), leans back, right leg out in front, left leg tucked, arms out for balance. Your own from
    `FirstPersonController.SetSliding` → `BodyPose.SetSliding`; everyone else's from the reliable
    `CosmeticAction` "Slide" relay (the server appends the slider's `UserId`), held for
    `Config.Movement.SlideDuration`.
  - First person shows your forearms and hands while posed and your legs + lower torso while sliding (upper
    arms and torso stay hidden: they sit at the camera and would block the view).
- **Tags** (`CourtVFXController`): the tagged Passer flashes red for everyone else; the tagger sees a red
  hit-marker ring pop around the crosshair (`HUDController`).
- **HUD** (`HUDController`, laid out like the mockup): faint dark scrims at the top and bottom of the screen; a
  torn scoreboard patch with the Red/Blue scores (roll up and snap) over chalk marks in the team colors, an
  amber scribble under your side, the clock (snaps each countdown second; signal red in a round's last
  10 s) and a chalk tick per round; under it the role line ("Runner reach the safehouse", role word in the
  role color). Crosshair dot; stamina is a chalk stroke drawn over a faint one (chalk → amber below half →
  red, flickering under 25%). Event callouts are paint plates that brush on left to right with the word
  slammed on top and an optional line under it ("TUBIG!" / "Neo scored +5"; zones show their short name);
  Tubig and the winner shake. Light paint gets ink lettering, dark paint chalk. A newer callout takes over.
- **Skill bar** (`StyleController`, both places): style name in its rarity color over two slots (torn patch,
  chalk edge, white skill-kind icon, amber key letter). Cooling down dims the icon under a big countdown;
  the slot dips on cast and, when ready again, snaps while its chalk edge flashes the rarity color.
- **UIKit** (`Controllers/UIKit`) is the shared "Kanto Night" look (Figma "Patintero UI", Direction B): a
  barangay court under a sodium streetlamp. Tokens: Ink / Patch darks, Chalk and Dim text, Sodium amber (the
  main action and what is yours), Signal red (urgency); color is otherwise reserved for meaning (rarity,
  team, role). Fonts: Sarpanch (Black for names/scores/callouts, ExtraBold for numbers and keys), Titillium
  Web for text. `UIKit.text` takes the mockup's font size and multiplies it by `UIKit.EM` (1.4: Roblox's
  TextSize is the line height); text past Roblox's 100 cap (style name, callouts) sits in a holder scaled
  up with UIScale. Art: `UIKit.Art` (chalk/paint/patch/lamp shapes, white, tinted with ImageColor3) via
  `art`; `wipe` draws a clipped stroke in left to right. Motion is crisp, no overshoot (Quick / Snap / Slide /
  Fade). Builders: `button` (hover nudge, press dip, release snap + click), `pop`, `countTo`, `shake`,
  `shockwave`, `blur` (menu blur, optional pulse), `fitScreen` (scale with screen height against the
  mockup's 768, 0.6–1.5). A GuiObject takes only one UIScale, so `fitScreen` goes on a container and
  `button`/`pop` on the element inside. Shakes, wipes and blur pulses are skipped when Reduced Motion is on.
- `CourtGeometry` builds the line and zone definitions once (frozen tables) instead of on every call.
