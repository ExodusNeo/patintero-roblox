--!strict
--[[
    MatchService.luau
    Authoritative server service orchestrating the Patintero match loop.
    Manages phases, team rotations, round timers, zone checkpoints, and "Tubig!" scoring.
    Implements a strict, anti-exploit sequential lap state machine (Outbound -> Inbound), and moves a Passer
    back to where they were ~1 s ago when they cover more ground than Config.Match.MaxRunSpeed (+ MaxBurst).
    A Tubig brings back one tagged teammate. Awards XP (ProgressionService), counts weekly Tubigs
    (LeaderboardService), names the match MVP, and logs funnel steps 3-4 (FunnelService).
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
local ProgressionService = require(script.Parent.ProgressionService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local FunnelService = require(script.Parent.FunnelService)
local TutorialService = require(script.Parent.TutorialService)
local GameMode = require(ReplicatedStorage.Shared.Modules.GameMode)

local MatchService = {}

local matchState: Types.MatchState = {
    phase = "Lobby",
    roundNumber = 0,
    timeRemaining = Config.Match.IntermissionTime,
    redScore = 0,
    blueScore = 0,
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
-- Team each player picked in the hub (the bleacher side they sat on), also from teleport data.
local wantedSide: { [Player]: Types.Side } = {}
-- A reserved server the hub opened for one new player's tutorial (teleport data `tutorial`)
local isTutorial = GameMode.StudioTutorial
-- Points each player scored this match (for the MVP)
local matchPoints: { [Player]: number } = {}
-- Movement check: where each Passer was at the last check, and ~1 s ago
type Mark = { pos: Vector3, t: number }
local lastSeen: { [Player]: Mark } = {}
local trail: { [Player]: Mark } = {}

local function readJoinData(player: Player)
    lastJoinTime = os.clock()
    local data = player:GetJoinData().TeleportData
    if typeof(data) == "table" and data.tutorial == true then
        isTutorial = true
    end
    if typeof(data) == "table" and typeof(data.expectedPlayers) == "number" and data.expectedPlayers == data.expectedPlayers then
        expectedPlayers = math.clamp(math.floor(data.expectedPlayers), 1, 8)
    end
    local sides = if typeof(data) == "table" then data.sides else nil
    local side = if typeof(sides) == "table" then sides[tostring(player.UserId)] else nil
    if side == "Red" or side == "Blue" then
        wantedSide[player] = side
    end
end

local function returnToHub()
    if RunService:IsStudio() then return end -- teleports don't work in Studio; just play again
    local players = Players:GetPlayers()
    local options = Instance.new("TeleportOptions")
    options:SetTeleportData({ funnels = FunnelService.Sessions(players) })
    TravelService.Send(Config.Places.HubPlaceId, players, options)
    -- Anyone whose teleport failed stays and gets another match.
end

local function broadcastMatchState()
    local remote = Remotes.GetEvent("MatchStateUpdated")
    remote:FireAllClients(matchState)
end

-- Adds points to the player's side (Player attribute `Side`) and returns that side's new score.
local function award(player: Player, points: number): number
    matchPoints[player] = (matchPoints[player] or 0) + points
    local side = player:GetAttribute("Side")
    if side == "Red" then
        matchState.redScore += points
    elseif side == "Blue" then
        matchState.blueScore += points
    end
    return if side == "Blue" then matchState.blueScore else matchState.redScore
end

local function teleportToSpawn(player: Player, team: Types.Team, guardRole: Types.GuardRole?)
    local character = player.Character
    if not character then return end

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local spawnCFrame = CourtService.GetSpawnCFrame(team, guardRole)
    root.CFrame = spawnCFrame
    trail[player] = nil -- a server move isn't running
    lastSeen[player] = nil
end

-- A Passer who covered more ground than any legal run (speed hack / teleport) is put back where they were
-- ~1 s ago, and this check gives them no zone progress. Returns true when that happened.
local function tooFar(mark: Mark?, position: Vector3, now: number): boolean
    if not mark then return false end
    local flat = (position - mark.pos) * Vector3.new(1, 0, 1)
    return flat.Magnitude > Config.Match.MaxRunSpeed * (now - mark.t) + Config.Match.MaxBurst
end

local function movedTooFast(player: Player, root: BasePart, now: number): boolean
    local mark = trail[player]
    -- Since the last check (catches one big jump) and over ~1 s (catches many small ones)
    if tooFar(lastSeen[player], root.Position, now) or tooFar(mark, root.Position, now) then
        local back = (mark or lastSeen[player] :: Mark).pos
        warn(`[MatchService] {player.Name} moved too fast; moved back`)
        root.CFrame = CFrame.new(back) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        lastSeen[player] = { pos = back, t = now }
        trail[player] = { pos = back, t = now }
        return true
    end
    lastSeen[player] = { pos = root.Position, t = now }
    if not mark or now - mark.t >= 1 then
        trail[player] = { pos = root.Position, t = now }
    end
    return false
end

-- A Tubig brings back the teammate who has been out the longest (first tagged in roster order)
local function reviveTeammate(scorer: Player)
    for _, player in teamRoster.Passers do
        local state = PlayerStateService.GetState(player)
        if player ~= scorer and player.Parent and state and state.isTagged then
            PlayerStateService.SetTagged(player, false)
            PlayerStateService.ResetLap(player)
            teleportToSpawn(player, "Passers", nil)
            Remotes.GetEvent("PasserRevived"):FireAllClients(player.UserId, player.DisplayName, scorer.DisplayName)
            return
        end
    end
end

local function assignTeams()
    table.clear(teamRoster.Passers)
    table.clear(teamRoster.Guards)

    -- Red starts as Passers, Blue as Guards (sides stay put when roles swap). Everyone keeps the hub bleacher
    -- side they sat on; the rest fill the smaller side, and a side more than one over gives its extras away.
    local red: { Player }, blue: { Player } = {}, {}
    local rest: { Player } = {}
    for _, player in Players:GetPlayers() do
        local side = wantedSide[player]
        table.insert(if side == "Red" then red elseif side == "Blue" then blue else rest, player)
    end
    for _, player in rest do
        table.insert(if #red <= #blue then red else blue, player)
    end
    while #red > #blue + 1 do
        table.insert(blue, table.remove(red) :: Player)
    end
    while #blue > #red + 1 do
        table.insert(red, table.remove(blue) :: Player)
    end

    for _, player in red do
        player:SetAttribute("Side", "Red")
        table.insert(teamRoster.Passers, player)
        PlayerStateService.SetTeam(player, "Passers", nil)
    end
    for i, player in blue do
        player:SetAttribute("Side", "Blue")
        table.insert(teamRoster.Guards, player)
        PlayerStateService.SetTeam(player, "Guards", guardRolesOrder[(i - 1) % #guardRolesOrder + 1])
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

local countActivePassers: () -> number

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

        if movedTooFast(player, root, os.clock()) then continue end

        local currentZone = CourtGeometry.GetZoneAtPosition(root.Position)
        if not currentZone then continue end

        -- PHASE 1: Outbound Journey (Home Base -> Zone 1 -> Zone 2 -> Safehouse)
        if state.lapPhase == "Outbound" then
            -- Player must advance strictly in sequence: next checkpoint must be highestZoneCleared + 1
            if currentZone.checkpointIndex == state.highestZoneCleared + 1 then
                PlayerStateService.SetCheckpoint(player, currentZone.checkpointIndex, currentZone.isEndZone)
                local sideScore = award(player, Config.Match.PointsForZoneAdvance)
                ProgressionService.AddXP(player, Config.Progression.XPPerZone)
                broadcastMatchState()

                local zoneLabel = if currentZone.isEndZone then "SAFEHOUSE" else currentZone.name
                checkpointEvent:FireAllClients(player.UserId, zoneLabel, sideScore)
            end

        -- PHASE 2: Inbound Return Journey (Safehouse -> Zone 2 -> Zone 1 -> Home Base)
        elseif state.lapPhase == "Inbound" then
            -- Standing in EndZone or intermediate zones awards 0 duplicate points!
            -- Only reaching Home Base with a valid completed trip triggers "TUBIG!"
            if currentZone.isHomeZone and state.hasReachedEndZone then
                local sideScore = award(player, Config.Match.PointsForTubig)
                broadcastMatchState()
                tubigEvent:FireAllClients(player.UserId, player.DisplayName, sideScore)
                StyleService.AddSpins(player, Config.Styles.SpinsPerTubig)
                ProgressionService.AddXP(player, Config.Progression.XPPerTubig)
                LeaderboardService.RecordTubig(player)

                -- Explicitly reset lap state so player can embark on a new outbound run
                PlayerStateService.ResetLap(player)
                reviveTeammate(player)
                matchState.activePasserCount = countActivePassers()
                broadcastMatchState()
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

function countActivePassers(): number
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
    TagService.SetTagSuccessCallback(function(tagger: Player, target: Player)
        award(tagger, Config.Match.PointsForTag)
        ProgressionService.AddXP(tagger, Config.Progression.XPPerTag)
        matchState.activePasserCount = countActivePassers()
        broadcastMatchState()

        -- Tagged Passers are out for the round: send them to the sideline.
        local root = if target.Character then target.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if root then
            root.CFrame = CourtService.GetSidelineCFrame()
            trail[target] = nil
            lastSeen[target] = nil
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
        wantedSide[player] = nil
        matchPoints[player] = nil
        trail[player] = nil
        lastSeen[player] = nil
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
        -- A tutorial server runs the tutorial for its one player instead of matches
        while #Players:GetPlayers() == 0 do
            task.wait(0.5)
        end
        task.wait(0.5) -- PlayerAdded (readJoinData) has run
        if isTutorial then
            TutorialService.Run(Players:GetPlayers()[1])
            return
        end

        while true do
            -- 1. Lobby Phase
            matchState.phase = "Lobby"
            matchState.mvpName = nil
            matchState.mvpPoints = nil
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
            if matchState.roundNumber == 1 then
                for _, player in Players:GetPlayers() do
                    FunnelService.Step(player, 3, "Match started")
                end
            end
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
                ProgressionService.AddXP(player, Config.Progression.XPPerRound)
            end
            for _, player in ipairs(teamRoster.Guards) do
                StyleService.AddSpins(player, Config.Styles.SpinsPerRound)
                ProgressionService.AddXP(player, Config.Progression.XPPerRound)
            end
            matchState.phase = "RoundEnded"
            matchState.timeRemaining = 5
            broadcastMatchState()
            task.wait(5)

            -- 5. Swap sides or conclude match
            if matchState.roundNumber >= 2 then
                matchState.phase = "MatchOver"
                local winner = if matchState.redScore > matchState.blueScore then "Red"
                    elseif matchState.blueScore > matchState.redScore then "Blue" else nil
                local mvp, best = nil, 0
                for _, player in Players:GetPlayers() do
                    local points = matchPoints[player] or 0
                    if points > best then
                        mvp, best = player, points
                    end
                    if winner and player:GetAttribute("Side") == winner then
                        ProgressionService.AddXP(player, Config.Progression.XPPerWin)
                    end
                    player:SetAttribute("TutorialDone", true) -- finished a match: never sent to the tutorial
                    FunnelService.Step(player, 4, "Match finished")
                end
                matchState.mvpName = if mvp then mvp.DisplayName else nil
                matchState.mvpPoints = if mvp then best else nil
                table.clear(matchPoints)
                broadcastMatchState()
                task.wait(8)

                -- Reset match scores
                matchState.roundNumber = 0
                matchState.redScore = 0
                matchState.blueScore = 0
                returnToHub()
            else
                swapTeams()
            end
        end
    end)
end

return MatchService
