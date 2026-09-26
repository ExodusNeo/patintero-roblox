--!strict
--[[
    TagService.luau
    Authoritative server service validating tag attempts by Guards.
    Guarantees strict anti-exploit enforcement: reach radius, line-constraint checks,
    cooldowns, and line-of-sight raycasts.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerStateService = require(script.Parent.PlayerStateService)

local TagService = {}
local lastTagTimestamp: { [Player]: number } = {}

-- Callback for MatchService integration
local onTagSuccessCallback: ((tagger: Player, target: Player) -> ())? = nil

local function validateLineConstraint(guardPosition: Vector3, role: Types.GuardRole): boolean
    local lineDefs = CourtGeometry.GetLineDefinitions()
    local lineDef = lineDefs[role]
    if not lineDef then
        return false
    end

    local distance = CourtGeometry.GetHorizontalDistanceToSegment(guardPosition, lineDef.startPoint, lineDef.endPoint)
    return distance <= Config.Tagging.MaxLineDistanceTolerance
end

local function hasLineOfSight(origin: Vector3, targetPos: Vector3, taggerChar: Model, targetChar: Model): boolean
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { taggerChar, targetChar }
    raycastParams.IgnoreWater = true

    local direction = targetPos - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)

    -- If no obstacle hit, line of sight is clear
    return result == nil
end

function TagService.SetTagSuccessCallback(callback: (tagger: Player, target: Player) -> ())
    onTagSuccessCallback = callback
end

function TagService.Init()
    local tagAttemptEvent = Remotes.GetEvent("TagAttempt")

    tagAttemptEvent.OnServerEvent:Connect(function(player: Player, targetUserId: any)
        if typeof(targetUserId) ~= "number" then
            return
        end

        local taggerState = PlayerStateService.GetState(player)
        if not taggerState or taggerState.team ~= "Guards" or not taggerState.guardRole then
            return
        end

        -- Cooldown rate-limit
        local now = os.clock()
        local lastTime = lastTagTimestamp[player] or 0
        if (now - lastTime) < Config.Tagging.TagCooldown then
            return
        end
        lastTagTimestamp[player] = now

        -- Target resolution & validation
        local targetPlayer = Players:GetPlayerByUserId(targetUserId)
        if not targetPlayer or targetPlayer == player then
            return
        end

        local targetState = PlayerStateService.GetState(targetPlayer)
        if not targetState or targetState.team ~= "Passers" or targetState.isTagged then
            return
        end

        local taggerChar = player.Character
        local targetChar = targetPlayer.Character
        if not taggerChar or not targetChar then
            return
        end

        local taggerRoot = taggerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not taggerRoot or not targetRoot then
            return
        end

        local taggerPos = taggerRoot.Position
        local targetPos = targetRoot.Position

        -- 1. Anti-Exploit: Line constraint check (Guard MUST be on their assigned line)
        if not validateLineConstraint(taggerPos, taggerState.guardRole) then
            warn(`[TagService] Rejected tag: Guard {player.Name} was off their line {taggerState.guardRole}`)
            return
        end

        -- 2. Anti-Exploit: Distance check with network ping tolerance
        local maxAllowedDistance = Config.Tagging.BaseReachDistance + Config.Tagging.MaxLatencySlackDistance
        local currentDistance = (targetPos - taggerPos).Magnitude
        if currentDistance > maxAllowedDistance then
            warn(`[TagService] Rejected tag: Distance {currentDistance} exceeded max {maxAllowedDistance}`)
            return
        end

        -- 3. Anti-Exploit: Line-of-sight check
        if not hasLineOfSight(taggerPos, targetPos, taggerChar, targetChar) then
            warn(`[TagService] Rejected tag: No line of sight between {player.Name} and {targetPlayer.Name}`)
            return
        end

        -- 4. Tag Validated!
        PlayerStateService.SetTagged(targetPlayer, true)

        -- Immobilize / Stun target
        local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
        if targetHumanoid then
            targetHumanoid.WalkSpeed = 0
            task.delay(Config.Tagging.TagStunDuration, function()
                if targetChar and targetHumanoid and targetHumanoid.Health > 0 then
                    targetHumanoid.WalkSpeed = Config.Movement.WalkSpeed
                end
            end)
        end

        -- Broadcast TagConfirmed to all clients for VFX and audio
        local tagConfirmedEvent = Remotes.GetEvent("TagConfirmed")
        tagConfirmedEvent:FireAllClients(player.UserId, targetPlayer.UserId, targetPos)

        if onTagSuccessCallback then
            onTagSuccessCallback(player, targetPlayer)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        lastTagTimestamp[player] = nil
    end)
end

return TagService
