--!strict
--[[
    MovementController.luau
    Client movement system handling sprinting, power sliding, stamina economy,
    and rigid line-constraint mechanics for Guards.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local FirstPersonController = require(script.Parent.FirstPersonController)

local MovementController = {}

local player = Players.LocalPlayer
local currentStamina = Config.Movement.MaxStamina
local isSprinting = false
local isSliding = false
local lastStaminaDrainTime = 0
local lastSlideTime = 0

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

    if currentTeam == "Guards" then
        humanoid.WalkSpeed = Config.Movement.GuardStrafeSpeed
    elseif isSliding then
        humanoid.WalkSpeed = Config.Movement.SlideInitialSpeed
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
    if humanoid.MoveDirection.Magnitude <= 0.1 then return end

    isSliding = true
    lastSlideTime = now
    currentStamina = math.clamp(currentStamina - Config.Movement.SlideCost, 0, Config.Movement.MaxStamina)
    lastStaminaDrainTime = now

    FirstPersonController.SetSliding(true)
    applySpeed()

    -- Fire cosmetic slide event to server
    local cosmeticEvent = Remotes.GetUnreliableEvent("CosmeticAction")
    cosmeticEvent:FireServer("Slide", root.Position)

    -- Decelerate slide
    task.delay(Config.Movement.SlideDuration, function()
        if isSliding then
            isSliding = false
            FirstPersonController.SetSliding(false)
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

    -- Input bindings
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.LeftShift then
            if currentTeam == "Passers" and currentStamina > 5 then
                isSprinting = true
                FirstPersonController.SetSprinting(true)
                applySpeed()
            end
        elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl then
            if currentTeam == "Passers" then
                triggerSlide()
            end
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

    -- RenderStepped loop: Stamina economy + Guard Line Constraint
    RunService.RenderStepped:Connect(function(deltaTime: number)
        local _, humanoid, root = getCharacterComponents()
        if not humanoid or not root then return end

        local now = os.clock()

        -- 1. Stamina management
        if isSprinting and humanoid.MoveDirection.Magnitude > 0 then
            currentStamina = math.clamp(currentStamina - (Config.Movement.SprintDrainRate * deltaTime), 0, Config.Movement.MaxStamina)
            lastStaminaDrainTime = now
            if currentStamina <= 0 then
                isSprinting = false
                FirstPersonController.SetSprinting(false)
                applySpeed()
            end
        elseif (now - lastStaminaDrainTime) >= Config.Movement.StaminaRegenDelay and currentStamina < Config.Movement.MaxStamina then
            currentStamina = math.clamp(currentStamina + (Config.Movement.StaminaRegenRate * deltaTime), 0, Config.Movement.MaxStamina)
        end

        if onStaminaChangedCallback then
            onStaminaChangedCallback(currentStamina, Config.Movement.MaxStamina)
        end

        -- 2. Guard Line Constraint (Physical Rail Lock)
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
