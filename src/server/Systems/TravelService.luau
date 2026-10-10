--!strict
--[[
    TravelService.luau
    Server-side teleports between the hub and match places.
    Players get the `Teleporting` attribute (blocks spins/queues) and their data is saved and
    released before leaving; a failed teleport hands their data back to this server.
    Teleports never work in Studio: Send() returns false there and players stay.
]]

local TeleportService = game:GetService("TeleportService")

local DataService = require(script.Parent.DataService)

local TravelService = {}

local ATTEMPTS = 3
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local function resume(player: Player)
    player:SetAttribute("Teleporting", nil)
    DataService.Resume(player)
end

-- Use options.ReservedServerAccessCode (not ShouldReserveServer) for matches, so a retried
-- teleport for one player still lands in the same match server.
function TravelService.Send(placeId: number, players: { Player }, options: TeleportOptions?): boolean
    for _, player in players do
        player:SetAttribute("Teleporting", true)
    end
    DataService.Release(players)

    local ok, err = false, nil
    for attempt = 1, ATTEMPTS do
        ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, players, options)
        if ok then break end
        if attempt < ATTEMPTS then
            task.wait(RETRY_DELAY)
        end
    end

    if not ok then
        warn(`[TravelService] Teleport to {placeId} failed: {err}`)
        for _, player in players do
            if player.Parent then
                resume(player)
            end
        end
    end
    return ok
end

function TravelService.Init()
    -- TeleportAsync can succeed and the teleport still fail later: retry transient failures.
    TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
        if result ~= Enum.TeleportResult.Flooded and result ~= Enum.TeleportResult.Failure then
            warn(`[TravelService] {player.Name} teleport failed [{result.Name}]: {message}`)
            resume(player)
            return
        end

        task.wait(if result == Enum.TeleportResult.Flooded then FLOOD_DELAY else RETRY_DELAY)
        if not player.Parent then return end
        local ok = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)
        if not ok then
            resume(player)
        end
    end)
end

return TravelService
