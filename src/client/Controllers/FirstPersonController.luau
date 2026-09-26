--!strict
--[[
    FirstPersonController.luau
    Manages immersive first-person camera: zoom locking, head bobbing,
    dynamic field-of-view (FOV) transitions, and directional strafe tilt.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FirstPersonController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local BASE_FOV = 75
local SPRINT_FOV = 85
local SLIDE_FOV = 90
local BOB_AMPLITUDE = 0.08
local BOB_FREQUENCY = 14
local TILT_MAX_ANGLE = 2.5 -- degrees

local isSprinting = false
local isSliding = false
local bobTimer = 0

local function lockFirstPerson(character: Model)
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMaxZoomDistance = 0.5
    player.CameraMinZoomDistance = 0.5

    -- Ensure limbs are properly transparent or visible
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Head" or part.Name == "UpperTorso" or part.Name == "Torso") then
            part.LocalTransparencyModifier = 0
        end
    end
end

function FirstPersonController.SetSprinting(sprinting: boolean)
    if isSprinting == sprinting then return end
    isSprinting = sprinting

    local targetFOV = if isSliding then SLIDE_FOV elseif isSprinting then SPRINT_FOV else BASE_FOV
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(camera, tweenInfo, { FieldOfView = targetFOV }):Play()
end

function FirstPersonController.SetSliding(sliding: boolean)
    if isSliding == sliding then return end
    isSliding = sliding

    local targetFOV = if isSliding then SLIDE_FOV elseif isSprinting then SPRINT_FOV else BASE_FOV
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(camera, tweenInfo, { FieldOfView = targetFOV }):Play()
end

function FirstPersonController.Init()
    camera.FieldOfView = BASE_FOV

    if player.Character then
        lockFirstPerson(player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        lockFirstPerson(character)
    end)

    -- RenderStepped loop for head bobbing and camera tilt
    RunService.RenderStepped:Connect(function(deltaTime: number)
        local character = player.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not humanoid or not root or humanoid.Health <= 0 then return end

        local velocity = root.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

        -- 1. Head Bobbing
        local bobOffset = Vector3.zero
        if horizontalSpeed > 1 and humanoid.FloorMaterial ~= Enum.Material.Air then
            local speedMultiplier = math.clamp(horizontalSpeed / 16, 0.8, 1.8)
            bobTimer += deltaTime * BOB_FREQUENCY * speedMultiplier
            local bobX = math.cos(bobTimer * 0.5) * BOB_AMPLITUDE * 0.5
            local bobY = math.sin(bobTimer) * BOB_AMPLITUDE
            bobOffset = Vector3.new(bobX, bobY, 0)
        else
            bobTimer = 0
        end

        -- 2. Directional Strafe Tilt
        local moveDirection = humanoid.MoveDirection
        local tiltAngle = 0
        if moveDirection.Magnitude > 0 then
            local rightDot = moveDirection:Dot(camera.CFrame.RightVector)
            tiltAngle = math.rad(-rightDot * TILT_MAX_ANGLE)
        end

        -- Apply subtle procedural offset to current camera CFrame
        local tiltCFrame = CFrame.Angles(0, 0, tiltAngle)
        local offsetCFrame = CFrame.new(bobOffset)
        camera.CFrame = camera.CFrame * offsetCFrame * tiltCFrame
    end)
end

return FirstPersonController
