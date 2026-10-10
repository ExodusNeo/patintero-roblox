--!strict
--[[
    MovementController.luau
    Client movement system handling heavy momentum-based running, sprinting, physical power
    sliding, jumping/landing weight, stamina economy, and rigid line-constraint mechanics for Guards.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local FirstPersonController = require(script.Parent.FirstPersonController)
local SoundController = require(script.Parent.SoundController)
local TouchLayout = require(script.Parent.TouchLayout)

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
local dashUntil = 0
local dashVelocity = Vector3.zero
local targetWalkSpeed = Config.Movement.WalkSpeed
local moveVector = Vector3.zero -- smoothed input actually fed to the Humanoid
local landingSlowUntil = 0
local fallSpeed = 0
local jumpEnabled = true

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

-- Style passive x active Haste x active Slow (SlowMult 0 = frozen). Attributes are set by the server.
local function getSpeedMult(): number
    local style = Styles.Get(player:GetAttribute("Style") :: string?)
    local character = player.Character
    if not character then return style.speedMult end
    local haste = (character:GetAttribute("HasteMult") :: number?) or 1
    local slow = (character:GetAttribute("SlowMult") :: number?) or 1
    return style.speedMult * haste * slow
end

local function getMaxStamina(): number
    return Config.Movement.MaxStamina * Styles.Get(player:GetAttribute("Style") :: string?).staminaMult
end

-- Move direction if moving, otherwise flat camera look.
local function getMoveDirection(humanoid: Humanoid, root: BasePart): Vector3
    if humanoid.MoveDirection.Magnitude > 0.1 then
        return humanoid.MoveDirection.Unit
    end
    local camLook = camera.CFrame.LookVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
    return if flatLook.Magnitude > 0.05 then flatLook.Unit else root.CFrame.LookVector
end

function MovementController.SetStaminaChangedCallback(callback: (current: number, max: number) -> ())
    onStaminaChangedCallback = callback
end

function MovementController.GetStamina(): (number, number)
    return currentStamina, getMaxStamina()
end

local function applySpeed()
    local _, humanoid, _ = getCharacterComponents()
    if not humanoid then return end

    local base: number
    if isSliding then
        base = Config.Movement.SlideInitialSpeed
    elseif currentTeam == "Guards" then
        base = if isSprinting and currentStamina > 0 then Config.Movement.GuardStrafeSpeed + 4 else Config.Movement.GuardStrafeSpeed
    elseif isSprinting and currentStamina > 0 then
        base = Config.Movement.SprintSpeed
    else
        base = Config.Movement.WalkSpeed
    end
    local landing = if os.clock() < landingSlowUntil then Config.Movement.LandingSlowMult else 1
    targetWalkSpeed = base * getSpeedMult() * landing -- the RenderStepped loop ramps WalkSpeed toward this
end

-- Heavy running: ease the input toward its target instead of snapping, so players build up speed,
-- skid to a stop, and lose speed on sharp turns. Roblox's native controls write the raw input into
-- MoveDirection every frame before Input+1 (verified in Studio), so we read it there and override
-- with Move(); our override never feeds back. Humanoid speed scales with the vector's length.
local function stepMomentum(deltaTime: number)
    local _, humanoid, _ = getCharacterComponents()
    if not humanoid or humanoid.Health <= 0 then
        moveVector = Vector3.zero
        return
    end

    local desired = humanoid.MoveDirection -- raw input this frame, world space, camera-relative
    local look = camera.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    forward = if forward.Magnitude > 1e-3 then forward.Unit else -Vector3.zAxis

    -- First person: running forward is fastest; strafing and backpedalling are slower
    if player.CameraMode == Enum.CameraMode.LockFirstPerson and desired.Magnitude > 0.05 then
        local facing = desired.Unit:Dot(forward) -- 1 forward, 0 sideways, -1 backwards
        desired *= if facing >= 0
            then math.lerp(Config.Movement.StrafeMult, 1, facing)
            else math.lerp(Config.Movement.StrafeMult, Config.Movement.BackpedalMult, -facing)
    end

    local rate = if desired.Magnitude >= moveVector.Magnitude then 1 / Config.Movement.AccelTime else 1 / Config.Movement.DecelTime
    if humanoid.FloorMaterial == Enum.Material.Air then
        rate *= Config.Movement.AirControl
    end
    local delta = desired - moveVector
    local step = rate * deltaTime
    moveVector = if delta.Magnitude <= step then desired else moveVector + delta.Unit * step
    humanoid:Move(moveVector, false)
end

-- Lower jumps that cost stamina; hard landings briefly stun your stride.
local function setupCharacter(character: Model)
    moveVector = Vector3.zero
    fallSpeed = 0
    jumpEnabled = true
    local humanoid = character:WaitForChild("Humanoid") :: Humanoid
    humanoid.UseJumpPower = false
    humanoid.JumpHeight = Config.Movement.JumpHeight
    humanoid.StateChanged:Connect(function(_old, new)
        if new == Enum.HumanoidStateType.Jumping then
            currentStamina = math.max(currentStamina - Config.Movement.JumpStaminaCost, 0)
            lastStaminaDrainTime = os.clock()
        elseif new == Enum.HumanoidStateType.Landed then
            if fallSpeed > Config.Movement.HardLandingSpeed then
                landingSlowUntil = os.clock() + Config.Movement.LandingSlowTime
                moveVector *= 0.3
                SoundController.PlaySneakerSqueak()
            end
            fallSpeed = 0
        end
    end)
end

local function triggerSlide()
    local now = os.clock()
    if (now - lastSlideTime) < Config.Movement.SlideCooldown then return end
    if currentStamina < Config.Movement.SlideCost then return end
    if isSliding then return end

    local _, humanoid, root = getCharacterComponents()
    if not humanoid or not root or humanoid.FloorMaterial == Enum.Material.Air then return end

    if getSpeedMult() <= 0 then return end
    slideDirection = getMoveDirection(humanoid, root)

    isSliding = true
    slideStartTime = now
    lastSlideTime = now
    currentStamina = math.clamp(currentStamina - Config.Movement.SlideCost, 0, getMaxStamina())
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

-- Skill: short velocity burst (caster-side prediction; server only checks the cooldown).
function MovementController.Dash(speed: number, duration: number)
    local _, humanoid, root = getCharacterComponents()
    if not humanoid or not root or getSpeedMult() <= 0 then return end
    dashVelocity = getMoveDirection(humanoid, root) * speed
    dashUntil = os.clock() + duration
    FirstPersonController.SetSliding(true)
    task.delay(duration, function()
        if not isSliding then
            FirstPersonController.SetSliding(false)
        end
    end)
end

-- Skill: instant short-range teleport, stopped 2 studs before walls/barriers.
function MovementController.Blink(distance: number)
    local character, humanoid, root = getCharacterComponents()
    if not character or not humanoid or not root or getSpeedMult() <= 0 then return end
    local direction = getMoveDirection(humanoid, root)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local hit = Workspace:Raycast(root.Position, direction * distance, params)
    local travel = if hit then math.max(hit.Distance - 2, 0) else distance
    root.CFrame += direction * travel
end

function MovementController.RestoreStamina(amount: number)
    currentStamina = math.clamp(currentStamina + amount, 0, getMaxStamina())
end

function MovementController.Init()
    RunService:BindToRenderStep("PatinteroMomentum", Enum.RenderPriority.Input.Value + 1, stepMomentum)

    if player.Character then
        task.spawn(setupCharacter, player.Character)
    end
    player.CharacterAdded:Connect(setupCharacter)

    -- Listen to state replication from server
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        currentTeam = state.team
        currentRole = state.guardRole
        applySpeed()
    end)

    -- Sprint (hold) & Slide: keyboard, gamepad, and an auto-created touch button each
    ContextActionService:BindAction("Sprint", function(_, inputState: Enum.UserInputState)
        if inputState == Enum.UserInputState.Begin then
            if currentStamina > 5 then
                isSprinting = true
                FirstPersonController.SetSprinting(true)
                SoundController.PlaySneakerSqueak()
                applySpeed()
            end
        elseif isSprinting then -- End or Cancel
            isSprinting = false
            FirstPersonController.SetSprinting(false)
            applySpeed()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
    ContextActionService:SetTitle("Sprint", "RUN")
    TouchLayout.place("Sprint")

    ContextActionService:BindAction("Slide", function(_, inputState: Enum.UserInputState)
        if inputState == Enum.UserInputState.Begin then
            triggerSlide()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
    ContextActionService:SetTitle("Slide", "SLIDE")
    TouchLayout.place("Slide")

    -- RenderStepped loop: Slide velocity sustain, stamina economy, and guard rail locking
    RunService.RenderStepped:Connect(function(deltaTime: number)
        local _, humanoid, root = getCharacterComponents()
        if not humanoid or not root then return end

        local now = os.clock()
        applySpeed() -- speed modifiers (haste/slow) change at any time
        local frozen = getSpeedMult() <= 0

        -- Speed builds up gradually (sprint ramp) and drops 3x faster; freezes and slides are instant
        if isSliding or targetWalkSpeed <= 0 then
            humanoid.WalkSpeed = targetWalkSpeed
        elseif humanoid.WalkSpeed < targetWalkSpeed then
            humanoid.WalkSpeed = math.min(targetWalkSpeed, humanoid.WalkSpeed + Config.Movement.SprintRampRate * deltaTime)
        else
            humanoid.WalkSpeed = math.max(targetWalkSpeed, humanoid.WalkSpeed - Config.Movement.SprintRampRate * 3 * deltaTime)
        end

        -- Track fall speed for hard landings; no jumping without the stamina for it
        if humanoid.FloorMaterial == Enum.Material.Air then
            fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
        end
        local canJump = currentStamina >= Config.Movement.JumpStaminaCost
        if canJump ~= jumpEnabled then
            jumpEnabled = canJump
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, canJump)
        end

        -- 0. Skill dash burst
        if now < dashUntil and not frozen then
            root.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, root.AssemblyLinearVelocity.Y, dashVelocity.Z)
        end

        -- 1. Active Slide Physics Glide
        if isSliding and not frozen then
            local elapsed = now - slideStartTime
            local alpha = math.clamp(elapsed / Config.Movement.SlideDuration, 0, 1)
            -- Ease-out velocity decay from 42 studs/s down to 24 studs/s
            local currentSlideSpeed = math.lerp(Config.Movement.SlideInitialSpeed, Config.Movement.WalkSpeed + 6, alpha)
            local slideVel = slideDirection * currentSlideSpeed
            root.AssemblyLinearVelocity = Vector3.new(slideVel.X, root.AssemblyLinearVelocity.Y, slideVel.Z)
        end

        -- 2. Stamina Management
        if isSprinting and humanoid.MoveDirection.Magnitude > 0 and not isSliding then
            currentStamina = math.clamp(currentStamina - (Config.Movement.SprintDrainRate * deltaTime), 0, getMaxStamina())
            lastStaminaDrainTime = now
            if currentStamina <= 0 then
                isSprinting = false
                FirstPersonController.SetSprinting(false)
                applySpeed()
            end
        elseif (now - lastStaminaDrainTime) >= Config.Movement.StaminaRegenDelay and currentStamina < getMaxStamina() and not isSliding then
            currentStamina = math.clamp(currentStamina + (Config.Movement.StaminaRegenRate * deltaTime), 0, getMaxStamina())
        end

        local staminaRatio = currentStamina / getMaxStamina()
        SoundController.UpdateStaminaAudio(staminaRatio)

        if onStaminaChangedCallback then
            onStaminaChangedCallback(currentStamina, getMaxStamina())
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
