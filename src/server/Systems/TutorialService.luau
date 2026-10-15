--!strict
--[[
    TutorialService.luau
    First-time tutorial. Hub: a player whose `TutorialDone` attribute loads false is sent alone to a reserved
    match-place server with teleport data `tutorial = true` (Init(true)). Match place: MatchService hands that
    server to Run() instead of starting a match. The player runs the court as a Passer through STEPS (zones in
    order, then home for TUBIG) past two dummy guards patrolling Line1 and Line2; getting close to one sends
    you back home to step 1. Finishing sets `TutorialDone` and returns the player to the hub.
    Studio: StudioMode = "Tutorial" runs it; teleports are skipped there.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local CourtService = require(script.Parent.CourtService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local TravelService = require(script.Parent.TravelService)
local FunnelService = require(script.Parent.FunnelService)

local TutorialService = {}

-- checkpoint: the zone's checkpointIndex to reach (0 = Home, after the Safehouse)
local STEPS = {
    { checkpoint = 1, title = "Zone 1", hint = "run to Zone 1 (Shift to sprint)" },
    { checkpoint = 2, title = "Zone 2", hint = "get past the guard to Zone 2 (C to slide)" },
    { checkpoint = 3, title = "Safehouse", hint = "reach the Safehouse at the far end" },
    { checkpoint = 0, title = "Tubig!", hint = "run back home for TUBIG! (+5 in a match)" },
}
local DUMMY_LINES = { "Line1", "Line2" }
local DUMMY_SPEED = 7 -- studs/s along their line
local DUMMY_REACH = 4.5 -- studs (flat) at which a dummy tags you
local GUARD_COLOR = Color3.fromRGB(61, 123, 224) -- Blue side

-- Hub: send a player who hasn't done the tutorial
local function sendToTutorial(player: Player)
    if player:GetAttribute("TutorialDone") ~= false or player:GetAttribute("Teleporting") then return end
    if RunService:IsStudio() then
        print(`[TutorialService] {player.Name} would go to the tutorial (teleports don't work in Studio)`)
        return
    end
    local ok, code = pcall(TeleportService.ReserveServerAsync, TeleportService, Config.Places.MatchPlaceId)
    if not ok then
        warn(`[TutorialService] ReserveServerAsync failed: {code}`)
        return
    end
    local options = Instance.new("TeleportOptions")
    options.ReservedServerAccessCode = code
    options:SetTeleportData({ tutorial = true, expectedPlayers = 1, funnels = FunnelService.Sessions({ player }) })
    TravelService.Send(Config.Places.MatchPlaceId, { player }, options)
end

local function makeDummy(lineId: string): (Model, Types.LineDefinition)
    local line = CourtGeometry.GetLineDefinitions()[lineId :: any]
    local description = Instance.new("HumanoidDescription")
    for _, part in { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
        (description :: any)[`{part}Color`] = Color3.fromRGB(204, 170, 140)
    end
    description.TorsoColor = GUARD_COLOR
    local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    dummy.Name = "TutorialGuard"
    for _, part in dummy:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    -- Arms wide, blocking (like a Guard's BodyPose): rotate the shoulder joints' parent-side frames
    for name, rot in { RightShoulder = CFrame.Angles(0, math.rad(30), math.rad(82)), LeftShoulder = CFrame.Angles(0, math.rad(-30), math.rad(-82)) } do
        local joint = dummy:FindFirstChild(name, true)
        if joint and joint:IsA("Motor6D") then
            joint.C0 = joint.C0 * rot
        elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
            joint.Attachment0.CFrame = joint.Attachment0.CFrame * rot
        end
    end
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    dummy.Parent = Workspace
    return dummy, line
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function sendHome(player: Player)
    local root = rootOf(player)
    if root then
        root.CFrame = CourtService.GetSpawnCFrame("Passers", nil)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

-- Match place: runs the tutorial for `player`, then sends them back to the hub. Yields until done.
function TutorialService.Run(player: Player)
    while player.Parent and not rootOf(player) do
        task.wait(0.2)
    end
    -- A new character sits at the world origin (mid-court) until Roblox places it; start once it's placed
    task.wait(2)
    if not player.Parent then return end
    PlayerStateService.SetTeam(player, "Passers", nil)
    player:SetAttribute("Side", "Red")
    sendHome(player)

    local stepEvent = Remotes.GetEvent("TutorialStep")
    local step = 1
    local function announce()
        local s = STEPS[step]
        stepEvent:FireClient(player, step, #STEPS, s.title, s.hint)
    end
    task.wait(0.5)
    announce()

    -- Dummy guards patrol their lines; anyone they reach goes back home to step 1
    local dummies = {}
    for i, lineId in DUMMY_LINES do
        local dummy, line = makeDummy(lineId)
        local height = dummy:GetExtentsSize().Y / 2
        table.insert(dummies, { model = dummy, line = line, height = height, t = i * 0.37 })
    end

    local done = false
    local patrol = RunService.Heartbeat:Connect(function(dt)
        local root = rootOf(player)
        for _, d in dummies do
            d.t += dt
            local span = (d.line.endPoint - d.line.startPoint).Magnitude
            local alpha = 0.5 + 0.5 * math.sin(d.t * DUMMY_SPEED / span * 2) -- back and forth along the line
            local at = d.line.startPoint:Lerp(d.line.endPoint, alpha) + Vector3.new(0, d.height, 0)
            local face = if root then Vector3.new(root.Position.X, at.Y, root.Position.Z) else at + Vector3.zAxis
            d.model:PivotTo(CFrame.lookAt(at, if (face - at).Magnitude > 0.1 then face else at + Vector3.zAxis))
            if root and not done and ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude < DUMMY_REACH then
                sendHome(player)
                step = 1
                stepEvent:FireClient(player, step, #STEPS, "Tagged!", "guards tag you when you get close; back to Zone 1")
            end
        end
    end)

    while player.Parent and not done do
        task.wait(0.1)
        local root = rootOf(player)
        local zone = if root then CourtGeometry.GetZoneAtPosition(root.Position) else nil
        if zone and zone.checkpointIndex == STEPS[step].checkpoint then
            if step == #STEPS then
                done = true
            else
                step += 1
                announce()
            end
        end
    end
    patrol:Disconnect()
    for _, d in dummies do
        d.model:Destroy()
    end
    if not player.Parent then return end

    player:SetAttribute("TutorialDone", true)
    stepEvent:FireClient(player, 0, #STEPS, "Tubig!", "tutorial done; heading to the hub")
    task.wait(4)
    if RunService:IsStudio() then return end
    local options = Instance.new("TeleportOptions")
    options:SetTeleportData({ funnels = FunnelService.Sessions({ player }) })
    TravelService.Send(Config.Places.HubPlaceId, { player }, options)
end

-- isHub: watch for players who still need the tutorial (their data loads `TutorialDone` = false)
function TutorialService.Init(isHub: boolean)
    if not isHub then return end
    local function watch(player: Player)
        player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
            task.delay(2, sendToTutorial, player) -- let them load into the hub first
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return TutorialService
