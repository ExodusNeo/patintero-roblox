--!strict
--[[
    GameMode.luau
    Which half of the game this server/client runs: "Hub" (queue pads, spins) or "Match" (the court).
    The same place file is published to both places, so the PlaceId decides.
    In Studio, set Workspace attribute StudioMode = "Match" to playtest the court.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)

export type Mode = "Hub" | "Match"

local function detect(): Mode
    if RunService:IsStudio() then
        local forced = Workspace:GetAttribute("StudioMode")
        if forced == "Hub" or forced == "Match" then
            return forced
        end
    end
    local matchId = Config.Places.MatchPlaceId
    return if matchId ~= 0 and game.PlaceId == matchId then "Match" else "Hub"
end

return table.freeze({
    Current = detect(),
})
