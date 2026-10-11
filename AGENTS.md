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
  Before committing, sync Studio → `src/`: run `node tools/sync-receiver.js .` in the background, then
  `execute_luau` (Edit) the contents of `tools/studio-sync-sender.luau`; review `git diff`, commit.
  (Deleted scripts are not removed from `src/` by the sync — delete those files by hand.)
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
  posed rig copies for one-render pose checks. Push the regenerated module into Studio (it is generated:
  never hand-edit it).
- **Effect sprites** come from `tools/blender/fx_textures.py` (white-on-transparent PNGs in `assets/fx/`),
  uploaded with the Studio MCP `upload_image` tool (serve `assets/fx` on localhost); the ids live in
  `SkillEffects.TEX`. Re-upload and update the ids if a sprite changes.
- **UI art** comes from `tools/blender/ui_assets.py` (`assets/ui/`): Eevee renders of the 7 embossed
  skill-kind icons, plus numpy sprites (sunburst rays, glow, tileable asphalt grain). Uploaded the same way;
  ids live in `UIKit.Image` / `UIKit.Icon` (the shockwave ring reuses the `fx_ring` effect sprite).
- Disk → Studio for generated/new files: serve `src/` on localhost and `HttpService:GetAsync` each file
  into its ModuleScript from an Edit-mode `execute_luau` (HttpEnabled on briefly, then restored).

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
  - Player: `Spins` (number), `Style` (style id), `Team` (current role), `Side` (`Red`/`Blue` match team), `Teleporting`.
  - Character: `HasteMult`, `SlowMult`, `ReachBonus`, `TagImmune` (timed, set by `StyleService`).
- Clean up connections on character removal; use `UnreliableRemoteEvent` for cosmetics.
- Commits: Conventional Commits (`feat(scope): …`, `fix(scope): …`), one per finished system.

---

## 5. Game design

### Hub (third person)
- A Filipino barangay street (`HubService.BuildHub`, saved as `Workspace.Hub`): welcome arch
  "Maligayang Pagdating sa Barangay Patintero" between spawn and pads, house rows, sari-sari store
  with a parked jeepney, utility poles, banderitas, invisible boundary walls.
- Four queue pads on the road (2×2 grid) need 2 / 4 / 6 / 8 players (`PadSize` attribute on parts in
  `Workspace.Hub.Pads`; add or move pads freely). A full pad counts down (`Config.Hub.CountdownTime`),
  cancelled if anyone steps off, then `HubService` reserves a match server and `TravelService`
  teleports the group.
- **Owner test pad** (`Workspace.Hub.Pads.PadTest`, beside the spawn): `PadSize` 1 + `OwnerOnly`
  attribute, so only the game's owner (`game.CreatorId`; anyone in Studio) can queue on it. It lets the
  owner run the full hub → match → hub loop alone in the live game; the match server starts with
  `min(MinPlayersToStart, expectedPlayers)` players.
- Spinning for Styles happens **only in the hub**. Skills (Q/E) can be tried in the hub.
- Data is saved and released before every teleport (`DataService.Release`) so the next server
  never loads stale spins; the `Teleporting` player attribute blocks spins/queueing meanwhile.

### Styles menu (hub; G / gamepad B to close, or the top-left STYLES button) — `SpinController`
- A slate board (laid out at 860x500, scaled to fit any screen) with an accent line across the top in the
  shown style's rarity color, over a dimmed backdrop; the world behind is blurred (`UIKit.blur`).
  Opening snaps it in and fills the odds bars one tier at a time.
- Left: dark showcase of the player's own avatar on a podium (ViewportFrame + WorldModel, scripts
  stripped) looping the style's dance (`<id>_Pose`) over faint, slow rays in the rarity color.
- Right: style name in the condensed scoreboard face (Epic/Legendary get a cold light passing through
  it), a filled rarity tag + outlined EQUIPPED tag, description, Q/E skill cards (rarity accent bar,
  skill-kind icon, inset key cap), SPEED / STAMINA / REACH readouts, the roll **odds** per tier as thin bars
  (from `Config.Styles.RarityWeights`) with every style in each tier, and the signal-red SPIN button with
  the spin count inset.
