--!strict
--[[
    PlayerStateService.luau
    Authoritative server service tracking player match status, role assignments,
    checkpoint progression, and state replication.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local PlayerStateService = {}
local playerStates: { [Player]: Types.PlayerMatchState } = {}

local function createDefaultState(player: Player): Types.PlayerMatchState
    return {
        userId = player.UserId,
        team = "Spectators",
        guardRole = nil,
        movementState = "Idle",
        stamina = Config.Movement.MaxStamina,
        lives = Config.Match.MaxLivesPerPasser,
        checkpointProgress = 0,
        hasReachedEndZone = false,
        isTagged = false,
    }
end

local function replicatePlayerState(player: Player)
    local state = playerStates[player]
    if not state then return end

    local remote = Remotes.GetEvent("PlayerStateUpdated")
    remote:FireClient(player, state)
end

function PlayerStateService.Init()
    Players.PlayerAdded:Connect(function(player)
        playerStates[player] = createDefaultState(player)
        replicatePlayerState(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerStates[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        playerStates[player] = createDefaultState(player)
        replicatePlayerState(player)
    end
end

function PlayerStateService.GetState(player: Player): Types.PlayerMatchState?
    return playerStates[player]
end

function PlayerStateService.GetAllStates(): { [Player]: Types.PlayerMatchState }
    return playerStates
end

function PlayerStateService.SetTeam(player: Player, team: Types.Team, guardRole: Types.GuardRole?)
    local state = playerStates[player]
    if not state then return end

    state.team = team
    state.guardRole = guardRole
    replicatePlayerState(player)
end

function PlayerStateService.SetTagged(player: Player, isTagged: boolean)
    local state = playerStates[player]
    if not state then return end

    state.isTagged = isTagged
    replicatePlayerState(player)
end

function PlayerStateService.SetCheckpoint(player: Player, checkpoint: number, reachedEndZone: boolean)
    local state = playerStates[player]
    if not state then return end

    state.checkpointProgress = checkpoint
    if reachedEndZone then
        state.hasReachedEndZone = true
    end
    replicatePlayerState(player)
end

function PlayerStateService.ResetForNewRound(player: Player)
    local state = playerStates[player]
    if not state then return end

    state.lives = Config.Match.MaxLivesPerPasser
    state.isTagged = false
    state.checkpointProgress = 0
    state.hasReachedEndZone = false
    state.stamina = Config.Movement.MaxStamina
    replicatePlayerState(player)
end

return PlayerStateService
