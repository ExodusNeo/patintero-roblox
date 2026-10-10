--!strict
--[[
    PlayerStateService.luau
    Authoritative server service tracking player match status, role assignments,
    checkpoint progression, and state replication.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local PlayerStateService = {}
local playerStates: { [Player]: Types.PlayerMatchState } = {}

local function createDefaultState(player: Player): Types.PlayerMatchState
    return {
        userId = player.UserId,
        team = "Spectators",
        guardRole = nil,
        lapPhase = "Outbound",
        highestZoneCleared = 0,
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
        player:SetAttribute("Team", "Spectators")
        replicatePlayerState(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerStates[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        playerStates[player] = createDefaultState(player)
        player:SetAttribute("Team", "Spectators")
        replicatePlayerState(player)
    end

    -- Replicate non-critical cosmetic actions (slide dust, etc.) to all other clients
    local cosmeticEvent = Remotes.GetUnreliableEvent("CosmeticAction")
    cosmeticEvent.OnServerEvent:Connect(function(player: Player, actionType: any, position: any)
        if typeof(actionType) == "string" and typeof(position) == "Vector3" then
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player then
                    cosmeticEvent:FireClient(otherPlayer, actionType, position)
                end
            end
        end
    end)
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
    player:SetAttribute("Team", team) -- lets every client know who is who (targeting, VFX)
    replicatePlayerState(player)
end

function PlayerStateService.SetTagged(player: Player, isTagged: boolean)
    local state = playerStates[player]
    if not state then return end

    state.isTagged = isTagged
    replicatePlayerState(player)
end

function PlayerStateService.SetCheckpoint(player: Player, zoneIndex: number, isEndZone: boolean)
    local state = playerStates[player]
    if not state then return end

    state.highestZoneCleared = zoneIndex
    if isEndZone then
        state.hasReachedEndZone = true
        state.lapPhase = "Inbound"
    end
    replicatePlayerState(player)
end

function PlayerStateService.ResetLap(player: Player)
    local state = playerStates[player]
    if not state then return end

    state.lapPhase = "Outbound"
    state.highestZoneCleared = 0
    state.hasReachedEndZone = false
    replicatePlayerState(player)
end

function PlayerStateService.ResetForNewRound(player: Player)
    local state = playerStates[player]
    if not state then return end

    state.isTagged = false
    state.lapPhase = "Outbound"
    state.highestZoneCleared = 0
    state.hasReachedEndZone = false
    replicatePlayerState(player)
end

return PlayerStateService
