--!strict
--[[
    MatchService.luau
    Authoritative server service orchestrating the Patintero match loop.
    Manages phases, team rotations, round timers, zone checkpoints, and "Tubig!" scoring.
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

local guardRolesOrder: { Types.GuardRole } = { "Line1", "Line2", "Line3", "Patotot" }

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

        -- 1. Forward progression (Advancing through checkpoints)
        if not state.hasReachedEndZone then
            if currentZone.checkpointIndex > state.checkpointProgress then
                PlayerStateService.SetCheckpoint(player, currentZone.checkpointIndex, currentZone.isEndZone)
                matchState.passerScore += Config.Match.PointsForZoneAdvance
                broadcastMatchState()
                checkpointEvent:FireAllClients(player.UserId, currentZone.name, matchState.passerScore)
            end
        else
            -- 2. Return journey: Reached EndZone and made it back to HomeZone!
            if currentZone.isHomeZone then
                matchState.passerScore += Config.Match.PointsForTubig
                broadcastMatchState()
                tubigEvent:FireAllClients(player.UserId, player.DisplayName, matchState.passerScore)

                -- Reset checkpoint progress for consecutive runs
                PlayerStateService.SetCheckpoint(player, 0, false)
            end
        end
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
    TagService.SetTagSuccessCallback(function(_tagger: Player, _target: Player)
        matchState.guardScore += Config.Match.PointsForTag
        matchState.activePasserCount = countActivePassers()
        broadcastMatchState()

        -- If all passers are tagged, end round early!
        if matchState.activePasserCount <= 0 and #teamRoster.Passers > 0 then
            matchState.timeRemaining = 0
        end
    end)

    -- RemoteFunction for initial data
    local initialDataFunc = Remotes.GetFunction("GetInitialMatchData")
    initialDataFunc.OnServerInvoke = function(_player: Player)
        return matchState
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
            while #Players:GetPlayers() < Config.Match.MinPlayersToStart do
                task.wait(1)
            end

            -- 2. Intermission & Team Assignment
            matchState.phase = "Countdown"
            matchState.timeRemaining = Config.Match.CountdownTime
            assignTeams()
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

            while matchState.timeRemaining > 0 and matchState.phase == "RoundActive" do
                task.wait(1)
                matchState.timeRemaining -= 1
                broadcastMatchState()
            end

            -- 4. Round Ended
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
            else
                swapTeams()
            end
        end
    end)
end

return MatchService
