--!strict
--[[
    Runtime.client.luau
    Client entrypoint. Hub: third-person plaza with the style/spin menu.
    Match: first-person court with HUD, tagging and court VFX. Skills work in both.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameMode = require(ReplicatedStorage.Shared.Modules.GameMode)

local SoundController = require(script.Parent.Controllers.SoundController)
local HUDController = require(script.Parent.Controllers.HUDController)
local CourtVFXController = require(script.Parent.Controllers.CourtVFXController)
local FirstPersonController = require(script.Parent.Controllers.FirstPersonController)
local MovementController = require(script.Parent.Controllers.MovementController)
local TagController = require(script.Parent.Controllers.TagController)
local StyleController = require(script.Parent.Controllers.StyleController)
local SpinController = require(script.Parent.Controllers.SpinController)

print(`[Client] Initializing Patintero Client Controllers ({GameMode.Current}) for {Players.LocalPlayer.Name}...`)

SoundController.Init()
MovementController.Init()
StyleController.Init()

if GameMode.Current == "Match" then
    HUDController.Init()
    CourtVFXController.Init()
    FirstPersonController.Init()
    TagController.Init()
else
    SpinController.Init()
end

print("[Client] All Patintero Controllers initialized successfully!")
