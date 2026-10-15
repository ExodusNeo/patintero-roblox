--!strict
--[[
    HubService.luau
    Hub matchmaking at the barangay covered court (99 Nights style): every lobby is a pair of bleacher sections
    facing each other across the court, Red on one sideline and Blue on the other. Walking into a section's zone
    walks you to a free seat on that side and sits you down. When every seat of a lobby is taken a countdown
    starts (cancelled if anyone stands up), then the group is teleported into a fresh reserved server of the
    match place, each player on the side they sat on. A lobby that isn't full starts anyway once
    Config.Hub.MinToStart players have sat there for Config.Hub.FillTimeout (the match evens out the sides).
    Also puts up the weekly TUBIG leaderboard board beside the spawn.
    Lobby zones are parts under Workspace.Hub.Pads with `PadSize`, `Lobby` (zones sharing it form one lobby),
    `Side` and `Title`; the Seat parts inside a zone are that side's seats.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local TravelService = require(script.Parent.TravelService)
local FilipinoStreetEnvironment = require(script.Parent.FilipinoStreetEnvironment)
local HubStreet = require(script.Parent.HubStreet)
local FunnelService = require(script.Parent.FunnelService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local HubService = {}

type Lobby = {
    id: string,
    size: number,
    title: string,
    ownerOnly: boolean,
    zones: { BasePart },
    labels: { TextLabel },
    seats: { Seat },
    occupants: { Player },
    countdownEnds: number?,
    waitingSince: number?, -- MinToStart seated, but not full
    busy: boolean,
}

local lobbies: { Lobby } = {}
local seatSide: { [Seat]: Types.Side } = {}

-- Seat queue: the server hands out seats, so two players never head for the same one.
type Claim = { lobby: Lobby, seat: Seat, target: Vector3, since: number, seated: boolean }
local claims: { [Player]: Claim } = {}
-- Stood up from a lobby's seat: not seated there again until they step out of its zones.
local stoodUp: { [Player]: Lobby } = {}
local SIT_RANGE = 3.5 -- studs (horizontal) from the walk target or seat at which the walk ends and the player sits
local WALK_TIMEOUT = 5 -- seconds; a blocked walk snaps the player into the seat

local SIDE_COLORS: { [Types.Side]: Color3 } = { Red = Color3.fromRGB(210, 69, 63), Blue = Color3.fromRGB(61, 123, 224) } -- the HUD's
local CHALK = Color3.fromRGB(240, 239, 233)
local COURT_TEXTURE = "rbxassetid://113273349405803" -- assets/court/court_half.png (tools/blender/court_texture.py)
local SEAT_GAP = 2.6
local BLEACHER_LENGTH = 80

local SIGN_FONT = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy)
local SIGN_PATCH = "rbxassetid://104932187263089" -- UIKit.Art.Patch (the client's "Kanto Night" art)
local SIGN_MARK = "rbxassetid://123140937052663" -- UIKit.Art.TeamMark

-- Lobby sign in the "Kanto Night" look: torn dark patch, a chalk mark in the side's color (the zone part's
-- Color), Sarpanch lettering. Runs on every zone at start.
local function dressSign(pad: BasePart)
    local label = pad:FindFirstChild("Status", true)
    local billboard = if label then label.Parent else nil
    if not (label and label:IsA("TextLabel") and billboard and billboard:IsA("BillboardGui")) or billboard:FindFirstChild("Plate") then
        return
    end
    billboard.Size = UDim2.fromScale(6.5, 2.4) -- studs: shrinks with distance instead of covering the court
    local plate = Instance.new("ImageLabel")
    plate.Name = "Plate"
    plate.Size = UDim2.fromScale(1, 1)
    plate.BackgroundTransparency = 1
    plate.Image = SIGN_PATCH
    plate.ImageColor3 = Color3.fromRGB(11, 12, 14)
    plate.ImageTransparency = 0.12
    plate.Parent = billboard
    local mark = Instance.new("ImageLabel")
    mark.Name = "Mark"
    mark.AnchorPoint = Vector2.new(0.5, 1)
    mark.Position = UDim2.fromScale(0.5, 0.95)
    mark.Size = UDim2.fromScale(0.48, 0.21)
    mark.BackgroundTransparency = 1
    mark.Image = SIGN_MARK
    mark.ImageColor3 = pad.Color
    mark.Parent = plate

    label.Parent = plate
    label.Position = UDim2.fromScale(0.06, 0.07)
    label.Size = UDim2.fromScale(0.88, 0.62)
    label.FontFace = SIGN_FONT
    label.TextColor3 = Color3.fromRGB(240, 239, 233)
    label.TextStrokeTransparency = 1
end

local function chalk(parent: Instance, size: Vector3, cf: CFrame)
    local line = Instance.new("Part")
    line.Name = "Chalk"
    line.Size = size
    line.CFrame = cf
    line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
    line.Material = Enum.Material.SmoothPlastic
    line.Color = CHALK
    line.Transparency = 0.1
    line.Parent = parent
end

-- One side of a lobby: `seats` seats on the first bleacher step, the queue zone in front of them (also covering
-- the step), a chalk box on the floor, the section name on the riser above and the lobby sign.
-- `frontCf`: the middle of the section's front edge on the ground, LookVector toward the court; `floorY`: height
-- of the floor the chalk box is painted on, relative to frontCf.
local function buildSection(pads: Instance, frontCf: CFrame, id: string, size: number, side: Types.Side, title: string, seats: number, floorY: number): BasePart
    local width = seats * SEAT_GAP
    local zone = Instance.new("Part")
    zone.Name = `{id}{side}`
    zone.Size = Vector3.new(width + 3, 10, 9)
    zone.CFrame = frontCf * CFrame.new(0, 5, -2.5)
    zone.Anchored, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = true, false, false, false, false
    zone.Transparency = 1
    zone.Color = SIDE_COLORS[side]
    zone:SetAttribute("PadSize", size)
    zone:SetAttribute("Lobby", id)
    zone:SetAttribute("Side", side)
    zone:SetAttribute("Title", title)

    for i = 1, seats do
        local seat = Instance.new("Seat")
        seat.Name = "Seat"
        seat.Size = Vector3.new(2.2, 0.3, 2)
        seat.CFrame = frontCf * CFrame.new((i - (seats + 1) / 2) * SEAT_GAP, 1.85, 1.2)
        seat.Anchored = true
        seat.CanTouch = false
        seat.Material = Enum.Material.SmoothPlastic
        seat.Color = CHALK
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.Parent = zone
    end

    local boxW, y = width + 2, floorY + 0.03
    -- chalk box on the court's painted border band, in front of the seats
    chalk(zone, Vector3.new(boxW, 0.04, 0.3), frontCf * CFrame.new(0, y, -0.4))
    chalk(zone, Vector3.new(boxW, 0.04, 0.3), frontCf * CFrame.new(0, y, -2.6))
    chalk(zone, Vector3.new(0.3, 0.04, 2.5), frontCf * CFrame.new(-boxW / 2, y, -1.5))
    chalk(zone, Vector3.new(0.3, 0.04, 2.5), frontCf * CFrame.new(boxW / 2, y, -1.5))

    local plate = Instance.new("Part")
    plate.Name = "SectionName"
    plate.Size = Vector3.new(math.max(width, 2.4), 1.2, 0.05)
    plate.CFrame = frontCf * CFrame.new(0, 2.7, 2.37)
    plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.CastShadow = true, false, false, false, false
    plate.Material = Enum.Material.SmoothPlastic
    plate.Color = Color3.fromRGB(11, 12, 14)
    plate.Parent = zone
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.Parent = plate
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Size = UDim2.fromScale(1, 1)
    name.FontFace = SIGN_FONT
    name.TextScaled = true
    name.TextColor3 = CHALK
    name.Text = title
    name.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(6.5, 2.4)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
    billboard.MaxDistance = 90
    billboard.Parent = zone
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.fromScale(1, 1)
    status.BackgroundTransparency = 1
    status.TextScaled = true
    status.Text = `{title}\n0/{size}`
    status.Parent = billboard

    zone.Parent = pads
    return zone
end

-- The barangay covered court past the end of the street, built in hub-local space around `origin`: plaza
-- floor, house rows and walls around it, the court, Red bleachers on one sideline and Blue on the other with a
-- section pair per lobby size (Config.Hub.PadSizes, smallest nearest the street), plus the owner's one-seat
-- test bleacher beside the spawn.
function HubService.BuildCourtPlaza(hub: Model, origin: CFrame): Model
    local env = FilipinoStreetEnvironment
    local plaza = Instance.new("Model")
    plaza.Name = "CourtPlaza"
    local function at(x: number, y: number, z: number): CFrame
        return origin * CFrame.new(x, y, z)
    end

    local floor = Instance.new("Part")
    floor.Name = "PlazaFloor"
    floor.Size = Vector3.new(112, 2, 116)
    floor.CFrame = at(0, -1, 138)
    floor.Anchored = true
    floor.Material = Enum.Material.Concrete
    floor.Color = Color3.fromRGB(128, 124, 118)
    floor.Parent = plaza
    HubStreet.BuildHouseRow(plaza, at(-56, 0, 82).Position, at(-56, 0, 196).Position, origin:VectorToWorldSpace(Vector3.xAxis), 106, 0.15)
    HubStreet.BuildHouseRow(plaza, at(56, 0, 196).Position, at(56, 0, 82).Position, origin:VectorToWorldSpace(-Vector3.xAxis), 107, 0.15)
    HubStreet.BuildHouseRow(plaza, at(-56, 0, 196).Position, at(56, 0, 196).Position, origin:VectorToWorldSpace(-Vector3.zAxis), 108, 0.15)
    for _, wall in { { Vector3.new(2, 30, 118), Vector3.new(-55, 15, 138) }, { Vector3.new(2, 30, 118), Vector3.new(55, 15, 138) },
        { Vector3.new(112, 30, 2), Vector3.new(0, 15, 195) } } do
        local barrier = Instance.new("Part")
        barrier.Name = "Barrier"
        barrier.Size = wall[1]
        barrier.CFrame = at(wall[2].X, wall[2].Y, wall[2].Z)
        barrier.Anchored = true
        barrier.Transparency = 1
        barrier.Parent = plaza
    end

    -- Court runs away from the street; its local +Z (tarpaulin, entrance) faces back down the street
    local courtCf = origin * CFrame.lookAt(Vector3.new(0, 0, 136), Vector3.new(0, 0, 137))
    env.BuildCoveredCourt(plaza, courtCf, COURT_TEXTURE)
    local pads = hub:FindFirstChild("Pads") or Instance.new("Folder")
    pads.Name = "Pads"
    pads.Parent = hub

    local sizes = Config.Hub.PadSizes
    local used = 0
    for _, size in sizes do
        used += size / 2 * SEAT_GAP
    end
    local gap = (BLEACHER_LENGTH - used) / (#sizes + 1)
    for _, side in { "Red", "Blue" } :: { Types.Side } do
        local x = if side == "Red" then -26.5 else 26.5
        env.BuildCourtBleachers(plaza, courtCf * CFrame.lookAt(Vector3.new(x, 0, 0), Vector3.zero), BLEACHER_LENGTH, 3, SIDE_COLORS[side])
        local z = BLEACHER_LENGTH / 2 -- the street end of the bleachers
        for _, size in sizes do
            local width = size / 2 * SEAT_GAP
            z -= gap + width / 2
            buildSection(pads, courtCf * CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, z)), `Pad{size}`, size, side,
                `{size // 2} V {size // 2}`, size // 2, 0.4)
            z -= width / 2
        end
    end

    local testCf = at(-18, 0, -55) * CFrame.lookAt(Vector3.zero, Vector3.xAxis) -- beside the spawn, facing it
    env.BuildCourtBleachers(plaza, testCf, 4, 1, SIDE_COLORS.Red)
    buildSection(pads, testCf, "PadTest", 1, "Red", "OWNER TEST", 1, 0):SetAttribute("OwnerOnly", true)

    env.OptimizeDecor(plaza)
    plaza.Parent = hub
    return plaza
end

-- Builds the hub around the origin, then pivots it to Config.Hub.Center: the barangay street at dusk (HubStreet:
-- houses, Aling Nena's store in its own gap, poles with sodium streetlamps, wires and banderitas past the welcome
-- arch, curbs and gutters) leading to the covered court with the lobbies. Props imported from
-- assets/models/HubProps.fbx (ServerStorage.HubProps) are placed if present. Also run once in edit mode so the
-- hub is saved in the place and can be decorated by hand.
function HubService.BuildHub(): Model
    local hub = Instance.new("Model")
    hub.Name = "Hub"
    local width, length, houseX = 60, 160, 39

    HubStreet.BuildStreet(hub, CFrame.new(), width, length, houseX)
    HubStreet.BuildPoles(hub, CFrame.new(), 33.5, { -28, 22, 72 }) -- all past the arch at z = -42
    local arch = FilipinoStreetEnvironment.BuildBarangayArch(hub, CFrame.lookAt(Vector3.new(0, 0, -42), Vector3.new(0, 0, -100)),
        width + 2, "MALIGAYANG PAGDATING SA BARANGAY PATINTERO")
    for _, x in { -1, 1 } do -- uplights on the welcome sign
        local can = Instance.new("Part")
        can.Name = "ArchUplight"
        can.Size = Vector3.new(1.2, 0.6, 1.2)
        can.CFrame = arch:GetPivot() * CFrame.new(x * (width / 2 - 4), 0.3, 4) * CFrame.Angles(math.rad(-20), 0, 0)
        can.Anchored, can.CanCollide, can.CastShadow = true, false, false
        can.Material = Enum.Material.Metal
        can.Color = Color3.fromRGB(40, 40, 42)
        can.Parent = arch
        local spot = Instance.new("SpotLight")
        spot.Face = Enum.NormalId.Top
        spot.Angle = 50
        spot.Range = 28
        spot.Brightness = 2.5
        spot.Color = Color3.fromRGB(255, 232, 200)
        spot.Parent = can
    end

    -- Houses on both sides and across the spawn end; the store fills a gap on the right; the far end opens onto the court
    HubStreet.BuildHouseRow(hub, Vector3.new(-houseX, 0, -length / 2), Vector3.new(-houseX, 0, length / 2), Vector3.xAxis, 201, 0.25)
    HubStreet.BuildHouseRow(hub, Vector3.new(houseX, 0, length / 2), Vector3.new(houseX, 0, 32), -Vector3.xAxis, 202, 0.25)
    HubStreet.BuildSariSariStore(hub, CFrame.lookAt(Vector3.new(houseX, 0, 20), Vector3.new(0, 0, 20)))
    HubStreet.BuildHouseRow(hub, Vector3.new(houseX, 0, 8), Vector3.new(houseX, 0, -length / 2), -Vector3.xAxis, 203, 0.25)
    HubStreet.BuildHouseRow(hub, Vector3.new(houseX, 0, -length / 2 - 1), Vector3.new(-houseX, 0, -length / 2 - 1), Vector3.zAxis, 204, 0)

    -- Invisible walls so nobody wanders out through gaps between houses
    for _, wall in { { Vector3.new(2, 30, length + 4), Vector3.new(-houseX + 1, 15, 0) }, { Vector3.new(2, 30, length + 4), Vector3.new(houseX - 1, 15, 0) },
        { Vector3.new(houseX * 2, 30, 2), Vector3.new(0, 15, -length / 2 + 1) } } do
        local barrier = Instance.new("Part")
        barrier.Name = "Barrier"
        barrier.Size = wall[1]
        barrier.Position = wall[2]
        barrier.Anchored = true
        barrier.Transparency = 1
        barrier.Parent = hub
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "HubSpawn"
    spawn.Size = Vector3.new(10, 1, 10)
    spawn.Position = Vector3.new(0, 0.5, -55)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Transparency = 1
    spawn.CanQuery = false
    spawn.Parent = hub

    HubService.BuildCourtPlaza(hub, CFrame.new())
    FilipinoStreetEnvironment.OptimizeDecor(hub)
    local props = ServerStorage:FindFirstChild("HubProps")
    if props then
        HubStreet.Dress(hub, props)
    end
    hub.WorldPivot = CFrame.new()
    hub:PivotTo(CFrame.new(Config.Hub.Center))
    hub.Parent = Workspace
    return hub
end

local function inZone(root: BasePart, zone: BasePart): boolean
    local p = zone.CFrame:PointToObjectSpace(root.Position)
    local half = zone.Size / 2
    return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function body(player: Player): (Humanoid?, BasePart?)
    local character = player.Character
    if not character then return nil, nil end
    return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The lobby zone the player stands in, if any.
local function zoneOf(player: Player, lobby: Lobby): BasePart?
    local _, root = body(player)
    if not root then return nil end
    for _, zone in lobby.zones do
        if inZone(root, zone) then
            return zone
        end
    end
    return nil
end

-- Lobbies with the OwnerOnly attribute (the 1-player test bleacher) only queue the game's owner, or anyone in Studio.
-- shortcut: compares to game.CreatorId, which is a group id for group-owned games; check group rank if the game moves to a group.
local function canUse(player: Player, lobby: Lobby): boolean
    return not lobby.ownerOnly or player.UserId == game.CreatorId or RunService:IsStudio()
end

-- The client walks its own character to this point (MovementController) and ignores input meanwhile.
local function setWalk(player: Player, target: Vector3?)
    if player.Character then
        player.Character:SetAttribute("SeatWalk", target)
    end
end

local function release(player: Player)
    if claims[player] then
        claims[player] = nil
        setWalk(player, nil)
    end
end

-- Stepping into a side's zone walks you to the nearest free seat on that side and sits you down; only seated
-- players are queued, and jumping out of the seat leaves the queue.
local function updateSeats(lobby: Lobby, now: number)
    for player, from in stoodUp do
        if from == lobby and not zoneOf(player, lobby) then
            stoodUp[player] = nil
        end
    end

    local taken: { [Seat]: boolean } = {}
    for player, claim in claims do
        if claim.lobby ~= lobby then continue end
        local humanoid, root = body(player)
        if not player.Parent or player:GetAttribute("Teleporting") or not humanoid or not root or humanoid.Health <= 0 then
            release(player)
        elseif claim.seat.Occupant == humanoid then
            if not claim.seated then
                claim.seated = true
                setWalk(player, nil)
                FunnelService.Step(player, 2, "Sat in lobby")
            end
        elseif claim.seated then -- jumped out of the seat
            release(player)
            stoodUp[player] = lobby
        elseif claim.seat.Occupant then
            release(player)
        else
            -- Sit at the walk target, or as soon as you're beside the seat itself
            local toTarget, toSeat = claim.target - root.Position, claim.seat.Position - root.Position
            if Vector2.new(toTarget.X, toTarget.Z).Magnitude <= SIT_RANGE or Vector2.new(toSeat.X, toSeat.Z).Magnitude <= SIT_RANGE
                or now - claim.since > WALK_TIMEOUT then
                claim.seat:Sit(humanoid)
            end
        end
        if claims[player] then
            taken[claim.seat] = true
        end
    end

    for _, player in Players:GetPlayers() do
        if claims[player] or stoodUp[player] or player:GetAttribute("Teleporting") or not canUse(player, lobby) then continue end
        local zone = zoneOf(player, lobby)
        local humanoid, root = body(player)
        if not zone or not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit then continue end

        local side = zone:GetAttribute("Side")
        local best: Seat?, bestDistance = nil, math.huge
        for _, seat in lobby.seats do
            local distance = (seat.Position - root.Position).Magnitude
            if seatSide[seat] == side and not taken[seat] and not seat.Occupant and distance < bestDistance then
                best, bestDistance = seat, distance
            end
        end
        if best then
            claims[player] = { lobby = lobby, seat = best, target = best.Position, since = now, seated = false }
            taken[best] = true
            setWalk(player, best.Position)
        end
    end

    table.clear(lobby.occupants)
    for player, claim in claims do
        if claim.lobby == lobby and claim.seated then
            table.insert(lobby.occupants, player)
        end
    end
end

local function setLabel(lobby: Lobby, text: string)
    for _, label in lobby.labels do
        label.Text = text
    end
end

local function launch(lobby: Lobby)
    lobby.busy = true
    setLabel(lobby, "TELEPORTING...")
    local group = table.clone(lobby.occupants)
    -- Each player's team in the match = the bleacher side they sat on
    local sides: { [string]: Types.Side } = {}
    for _, player in group do
        local claim = claims[player]
        if claim then
            sides[tostring(player.UserId)] = seatSide[claim.seat]
        end
    end

    task.spawn(function()
        local ok = false
        local matchId = Config.Places.MatchPlaceId
        if matchId == 0 then
            warn("[HubService] Config.Places.MatchPlaceId is not set; can't start a match")
        else
            local reserved, code = pcall(TeleportService.ReserveServerAsync, TeleportService, matchId)
            if reserved then
                local options = Instance.new("TeleportOptions")
                options.ReservedServerAccessCode = code
                -- Non-secure (client-visible) data: a wait hint and team picks the match server sanity-checks.
                options:SetTeleportData({ expectedPlayers = #group, sides = sides, funnels = FunnelService.Sessions(group) })
                ok = TravelService.Send(matchId, group, options)
            else
                warn(`[HubService] ReserveServerAsync failed: {code}`)
            end
        end

        if not ok then
            setLabel(lobby, "COULDN'T START MATCH")
            task.wait(2)
        end
        lobby.countdownEnds = nil
        lobby.waitingSince = nil
        lobby.busy = false
    end)
end

local function updateLobby(lobby: Lobby, now: number)
    if lobby.busy then return end
    updateSeats(lobby, now)

    local count = #lobby.occupants
    local full = count >= lobby.size
    if not full and count >= math.min(Config.Hub.MinToStart, lobby.size) then
        lobby.waitingSince = lobby.waitingSince or now
    elseif not full then
        lobby.waitingSince = nil
    end
    local waited = if lobby.waitingSince then now - lobby.waitingSince else 0

    if full or waited >= Config.Hub.FillTimeout then
        lobby.countdownEnds = lobby.countdownEnds or now + Config.Hub.CountdownTime
        local remaining = math.ceil((lobby.countdownEnds :: number) - now)
        if remaining <= 0 then
            launch(lobby)
        else
            setLabel(lobby, `STARTING IN {remaining}`)
        end
    else
        lobby.countdownEnds = nil
        local wait = if lobby.waitingSince then ` · {math.ceil(Config.Hub.FillTimeout - waited)}s` else ""
        setLabel(lobby, `{lobby.title}\n{count}/{lobby.size}{wait}`)
    end
end

-- Weekly TUBIG board on two posts beside the spawn, facing the street; returns its row labels
local function buildLeaderboard(hub: Instance): { TextLabel }
    local spawn = hub:FindFirstChild("HubSpawn") :: BasePart?
    local base = if spawn then spawn.Position else Config.Hub.Center
    local at = Vector3.new(base.X + 15, base.Y, base.Z + 4)
    local model = Instance.new("Model")
    model.Name = "WeeklyBoard"

    local board = Instance.new("Part")
    board.Name = "Board"
    board.Size = Vector3.new(7, 8, 0.4)
    board.CFrame = CFrame.lookAt(at + Vector3.new(0, 6, 0), at + Vector3.new(-1, 6, 0))
    board.Color = Color3.fromRGB(28, 26, 24)
    board.Material = Enum.Material.Wood
    board.Anchored = true
    board.CanTouch = false
    board.Parent = model
    for _, x in { -3, 3 } do
        local post = Instance.new("Part")
        post.Size = Vector3.new(0.4, 10, 0.4)
        post.CFrame = board.CFrame * CFrame.new(x, -1, 0.3)
        post.Color = Color3.fromRGB(60, 52, 44)
        post.Material = Enum.Material.Wood
        post.Anchored = true
        post.CanTouch = false
        post.Parent = model
    end

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.LightInfluence = 0.2
    gui.Parent = board
    local plate = Instance.new("ImageLabel")
    plate.Size = UDim2.fromScale(1, 1)
    plate.BackgroundTransparency = 1
    plate.Image = SIGN_PATCH
    plate.ImageColor3 = Color3.fromRGB(11, 12, 14)
    plate.Parent = gui
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromScale(0.08, 0.05)
    title.Size = UDim2.fromScale(0.84, 0.13)
    title.FontFace = SIGN_FONT
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 176, 59) -- UIKit sodium amber
    title.Text = "WEEKLY TUBIG"
    title.Parent = plate

    local rows: { TextLabel } = {}
    local count = Config.Hub.LeaderboardSize
    for i = 1, count do
        local row = Instance.new("TextLabel")
        row.BackgroundTransparency = 1
        row.Position = UDim2.fromScale(0.1, 0.21 + (i - 1) * 0.074)
        row.Size = UDim2.fromScale(0.8, 0.066)
        row.FontFace = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)
        row.TextScaled = true
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextColor3 = CHALK
        row.Text = ""
        row.Parent = plate
        rows[i] = row
    end
    model.Parent = hub
    return rows
end

function HubService.Init()
    HubStreet.SetupNightLighting()

    local hub = Workspace:FindFirstChild("Hub") or HubService.BuildHub()
    LeaderboardService.ShowOn(buildLeaderboard(hub))
    local padFolder = hub:FindFirstChild("Pads")
    local byId: { [string]: Lobby } = {}
    for _, zone in if padFolder then padFolder:GetChildren() else {} do
        local size = zone:GetAttribute("PadSize")
        if not zone:IsA("BasePart") or typeof(size) ~= "number" then continue end
        dressSign(zone)
        local id = zone:GetAttribute("Lobby")
        id = if typeof(id) == "string" then id else zone.Name
        local lobby = byId[id]
        if not lobby then
            local title = zone:GetAttribute("Title")
            local created: Lobby = {
                id = id,
                size = size,
                title = if typeof(title) == "string" then title else `{size} PLAYERS`,
                ownerOnly = zone:GetAttribute("OwnerOnly") == true,
                zones = {},
                labels = {},
                seats = {},
                occupants = {},
                countdownEnds = nil,
                busy = false,
            }
            byId[id] = created
            table.insert(lobbies, created)
            lobby = created
        end
        table.insert(lobby.zones, zone)
        local label = zone:FindFirstChild("Status", true)
        if label and label:IsA("TextLabel") then
            table.insert(lobby.labels, label)
        end
        local side: Types.Side = if zone:GetAttribute("Side") == "Blue" then "Blue" else "Red"
        for _, seat in zone:GetDescendants() do
            if seat:IsA("Seat") then
                seat.CanTouch = false -- seats are handed out by the queue, never by bumping into them
                seatSide[seat] = side
                table.insert(lobby.seats, seat)
            end
        end
    end

    Players.PlayerRemoving:Connect(function(player)
        claims[player] = nil
        stoodUp[player] = nil
    end)

    task.spawn(function()
        while true do
            local now = os.clock()
            for _, lobby in lobbies do
                updateLobby(lobby, now)
            end
            task.wait(0.2)
        end
    end)
end

return HubService
