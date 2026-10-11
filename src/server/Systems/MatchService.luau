--!strict
--[[
    MatchService.luau
    Authoritative server service orchestrating the Patintero match loop.
    Manages phases, team rotations, round timers, zone checkpoints, and "Tubig!" scoring.
    Implements a strict, anti-exploit sequential lap state machine (Outbound -> Inbound).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local CourtService = require(script.Parent.CourtService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local TagService = require(script.Parent.TagService)
local StyleService = require(script.Parent.StyleService)
local TravelService = require(script.Parent.TravelService)

local MatchService = {}

local matchState: Types.MatchState = {
    phase = "Lobby",
    roundNumber = 0,
    timeRemaining = Config.Match.IntermissionTime,
    passerScore = 0,
    guardScore = 0,
    activePasserCount = 0,
}

local teamRoster: {
    Passers: { Player },
    Guards: { Player },
} = {
    Passers = {},
    Guards = {},
}

-- Assignment priority (a lone guard gets the mid line) and the line-hop cycle.
local guardRolesOrder: { Types.GuardRole } = { "Line2", "Line1", "Line3", "Patotot" }
local lastLineSwitch: { [Player]: number } = {}

-- Party size the hub sent (teleport data is client-visible, so it's only a wait hint).
local expectedPlayers = Config.Match.MinPlayersToStart
local lastJoinTime = 0

local function readJoinData(player: Player)
    lastJoinTime = os.clock()
    local data = player:GetJoinData().TeleportData
    if typeof(data) == "table" and typeof(data.expectedPlayers) == "number" and data.expectedPlayers == data.expectedPlayers then
        expectedPlayers = math.clamp(math.floor(data.expectedPlayers), 1, 8)
    end
end

local function returnToHub()
    if RunService:IsStudio() then return end -- teleports don't work in Studio; just play again
    TravelService.Send(Config.Places.HubPlaceId, Players:GetPlayers())
    -- Anyone whose teleport failed stays and gets another match.
end

local function broadcastMatchState()
    local remote = Remotes.GetEvent("MatchStateUpdated")
    remote:FireAllClients(matchState)
end

local function teleportToSpawn(player: Player, team: Types.Team, guardRole: Types.GuardRole?)
    local character = player.Character
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local spawnCFrame = CourtService.GetSpawnCFrame(team, guardRole)
    root.CFrame = spawnCFrame
end

local function assignTeams()
    local allPlayers = Players:GetPlayers()
    table.clear(teamRoster.Passers)
    table.clear(teamRoster.Guards)

    -- Split players evenly into Passers and Guards
    for i, player in ipairs(allPlayers) do
        if i % 2 == 1 then
            table.insert(teamRoster.Passers, player)
            PlayerStateService.SetTeam(player, "Passers", nil)
        else
            table.insert(teamRoster.Guards, player)
            local roleIndex = (#teamRoster.Guards - 1) % #guardRolesOrder + 1
            local role = guardRolesOrder[roleIndex]
            PlayerStateService.SetTeam(player, "Guards", role)
        end
    end
end

local function swapTeams()
    local prevPassers = table.clone(teamRoster.Passers)
    local prevGuards = table.clone(teamRoster.Guards)

    table.clear(teamRoster.Passers)
    table.clear(teamRoster.Guards)

    -- Previous guards become passers
    for _, player in ipairs(prevGuards) do
        if player.Parent then
            table.insert(teamRoster.Passers, player)
            PlayerStateService.SetTeam(player, "Passers", nil)
        end
    end

    -- Previous passers become guards
    for i, player in ipairs(prevPassers) do
        if player.Parent then
            table.insert(teamRoster.Guards, player)
            local roleIndex = (i - 1) % #guardRolesOrder + 1
            local role = guardRolesOrder[roleIndex]
            PlayerStateService.SetTeam(player, "Guards", role)
        end
    end
end

local function setupRoundPositions()
    for _, player in ipairs(teamRoster.Passers) do
        PlayerStateService.ResetForNewRound(player)
        teleportToSpawn(player, "Passers", nil)
    end

    for _, player in ipairs(teamRoster.Guards) do
        local state = PlayerStateService.GetState(player)
        local role = if state then state.guardRole else nil
        PlayerStateService.ResetForNewRound(player)
        teleportToSpawn(player, "Guards", role)
    end

    matchState.activePasserCount = #teamRoster.Passers
end

local function checkPasserPositions()
    if matchState.phase ~= "RoundActive" then return end

    local checkpointEvent = Remotes.GetEvent("ZoneCheckpointReached")
    local tubigEvent = Remotes.GetEvent("TubigScored")

    for _, player in ipairs(teamRoster.Passers) do
        local state = PlayerStateService.GetState(player)
        if not state or state.isTagged then continue end

        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if not root then continue end

        local currentZone = CourtGeometry.GetZoneAtPosition(root.Position)
        if not currentZone then continue end

        -- PHASE 1: Outbound Journey (Home Base -> Zone 1 -> Zone 2 -> Safehouse)
        if state.lapPhase == "Outbound" then
            -- Player must advance strictly in sequence: next checkpoint must be highestZoneCleared + 1
            if currentZone.checkpointIndex == state.highestZoneCleared + 1 then
                PlayerStateService.SetCheckpoint(player, currentZone.checkpointIndex, currentZone.isEndZone)
                matchState.passerScore += Config.Match.PointsForZoneAdvance
                broadcastMatchState()

                local zoneLabel = if currentZone.isEndZone then "SAFEHOUSE" else currentZone.name
                checkpointEvent:FireAllClients(player.UserId, zoneLabel, matchState.passerScore)
            end

        -- PHASE 2: Inbound Return Journey (Safehouse -> Zone 2 -> Zone 1 -> Home Base)
        elseif state.lapPhase == "Inbound" then
            -- Standing in EndZone or intermediate zones awards 0 duplicate points!
            -- Only reaching Home Base with a valid completed trip triggers "TUBIG!"
            if currentZone.isHomeZone and state.hasReachedEndZone then
                matchState.passerScore += Config.Match.PointsForTubig
                broadcastMatchState()
                tubigEvent:FireAllClients(player.UserId, player.DisplayName, matchState.passerScore)
                StyleService.AddSpins(player, Config.Styles.SpinsPerTubig)

                -- Explicitly reset lap state so player can embark on a new outbound run
                PlayerStateService.ResetLap(player)
            end
        end
    end
end

-- Guard hops to the next line no other guard holds, keeping their position along the line.
local function onSwitchLine(player: Player)
    if matchState.phase ~= "RoundActive" and matchState.phase ~= "Countdown" then return end
    local state = PlayerStateService.GetState(player)
    if not state or state.team ~= "Guards" or not state.guardRole then return end

    local now = os.clock()
    if now - (lastLineSwitch[player] or -math.huge) < Config.Tagging.LineSwitchCooldown then return end

    local taken: { [string]: boolean } = {}
    for _, guard in ipairs(teamRoster.Guards) do
        local guardState = PlayerStateService.GetState(guard)
        if guard ~= player and guard.Parent and guardState and guardState.guardRole then
            taken[guardState.guardRole] = true
        end
    end

    local current = table.find(guardRolesOrder, state.guardRole) or 1
    for step = 1, #guardRolesOrder - 1 do
        local role = guardRolesOrder[(current - 1 + step) % #guardRolesOrder + 1]
        if taken[role] then continue end

        lastLineSwitch[player] = now
        PlayerStateService.SetTeam(player, "Guards", role)
        local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if root then
            local line = CourtGeometry.GetLineDefinitions()[role]
            local spot = CourtGeometry.ProjectPointOntoSegment(root.Position, line.startPoint, line.endPoint)
            root.CFrame = CFrame.new(spot.X, root.Position.Y, spot.Z) * root.CFrame.Rotation
        end
        return
    end
end

local function countActivePassers(): number
    local count = 0
    for _, player in ipairs(teamRoster.Passers) do
        local state = PlayerStateService.GetState(player)
        if state and not state.isTagged and player.Parent then
            count += 1
        end
    end
    return count
end

function MatchService.Init()
    -- Hook TagService onTagSuccess callback
    TagService.SetTagSuccessCallback(function(_tagger: Player, target: Player)
        matchState.guardScore += Config.Match.PointsForTag
        matchState.activePasserCount = countActivePassers()
        broadcastMatchState()

        -- Tagged Passers are out for the round: send them to the sideline.
        local root = if target.Character then target.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if root then
            root.CFrame = CourtService.GetSidelineCFrame()
        end
    end)

    -- RemoteFunction for initial data
    local initialDataFunc = Remotes.GetFunction("GetInitialMatchData")
    initialDataFunc.OnServerInvoke = function(_player: Player)
        return matchState
    end

    Remotes.GetEvent("SwitchLine").OnServerEvent:Connect(onSwitchLine)
    Players.PlayerRemoving:Connect(function(player)
        lastLineSwitch[player] = nil
    end)

    Players.PlayerAdded:Connect(readJoinData)
    for _, player in Players:GetPlayers() do
        readJoinData(player)
    end

    -- Position checking loop for zone checkpoints
    task.spawn(function()
        while true do
            task.wait(0.2)
            checkPasserPositions()
        end
    end)

    -- Main match state machine loop
    task.spawn(function()
        while true do
            -- 1. Lobby Phase
            matchState.phase = "Lobby"
            broadcastMatchState()
            -- A smaller group sent on purpose by the hub (e.g. the owner's 1-player test pad) may start
            while #Players:GetPlayers() < math.min(Config.Match.MinPlayersToStart, expectedPlayers) do
                task.wait(1)
            end
            local arrivalDeadline = os.clock() + Config.Match.ArrivalTimeout
            -- Also wait until joins settle, so players loading a few seconds apart all get a team.
            while (#Players:GetPlayers() < expectedPlayers or os.clock() - lastJoinTime < Config.Match.JoinSettleTime)
                and os.clock() < arrivalDeadline do
                task.wait(0.5)
            end

            -- 2. Intermission & Team Assignment
            matchState.phase = "Countdown"
            matchState.timeRemaining = Config.Match.CountdownTime
            if matchState.roundNumber == 0 then
                assignTeams() -- later rounds keep the roster swapTeams() produced
            end
            setupRoundPositions()
            broadcastMatchState()

            while matchState.timeRemaining > 0 do
                task.wait(1)
                matchState.timeRemaining -= 1
                broadcastMatchState()
            end

            -- 3. Round Active
            matchState.roundNumber += 1
            matchState.phase = "RoundActive"
            matchState.timeRemaining = Config.Match.RoundDuration
            broadcastMatchState()

            -- Ends on time-out or when every Passer is tagged out / has left
            while matchState.timeRemaining > 0 and countActivePassers() > 0 do
                task.wait(1)
                matchState.timeRemaining -= 1
                broadcastMatchState()
            end

            -- 4. Round Ended
            for _, player in ipairs(teamRoster.Passers) do
                StyleService.AddSpins(player, Config.Styles.SpinsPerRound)
            end
            for _, player in ipairs(teamRoster.Guards) do
                StyleService.AddSpins(player, Config.Styles.SpinsPerRound)
            end
            matchState.phase = "RoundEnded"
            matchState.timeRemaining = 5
            broadcastMatchState()
            task.wait(5)

            -- 5. Swap sides or conclude match
            if matchState.roundNumber >= 2 then
                matchState.phase = "MatchOver"
                broadcastMatchState()
                task.wait(8)

                -- Reset match scores
                matchState.roundNumber = 0
                matchState.passerScore = 0
                matchState.guardScore = 0
                returnToHub()
            else
                swapTeams()
            end
        end
    end)
end

return MatchService
