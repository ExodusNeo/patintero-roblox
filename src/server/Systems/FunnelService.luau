--!strict
--[[
    FunnelService.luau
    Analytics funnel "MatchLoop" (Creator Dashboard > Analytics > Funnels) across both places:
    1 Joined hub -> 2 Sat in lobby -> 3 Match started -> 4 Match finished -> 5 Back in hub.
    Each player's session id rides along in teleport data (`funnels`, userId -> id). Back in the hub, the old
    session logs step 5 and a new one starts at step 1.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local AnalyticsService = game:GetService("AnalyticsService")

local FunnelService = {}

local FUNNEL = "MatchLoop"
local sessions: { [Player]: string } = {}

function FunnelService.Step(player: Player, step: number, name: string)
    local id = sessions[player]
    if not id then return end
    pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, FUNNEL, id, step, name)
end

-- For TeleportOptions:SetTeleportData({ funnels = FunnelService.Sessions(group), ... })
function FunnelService.Sessions(players: { Player }): { [string]: string }
    local out = {}
    for _, player in players do
        out[tostring(player.UserId)] = sessions[player]
    end
    return out
end

local function arrived(player: Player, isHub: boolean)
    local data = player:GetJoinData().TeleportData
    local funnels = if typeof(data) == "table" then data.funnels else nil
    local old = if typeof(funnels) == "table" then funnels[tostring(player.UserId)] else nil
    -- Client-visible teleport data: only accept a GUID-shaped string
    if typeof(old) ~= "string" or #old > 40 then
        old = nil
    end
    if isHub then
        if old then
            sessions[player] = old
            FunnelService.Step(player, 5, "Back in hub")
        end
        sessions[player] = HttpService:GenerateGUID(false)
        FunnelService.Step(player, 1, "Joined hub")
    else
        sessions[player] = old
    end
end

function FunnelService.Init(isHub: boolean)
    Players.PlayerAdded:Connect(function(player)
        arrived(player, isHub)
    end)
    for _, player in Players:GetPlayers() do
        arrived(player, isHub)
    end
    Players.PlayerRemoving:Connect(function(player)
        sessions[player] = nil
    end)
end

return FunnelService
