--!strict
--[[
    Runtime.client.luau
    Client entrypoint initializing all presentation controllers in sequence.
]]

local Players = game:GetService("Players")

local HUDController = require(script.Parent.Controllers.HUDController)
local CourtVFXController = require(script.Parent.Controllers.CourtVFXController)
local FirstPersonController = require(script.Parent.Controllers.FirstPersonController)
local MovementController = require(script.Parent.Controllers.MovementController)
local TagController = require(script.Parent.Controllers.TagController)

print(`[Client] Initializing Patintero Client Controllers for {Players.LocalPlayer.Name}...`)

HUDController.Init()
CourtVFXController.Init()
FirstPersonController.Init()
MovementController.Init()
TagController.Init()

print("[Client] All Patintero Controllers initialized successfully!")
