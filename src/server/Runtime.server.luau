--!strict
--[[
    Runtime.server.luau
    Authoritative server entrypoint. Starts the shared systems, then the hub or the match
    (see GameMode) and removes the other side's map.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local GameMode = require(ReplicatedStorage.Shared.Modules.GameMode)
local TravelService = require(ServerScriptService.Server.Systems.TravelService)
local HubService = require(ServerScriptService.Server.Systems.HubService)
local CourtService = require(ServerScriptService.Server.Systems.CourtService)
local PlayerStateService = require(ServerScriptService.Server.Systems.PlayerStateService)
local DataService = require(ServerScriptService.Server.Systems.DataService)
local StyleService = require(ServerScriptService.Server.Systems.StyleService)
local TagService = require(ServerScriptService.Server.Systems.TagService)
local MatchService = require(ServerScriptService.Server.Systems.MatchService)
local AvatarService = require(ServerScriptService.Server.Systems.AvatarService)
local ProgressionService = require(ServerScriptService.Server.Systems.ProgressionService)
local FunnelService = require(ServerScriptService.Server.Systems.FunnelService)
local TutorialService = require(ServerScriptService.Server.Systems.TutorialService)

print(`[Server] Initializing Patintero Server Systems ({GameMode.Current})...`)

local function destroy(name: string)
    local inst = Workspace:FindFirstChild(name)
    if inst then
        inst:Destroy()
    end
end

Remotes.Init()
DataService.Init()
StyleService.Init()
TravelService.Init()
AvatarService.Init()
ProgressionService.Init()
FunnelService.Init(GameMode.Current ~= "Match")
TutorialService.Init(GameMode.Current ~= "Match")

if GameMode.Current == "Match" then
    destroy("Hub")
    CourtService.Init()
    PlayerStateService.Init()
    TagService.Init()
    MatchService.Init()
else
    destroy("PatinteroCourt")
    destroy("SpawnLocation") -- court home spawn; the hub has its own
    HubService.Init()
end

print("[Server] All Patintero Systems initialized successfully!")