- Spin: names shuffle and tick (the accent line flickers through rarities) while the rays speed up;
  Epic/Legendary get a beat of shake first. The reveal lands with a shockwave ring behind the avatar, a
  flash, a snap of the name/rarity tag and the accent line sweeping across; Legendary adds a second white
  ring, a board shake and a blur pulse. The result (name, EQUIPPED tag, skill bar) stays hidden until the
  reveal even though the server sets `Style` instantly. The skill bar is hidden while the menu is open.
  The STYLES button (own ScreenGui, safe area) shows the spin count, which snaps when spins are earned.

### Match (first person) — Core loop (Patintero)
- The match server waits for the party the hub sent (`expectedPlayers` teleport data) and until no
  one has joined for `Config.Match.JoinSettleTime` (max `ArrivalTimeout`), plays 2 rounds, then
  teleports everyone back to the hub. Players who arrive after teams are set spectate.
- Two teams per match, **Red** and **Blue** (player attribute `Side`, assigned at match start): Red starts
  as Passers, Blue as Guards, and they swap roles for round 2. Every point (zone advance, Tubig, tag) goes
  to the scorer's side, so the match winner is a team of players: the HUD shows `RED: x | BLUE: y`
  (your side underlined) and the match-over banner names the winning side (or a draw).
- Guards are locked to chalk lines: `Line1`, `Line2`, `Line3` (across the court) and the
  `Patotot` (center line along the court). They tag with click / F. A lone guard gets the mid line
  (`Line2`); **line hop** (R / HOP) moves a guard to the next free line (`Config.Tagging.LineSwitchCooldown`).
- Passers run Home → Zone 1 → Zone 2 → Safehouse (outbound, +1 per zone in order),
  then back to Home for **"TUBIG!"** (+5). Zones must be cleared in order (no farming).
- A tagged Passer is out for the round and sent to the sideline. Round ends at time-out or when
  all Passers are out.
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
- Spins: start with 10; +1 per round played, +1 per Tubig. Saved in DataStore with the Style.
- Each Style = passive stat modifiers (speed, stamina, reach) + **Q** and **E** skills, each with its own
  custom animation and effects, plus a looping showcase dance (see *Style animations & effects*).
- Skill kinds: `Dash`, `Blink`, `Haste`, `SecondWind`, `LongArm`, `Slow` (area, enemies only;
  `mult = 0` is a freeze), `Veil` (tag-immune + see-through). Roster lives in `Styles.luau`.

### Environment builders — `FilipinoStreetEnvironment`
- `BuildStreet`, `BuildHouseRow`, `BuildJeepney`, `BuildBarangayArch`, `BuildSariSariStore`,
  `BuildUtilityPolesAndWires`, `BuildBanderitas` (share one pole layout), hoop, walls, lighting.
  Both maps are saved in the place; the builders only run when a map is missing (or by hand in edit mode).
- `SetupGoldenHourLighting` (runs on every server start): sunset `ClockTime`, warm atmosphere, bloom,
  a warm `ColorCorrectionEffect` grade, sun rays, and `EnvironmentDiffuseScale = 0.45` so shade stays
  warm instead of sky-blue. Asphalt is a warm grey-brown (104, 96, 90).
- `OptimizeDecor(root)` runs on every built map (and was run on the saved ones): all map parts get
  `CanTouch = false`, non-solid decor gets `CanQuery = false` (flags/wires never block tag line of sight
  or Blink raycasts), parts under 1.5 studs get `CastShadow = false`. Run it after adding map pieces by hand.
- Hub queue pads glow (a `PointLight` in the pad color) and emit rising sparkles (`HubService.decoratePad`).
  Their signs are dressed at start (`HubService.dressSign`): slate plate, pad-colored edge, scoreboard lettering.

### Style animations & effects (client) — `StyleAnimator`, `SkillEffects`, data in `StyleAnimations`
- 24 Blender-made animations: `<styleId>_Q`, `<styleId>_E` (one-shots) and `<styleId>_Pose` (looping
  showcase dance in the Styles menu). `StyleAnimator.Play(character, name)` / `Stop` overrides joint
  `Transform`s right after the Animator (`PreSimulation`), blending in/out (0.08 s / 0.15 s) over the
  current animation; joints no Animator drives blend from rest. Works on Motor6D and AnimationConstraint
  rigs and on the ViewportFrame preview. **Nothing is uploaded**: the caster plays its own cast instantly,
  every other client plays it on `SkillCast` (Studio-registered temp animation ids don't work live, so
  real Animation assets would otherwise have to be uploaded by hand).
