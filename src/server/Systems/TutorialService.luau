--!strict
--[[
    TutorialService.luau
    First-time tutorial. Hub: a player whose `TutorialDone` loads false is sent alone to a reserved match-place
    server with teleport data `tutorial = true` (Init(true)). Match place: MatchService hands that server to Run()
    instead of starting a match. The player learns by doing: each step completes on the action itself (sprint,
    slide, a skill, zones, TUBIG, a tag); TutorialController draws the step card and a beacon at the target.
    From step 3 two dummy guards track the player along Line1 / Line2; getting close sends you back to the start
    of the leg (Home on the way out, the Safehouse on the way back; the step stays). Last, the player guards Line2 and tags a practice runner. Finishing sets `TutorialDone`, gives
    Config.Progression.TutorialSpins and returns the player to the hub.
    Studio: StudioMode = "Tutorial" runs it; teleports are skipped there.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local CourtService = require(script.Parent.CourtService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local TravelService = require(script.Parent.TravelService)
local FunnelService = require(script.Parent.FunnelService)
local StyleService = require(script.Parent.StyleService)

local TutorialService = {}

-- kind: "sprint" (sprint, then reach `zone`), "slide", "skill", "zone" (reach `zone`), "tubig" (Home after the
-- Safehouse), "tag" (guard practice). zone = checkpointIndex (0 Home, 3 Safehouse)
type Step = { kind: string, title: string, hint: string, keys: { string }, zone: number? }
local STEPS: { Step } = {
    { kind = "sprint", zone = 1, title = "Sprint", hint = "Hold SHIFT and run into Zone 1.", keys = { "SHIFT" } },
    { kind = "slide", title = "Slide", hint = "While running, press C to slide. It's fast but costs stamina.", keys = { "C" } },
    { kind = "zone", zone = 2, title = "Get past the guard", hint = "Guards tag you if they get close. Reach Zone 2.", keys = {} },
    { kind = "skill", title = "Use your skill", hint = "Press Q. Every style has two skills, on Q and E.", keys = { "Q" } },
    { kind = "zone", zone = 3, title = "Safehouse", hint = "Reach the Safehouse at the far end.", keys = {} },
    { kind = "tubig", zone = 0, title = "Tubig!", hint = "Run all the way back home. In a match that's +5.", keys = {} },
    { kind = "tag", title = "Play guard", hint = "You guard Line 2 now. Tag the runner as it crosses.", keys = { "CLICK", "F" } },
}
local GUARD_LINES = { "Line1", "Line2" }
local GUARD_SPEED = 11 -- studs/s a dummy guard slides along its line toward you
local GUARD_SIGHT = 22 -- studs along the court within which a dummy tracks you
local GUARD_REACH = 4.5
local RUNNER_LANE = 8 -- studs off center the practice runner runs
local RUNNER_SPEED = 9
local PRACTICE_REACH = Config.Tagging.BaseReachDistance + Config.Tagging.MaxLatencySlackDistance
local SPRINT_SPEED = Config.Movement.WalkSpeed + 4 -- moving faster than this counts as sprinting
local SKIN = Color3.fromRGB(204, 170, 140)
local GUARD_SHIRT = Color3.fromRGB(61, 123, 224) -- Blue side
local RUNNER_SHIRT = Color3.fromRGB(210, 69, 63) -- Red side
local FLAT = Vector3.new(1, 0, 1)

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

local function makeDummy(name: string, shirt: Color3, armsWide: boolean): (Model, number)
    local description = Instance.new("HumanoidDescription")
    description.HeadColor, description.LeftArmColor, description.RightArmColor = SKIN, SKIN, SKIN
    description.LeftLegColor, description.RightLegColor = SKIN, SKIN
    description.TorsoColor = shirt
    local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    dummy.Name = name
    for _, part in dummy:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end
    if armsWide then -- like a Guard's BodyPose: rotate the shoulder joints' parent-side frames
        for joint, rot in { RightShoulder = CFrame.Angles(0, math.rad(30), math.rad(82)), LeftShoulder = CFrame.Angles(0, math.rad(-30), math.rad(-82)) } do
            local j = dummy:FindFirstChild(joint, true)
            if j and j:IsA("Motor6D") then
                j.C0 = j.C0 * rot
            elseif j and j:IsA("AnimationConstraint") and j.Attachment0 then
                j.Attachment0.CFrame = j.Attachment0.CFrame * rot
            end
        end
    end
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    dummy.Parent = Workspace
    return dummy, dummy:GetExtentsSize().Y / 2
end

local function zoneCenter(index: number): Vector3
    for _, zone in CourtGeometry.GetZoneDefinitions() do
        if zone.checkpointIndex == index then
            local c = (zone.minPoint + zone.maxPoint) / 2
            return Vector3.new(c.X, 0, c.Z)
        end
    end
    return Vector3.zero
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function moveTo(player: Player, cf: CFrame)
    local root = rootOf(player)
    if root then
        root.CFrame = cf
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
    moveTo(player, CourtService.GetSpawnCFrame("Passers", nil))

    local stepEvent = Remotes.GetEvent("TutorialStep")
    local step = 1
    local done = false
    -- What the player did during the current step (set by remotes, cleared on each new step)
    local sprinted, slid, usedSkill, tagged = false, false, false, false

    local function info(kind: "step" | "tagged" | "done"): Types.TutorialStepInfo
        local s = STEPS[step]
        local label = if s.zone == 0 then "HOME" elseif s.zone == 3 then "SAFEHOUSE" elseif s.zone then `ZONE {s.zone}` else nil
        return {
            kind = kind, step = step, total = #STEPS, title = s.title, hint = s.hint, keys = s.keys,
            target = if s.zone then zoneCenter(s.zone) else nil, targetLabel = label,
        }
    end
    local function advance()
        step += 1
        sprinted, slid, usedSkill, tagged = false, false, false, false
        if step > #STEPS then
            done = true
        else
            stepEvent:FireClient(player, info("step"))
        end
    end

    type Guard = { model: Model, line: Types.LineDefinition, height: number, s: number }
    local guards: { Guard } = {}
    local runner: { model: Model, height: number, t: number }? = nil

    local conns: { RBXScriptConnection } = {}
    table.insert(conns, Remotes.GetEvent("CosmeticAction").OnServerEvent:Connect(function(who: Player, action: any)
        if who == player and action == "Slide" then
            slid = true
        end
    end))
    table.insert(conns, Remotes.GetEvent("UseSkill").OnServerEvent:Connect(function(who: Player)
        if who == player then
            usedSkill = true
        end
    end))
    table.insert(conns, Remotes.GetEvent("PracticeTag").OnServerEvent:Connect(function(who: Player, model: any)
        local root = rootOf(player)
        if who ~= player or STEPS[step] == nil or STEPS[step].kind ~= "tag" or not root then return end
        if typeof(model) ~= "Instance" or not model:IsA("Model") or not CollectionService:HasTag(model, "PracticeRunner") then return end
        if (model:GetPivot().Position - root.Position).Magnitude <= PRACTICE_REACH then
            tagged = true
        end
    end))

    -- Dummy guards slide along their line toward you once you're near it; the practice runner jogs across Line2
    table.insert(conns, RunService.Heartbeat:Connect(function(dt)
        local root = rootOf(player)
        for _, g in guards do
            local line = g.line
            local span = line.endPoint - line.startPoint
            local length = span.Magnitude
            local want = length / 2
            if root and math.abs(root.Position.Z - line.startPoint.Z) < GUARD_SIGHT then
                want = math.clamp((root.Position - line.startPoint):Dot(span.Unit), 0, length)
            end
            g.s += math.clamp(want - g.s, -GUARD_SPEED * dt, GUARD_SPEED * dt)
            local at = line.startPoint + span.Unit * g.s + Vector3.new(0, g.height, 0)
            local look = if root then Vector3.new(root.Position.X, at.Y, root.Position.Z) else at - Vector3.zAxis
            g.model:PivotTo(CFrame.lookAt(at, if (look - at).Magnitude > 0.1 then look else at - Vector3.zAxis))
            if root and ((root.Position - at) * FLAT).Magnitude < GUARD_REACH then
                -- Back to the start of the leg: on the way home that's the Safehouse, so a tag can't finish TUBIG
                local back = if STEPS[step] and STEPS[step].kind == "tubig"
                    then CFrame.lookAt(zoneCenter(3) + Vector3.new(0, 3, 0), zoneCenter(0) + Vector3.new(0, 3, 0))
                    else CourtService.GetSpawnCFrame("Passers", nil)
                moveTo(player, back)
                stepEvent:FireClient(player, info("tagged"))
            end
        end
        if runner then
            runner.t += dt
            local phase = runner.t * RUNNER_SPEED / 30
            local at = Vector3.new(RUNNER_LANE, runner.height, math.sin(phase) * 30) -- back and forth over Line2 (z = 0)
            local heading = if math.cos(phase) >= 0 then 1 else -1
            runner.model:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, heading)))
        end
    end))

    task.wait(0.5)
    stepEvent:FireClient(player, info("step"))

    while player.Parent and not done do
        task.wait(0.1)
        local root = rootOf(player)
        local s = STEPS[step]
        if not root or not s then continue end
        local zone = CourtGeometry.GetZoneAtPosition(root.Position)
        local zoneIndex = if zone then zone.checkpointIndex else nil
        if (root.AssemblyLinearVelocity * FLAT).Magnitude > SPRINT_SPEED then
            sprinted = true
        end

        if s.kind == "sprint" and sprinted and zoneIndex == s.zone
            or s.kind == "slide" and slid
            or s.kind == "skill" and usedSkill
            or s.kind == "zone" and zoneIndex == s.zone then
            advance()
        elseif s.kind == "tubig" and zoneIndex == 0 then
            Remotes.GetEvent("TubigScored"):FireClient(player, player.UserId, player.DisplayName, 0) -- whistle, fanfare, cheer
            advance()
        elseif s.kind == "tag" and tagged and runner then
            Remotes.GetEvent("TagConfirmed"):FireClient(player, player.UserId, 0, runner.model:GetPivot().Position)
            advance()
        end

        -- Set the court up for the new step
        local now = STEPS[step]
        if step == 3 and #guards == 0 then
            for _, lineId in GUARD_LINES do
                local model, height = makeDummy("TutorialGuard", GUARD_SHIRT, true)
                local line = CourtGeometry.GetLineDefinitions()[lineId :: any]
                table.insert(guards, { model = model, line = line, height = height, s = (line.endPoint - line.startPoint).Magnitude / 2 })
            end
        elseif now and now.kind == "tag" and not runner then
            for _, g in guards do
                g.model:Destroy()
            end
            table.clear(guards)
            PlayerStateService.SetTeam(player, "Guards", "Line2")
            moveTo(player, CourtService.GetSpawnCFrame("Guards", "Line2"))
            local model, height = makeDummy("PracticeRunner", RUNNER_SHIRT, false)
            CollectionService:AddTag(model, "PracticeRunner")
            local highlight = Instance.new("Highlight")
            highlight.FillTransparency = 1
            highlight.OutlineColor = RUNNER_SHIRT
            highlight.Parent = model
            runner = { model = model, height = height, t = 0 }
        end
    end

    for _, conn in conns do
        conn:Disconnect()
    end
    for _, g in guards do
        g.model:Destroy()
    end
    if runner then
        task.delay(1, runner.model.Destroy, runner.model)
    end
    if not player.Parent then return end

    player:SetAttribute("TutorialDone", true)
    StyleService.AddSpins(player, Config.Progression.TutorialSpins)
    stepEvent:FireClient(player, {
        kind = "done", step = #STEPS, total = #STEPS, title = "Tutorial complete",
        hint = `+{Config.Progression.TutorialSpins} spins. Heading to the hub...`, keys = {},
    } :: Types.TutorialStepInfo)
    task.wait(5)
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
