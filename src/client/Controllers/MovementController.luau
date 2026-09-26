--!strict
--[[
    MovementController.luau
    Client movement system handling sprinting, physical power sliding, stamina economy,
    sneaker screeches, slide whoosh audio, and rigid line-constraint mechanics for Guards.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local FirstPersonController = require(script.Parent.FirstPersonController)
local SoundController = require(script.Parent.SoundController)

local MovementController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local currentStamina = Config.Movement.MaxStamina
local isSprinting = false
local isSliding = false
local slideStartTime = 0
local slideDirection = Vector3.zero
local lastSlideTime = 0
local lastStaminaDrainTime = 0

local currentRole: Types.GuardRole? = nil
local currentTeam: Types.Team = "Spectators"

local onStaminaChangedCallback: ((current: number, max: number) -> ())? = nil

local function getCharacterComponents(): (Model?, Humanoid?, BasePart?)
    local character = player.Character
    if not character then return nil, nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    return character, humanoid, root
end

function MovementController.SetStaminaChangedCallback(callback: (current: number, max: number) -> ())
    onStaminaChangedCallback = callback
end

function MovementController.GetStamina(): (number, number)
    return currentStamina, Config.Movement.MaxStamina
end

local function applySpeed()
    local _, humanoid, _ = getCharacterComponents()
    if not humanoid then return end

    if isSliding then
        humanoid.WalkSpeed = Config.Movement.SlideInitialSpeed
    elseif currentTeam == "Guards" then
        humanoid.WalkSpeed = if isSprinting and currentStamina > 0 then Config.Movement.GuardStrafeSpeed + 4 else Config.Movement.GuardStrafeSpeed
    elseif isSprinting and currentStamina > 0 then
        humanoid.WalkSpeed = Config.Movement.SprintSpeed
    else
        humanoid.WalkSpeed = Config.Movement.WalkSpeed
    end
end

local function triggerSlide()
    local now = os.clock()
    if (now - lastSlideTime) < Config.Movement.SlideCooldown then return end
    if currentStamina < Config.Movement.SlideCost then return end
    if isSliding then return end

    local _, humanoid, root = getCharacterComponents()
    if not humanoid or not root or humanoid.FloorMaterial == Enum.Material.Air then return end

    -- Determine slide direction: either move direction or camera forward
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude > 0.1 then
        slideDirection = moveDir.Unit
    else
        local camLook = camera.CFrame.LookVector
        local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
        if flatLook.Magnitude > 0.05 then
            slideDirection = flatLook.Unit
        else
            slideDirection = root.CFrame.LookVector
        end
    end

    isSliding = true
    slideStartTime = now
    lastSlideTime = now
    currentStamina = math.clamp(currentStamina - Config.Movement.SlideCost, 0, Config.Movement.MaxStamina)
    lastStaminaDrainTime = now

    FirstPersonController.SetSliding(true)
    SoundController.StartSlideSound()
    applySpeed()

    -- Apply initial physical burst of velocity
    local boostVel = slideDirection * Config.Movement.SlideInitialSpeed
    root.AssemblyLinearVelocity = Vector3.new(boostVel.X, root.AssemblyLinearVelocity.Y, boostVel.Z)

    -- Fire cosmetic slide event for dust VFX
    local cosmeticEvent = Remotes.GetUnreliableEvent("CosmeticAction")
    cosmeticEvent:FireServer("Slide", root.Position)

    -- End slide after duration
    task.delay(Config.Movement.SlideDuration, function()
        if isSliding then
            isSliding = false
            FirstPersonController.SetSliding(false)
            SoundController.StopSlideSound()
            applySpeed()
        end
    end)
end

function MovementController.Init()
    -- Listen to state replication from server
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        currentTeam = state.team
        currentRole = state.guardRole
        applySpeed()
    end)

    -- Input bindings: Sprint (Shift) & Slide (C / Ctrl)
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.LeftShift then
            if currentStamina > 5 then
                isSprinting = true
                FirstPersonController.SetSprinting(true)
                SoundController.PlaySneakerSqueak()
                applySpeed()
            end
        elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
            triggerSlide()
        end
    end)

    UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
        if input.KeyCode == Enum.KeyCode.LeftShift then
            if isSprinting then
                isSprinting = false
                FirstPersonController.SetSprinting(false)
                applySpeed()
            end
        end
    end)

    -- RenderStepped loop: Slide velocity sustain, stamina economy, and guard rail locking
    RunService.RenderStepped:Connect(function(deltaTime: number)
        local _, humanoid, root = getCharacterComponents()
        if not humanoid or not root then return end

        local now = os.clock()

        -- 1. Active Slide Physics Glide
        if isSliding then
            local elapsed = now - slideStartTime
            local alpha = math.clamp(elapsed / Config.Movement.SlideDuration, 0, 1)
            -- Ease-out velocity decay from 42 studs/s down to 24 studs/s
            local currentSlideSpeed = math.lerp(Config.Movement.SlideInitialSpeed, Config.Movement.WalkSpeed + 6, alpha)
            local slideVel = slideDirection * currentSlideSpeed
            root.AssemblyLinearVelocity = Vector3.new(slideVel.X, root.AssemblyLinearVelocity.Y, slideVel.Z)
        end

        -- 2. Stamina Management
        if isSprinting and humanoid.MoveDirection.Magnitude > 0 and not isSliding then
            currentStamina = math.clamp(currentStamina - (Config.Movement.SprintDrainRate * deltaTime), 0, Config.Movement.MaxStamina)
            lastStaminaDrainTime = now
            if currentStamina <= 0 then
                isSprinting = false
                FirstPersonController.SetSprinting(false)
                applySpeed()
            end
        elseif (now - lastStaminaDrainTime) >= Config.Movement.StaminaRegenDelay and currentStamina < Config.Movement.MaxStamina and not isSliding then
            currentStamina = math.clamp(currentStamina + (Config.Movement.StaminaRegenRate * deltaTime), 0, Config.Movement.MaxStamina)
        end

        local staminaRatio = currentStamina / Config.Movement.MaxStamina
        SoundController.UpdateStaminaAudio(staminaRatio)

        if onStaminaChangedCallback then
            onStaminaChangedCallback(currentStamina, Config.Movement.MaxStamina)
        end

        -- 3. Guard Line Constraint (Physical Rail Lock)
        if currentTeam == "Guards" and currentRole then
            local lineDefs = CourtGeometry.GetLineDefinitions()
            local lineDef = lineDefs[currentRole]
            if lineDef then
                local currentPos = root.Position
                local projected = CourtGeometry.ProjectPointOntoSegment(currentPos, lineDef.startPoint, lineDef.endPoint)

                -- Keep Y altitude consistent with ground, snap horizontal X/Z onto line segment
                root.CFrame = CFrame.new(projected.X, currentPos.Y, projected.Z) * (root.CFrame.Rotation)

                -- Cancel velocity perpendicular to the line
                local lineDir = (lineDef.endPoint - lineDef.startPoint).Unit
                local vel = root.AssemblyLinearVelocity
                local parallelSpeed = vel:Dot(lineDir)
                root.AssemblyLinearVelocity = (lineDir * parallelSpeed) + Vector3.new(0, vel.Y, 0)
            end
        end
    end)
end

return MovementController