- Dances: Tsinelas *Tinikling* hops (hands on hips), Kanto *Budots*, Bantay guard shuffle, Sipa juggling
  kicks, Tumbang *tumbang preso* slipper throw, Habagat flowing wind arms, Anino low shadow seal,
  Bathala levitation.
- Skills: Tsinelas Dash (anime sprint) / Takbo! (set + fist pump); Kanto shoulder charge / Second Wind
  (big breath); Bantay fencing Lunge / Long Arm (arms snap wide); Sipa hop-kick / knee juggles; Tumbang
  diving reach / Lata Shock (overhead can slam); Habagat Gale Step (full spin) / Monsoon (gather, rise,
  slam); Anino shadow run / Shadow Veil (cloaked crouch); Bathala Divine Step (rise, arms to the sky) /
  Divine Halt (palm out, other arm raised).
- `SkillEffects.Play(styleId, slot, skill, casterCharacter, position)`, effect per `<styleId>_<slot>`, colored
  by the style's `THEME`: dust, speed lines, trails, ground rings (flat particle sprites), slash crescent,
  glowing hands, star/leaf/feather bursts, afterimages, a thrown tin can + shock ring (Lata Shock), rain
  over the Monsoon radius, smoke bomb + wisps (Shadow Veil), light pillars and a spreading clock rune
  (Bathala). Impact moments are delayed to match the animation (e.g. Lata Shock lands at ~0.32 s).

### Presentation (client) — audio, VFX, HUD
- **Audio** (`SoundController`, classic `Sound` + SoundGroups Master → SFX / UI / Ambience / Music; all ids
  in `SOUND_CONFIGS`): hub-only acoustic music (`HubMusic`) under the street ambience; whistles for the
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
- **Tags** (`CourtVFXController`): the tagged Passer flashes red for everyone else; the tagger sees a red
  hit-marker ring pop around the crosshair (`HUDController`).
- **HUD** (`HUDController`): a slate broadcast scoreboard with team-tinted Red/Blue score blocks (an amber
  underline marks your side; scores roll up and snap), the phase line and a big scoreboard clock (snaps each
  countdown second; signal red in a round's last 10 s), and the role tag under it (accent bar in the role
  color). Thin stamina bar (green → amber → red, flickers under 25%). Event banners are broadcast strips
  (slate band fading out at both ends, accent line in the event color, text in caps) that slide in, hold,
  slide on and fade; Tubig and the winner get faint rays behind. A newer strip cancels an older one's fade.
- **Skill bar** (`StyleController`, both places): style name + rarity (in its color), two slate cards with
  the skill-kind icon, a 1 px edge tinted toward the rarity and an inset key cap; cooldown shades the
  card from the top with a big countdown; the card dips on cast and, when ready again, snaps while its
  edge flashes the rarity color.
- **UIKit** (`Controllers/UIKit`) is the shared "night court" look: chalk lines on night asphalt, read like a
  sports broadcast. Tokens: Night / Deep / Slab / Steel slates, Chalk and Dim text, Signal red (main action,
  urgency), Amber (yours); color is otherwise reserved for meaning (rarity, team, role). Fonts: Oswald
  (condensed scoreboard face) for titles and numbers, Builder Sans for body. Motion is crisp, no overshoot
  (Quick / Snap / Slide / Fade). Builders: `panel` (small radius, 1 px steel edge, asphalt grain, optional
  accent bar), `button` (hover nudge, press dip, release snap + click), `pop`, `shimmer` (faint), `spin`,
  `countTo`, `shake`, `shockwave`, `blur` (menu blur, optional pulse), `fitScreen` (scale with screen height,
  0.6–1.3). A GuiObject takes only one UIScale, so `fitScreen` goes on a container and `button`/`pop` on
  the element inside. Loops, shakes and blur pulses are skipped when the player's Reduced Motion is on.
- `CourtGeometry` builds the line and zone definitions once (frozen tables) instead of on every call.
