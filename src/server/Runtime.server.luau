--!strict
--[[
    Runtime.server.luau
    Authoritative server entrypoint initializing all core systems in dependency order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local CourtService = require(ServerScriptService.Server.Systems.CourtService)
local PlayerStateService = require(ServerScriptService.Server.Systems.PlayerStateService)
local TagService = require(ServerScriptService.Server.Systems.TagService)
local MatchService = require(ServerScriptService.Server.Systems.MatchService)

print("[Server] Initializing Patintero Server Systems...")

Remotes.Init()
CourtService.Init()
PlayerStateService.Init()
TagService.Init()
MatchService.Init()

print("[Server] All Patintero Systems initialized successfully!")
