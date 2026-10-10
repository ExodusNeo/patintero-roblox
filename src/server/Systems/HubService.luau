--!strict
--[[
    HubService.luau
    Hub matchmaking, 99 Nights style: stand on a queue pad; when it holds `PadSize` players a
    countdown starts (cancelled if anyone steps off), then the group is teleported into a fresh
    reserved server of the match place.
    Pads are any part under Workspace.Hub.Pads with a `PadSize` attribute (editable live in Studio).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)
local TravelService = require(script.Parent.TravelService)
local FilipinoStreetEnvironment = require(script.Parent.FilipinoStreetEnvironment)

local HubService = {}

type Pad = {
    part: BasePart,
    label: TextLabel?,
    occupants: { Player },
    countdownEnds: number?,
    busy: boolean,
}

local PAD_COLORS: { [number]: Color3 } = {
    [2] = Color3.fromRGB(80, 200, 120),
    [4] = Color3.fromRGB(80, 160, 255),
    [6] = Color3.fromRGB(255, 170, 60),
    [8] = Color3.fromRGB(230, 70, 90),
}

local pads: { Pad } = {}

-- Builds the hub plaza (floor, spawn, pads). Also run once in edit mode so it can be decorated by hand.
function HubService.BuildHub(): Folder
    local center = Config.Hub.Center
    local hub = Instance.new("Folder")
    hub.Name = "Hub"

    local floor = Instance.new("Part")
    floor.Name = "PlazaFloor"
    floor.Size = Vector3.new(160, 1, 160)
    floor.Position = center
    floor.Anchored = true
    floor.Material = Enum.Material.Pavement
    floor.Color = Color3.fromRGB(120, 115, 110)
    floor.Parent = hub

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "HubSpawn"
    spawn.Size = Vector3.new(10, 1, 10)
    spawn.Position = center + Vector3.new(0, 0.6, -30)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Color = Color3.fromRGB(255, 215, 0)
    spawn.Parent = hub

    local padFolder = Instance.new("Folder")
    padFolder.Name = "Pads"
    padFolder.Parent = hub

    local sizes = Config.Hub.PadSizes
    for i, size in sizes do
        local x = center.X + (i - (#sizes + 1) / 2) * 26
        local pad = Instance.new("Part")
        pad.Name = `Pad{size}`
        pad.Shape = Enum.PartType.Cylinder
        pad.Size = Vector3.new(0.4, 16, 16) -- cylinder axis is X; rotated flat below
        pad.CFrame = CFrame.new(x, center.Y + 0.7, center.Z + 20) * CFrame.Angles(0, 0, math.rad(90))
        pad.Anchored = true
        pad.CanCollide = false
        pad.Material = Enum.Material.Neon
        pad.Color = PAD_COLORS[size] or Color3.new(1, 1, 1)
        pad.Transparency = 0.35
        pad:SetAttribute("PadSize", size)
        pad.Parent = padFolder

        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.fromOffset(220, 70)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 120
        billboard.Parent = pad

        local status = Instance.new("TextLabel")
        status.Name = "Status"
        status.Size = UDim2.fromScale(1, 1)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.GothamBlack
        status.TextScaled = true
        status.TextColor3 = Color3.new(1, 1, 1)
        status.TextStrokeTransparency = 0.3
        status.Text = `{size} PLAYERS\n0/{size}`
        status.Parent = billboard
    end

    hub.Parent = Workspace
    return hub
end

local function isOnPad(player: Player, part: BasePart): boolean
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if not root then return false end
    local offset = root.Position - part.Position
    return Vector2.new(offset.X, offset.Z).Magnitude <= part.Size.Y / 2 and math.abs(offset.Y) < 8
end

local function setLabel(pad: Pad, text: string)
    if pad.label then
        pad.label.Text = text
    end
end

local function launch(pad: Pad)
    pad.busy = true
    setLabel(pad, "TELEPORTING...")
    local group = table.clone(pad.occupants)

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
                -- Non-secure (client-visible) data; only used as a wait hint by the match server.
                options:SetTeleportData({ expectedPlayers = #group })
                ok = TravelService.Send(matchId, group, options)
            else
                warn(`[HubService] ReserveServerAsync failed: {code}`)
            end
        end

        if not ok then
            setLabel(pad, "COULDN'T START MATCH")
            task.wait(2)
        end
        table.clear(pad.occupants)
        pad.countdownEnds = nil
        pad.busy = false
    end)
end

local function updatePad(pad: Pad, now: number)
    if pad.busy then return end
    local size = pad.part:GetAttribute("PadSize")
    if typeof(size) ~= "number" or size < 1 then return end

    local occupants = pad.occupants
    for i = #occupants, 1, -1 do
        local player = occupants[i]
        if not player.Parent or player:GetAttribute("Teleporting") or not isOnPad(player, pad.part) then
            table.remove(occupants, i)
        end
    end

    -- First come, first served; extra players on a full pad are not queued.
    for _, player in Players:GetPlayers() do
        if #occupants >= size then break end
        if not table.find(occupants, player) and not player:GetAttribute("Teleporting") and isOnPad(player, pad.part) then
            table.insert(occupants, player)
        end
    end

    if #occupants >= size then
        pad.countdownEnds = pad.countdownEnds or now + Config.Hub.CountdownTime
        local remaining = math.ceil((pad.countdownEnds :: number) - now)
        if remaining <= 0 then
            launch(pad)
        else
            setLabel(pad, `STARTING IN {remaining}`)
        end
    else
        pad.countdownEnds = nil
        setLabel(pad, `{size} PLAYERS\n{#occupants}/{size}`)
    end
end

function HubService.Init()
    FilipinoStreetEnvironment.SetupGoldenHourLighting()

    local hub = Workspace:FindFirstChild("Hub") or HubService.BuildHub()
    local padFolder = hub:FindFirstChild("Pads")
    for _, part in if padFolder then padFolder:GetChildren() else {} do
        if part:IsA("BasePart") and part:GetAttribute("PadSize") then
            local label = part:FindFirstChild("Status", true)
            table.insert(pads, {
                part = part,
                label = if label and label:IsA("TextLabel") then label else nil,
                occupants = {},
                countdownEnds = nil,
                busy = false,
            })
        end
    end

    task.spawn(function()
        while true do
            local now = os.clock()
            for _, pad in pads do
                updatePad(pad, now)
            end
            task.wait(0.2)
        end
    end)
end

return HubService
