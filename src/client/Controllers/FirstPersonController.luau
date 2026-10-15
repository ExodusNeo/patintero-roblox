--!strict
--[[
    FirstPersonController.luau
    Manages immersive first-person camera: zoom locking, head bobbing,
    dynamic field-of-view (FOV) transitions, directional strafe tilt,
    visceral low-crouch camera dip on power slides, and wind (streaks past both sides of the view plus
    rushing air) that builds with running speed. A tagged Passer (Player attribute `Tagged`) watches an
    untagged teammate in third person until they're back in.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.SoundController)
local SkillEffects = require(script.Parent.SkillEffects)
local BodyPose = require(script.Parent.BodyPose)

local FirstPersonController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local BASE_FOV = 75
local SPRINT_FOV = 85
local SLIDE_FOV = 92
local BOB_AMPLITUDE = 0.08
local BOB_FREQUENCY = 14
local TILT_MAX_ANGLE = 2.5 -- degrees
local SLIDE_CAMERA_DIP = -BodyPose.SLIDE_DROP -- studs downward during slide; the body drops the same
local WIND_START_SPEED = 14 -- studs/s: walking makes almost no wind
local WIND_FULL_SPEED = 30 -- full wind (sprint is ~26, a slide more)
local WIND_RATE = 40 -- streaks per second on each side at full wind
local WIND_AHEAD = 16 -- studs in front of the camera where the streaks start
local WIND_SIDE = 4.5 -- studs left/right of the view center

local SPECTATE_ZOOM = Vector2.new(8, 14) -- min, max studs

local isSprinting = false
local spectating: Humanoid? = nil
local isSliding = false
local bobTimer = 0
local currentCameraDip = 0

type Wind = { part: BasePart, emitter: ParticleEmitter, side: number }
local winds: { Wind } = {}

-- Two invisible emitters riding in front of the camera, one per side; the streaks fly back past the view
local function buildWind()
    for _, side in { -1, 1 } do
        local part = Instance.new("Part")
        part.Name = "RunWind"
        part.Size = Vector3.new(2, 5, 1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = SkillEffects.TEX.Streak
        emitter.Rate = 0
        emitter.LockedToPart = true
        emitter.Shape = Enum.ParticleEmitterShape.Box
        emitter.EmissionDirection = Enum.NormalId.Back
        emitter.Speed = NumberRange.new(50, 65)
        emitter.Lifetime = NumberRange.new(0.25, 0.35)
        emitter.Orientation = Enum.ParticleOrientation.VelocityParallel -- the streak sprite runs along the motion
        emitter.Size = NumberSequence.new(0.8, 0.25)
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.LightEmission = 0.5
        emitter.Parent = part
        part.Parent = camera
        table.insert(winds, { part = part, emitter = emitter, side = side })
    end
end

-- level 0..1
local function setWind(level: number)
    for _, wind in winds do
        wind.emitter.Rate = WIND_RATE * level
        wind.part.CFrame = camera.CFrame * CFrame.new(wind.side * WIND_SIDE, -0.5, -WIND_AHEAD)
    end
    SoundController.UpdateRunWind(level)
end

-- Menus free the mouse with a Modal GuiButton (see SpinController).
local function lockFirstPerson()
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMaxZoomDistance = 0.5
    player.CameraMinZoomDistance = 0.5
end

local function spectateTarget(): Humanoid?
    if player:GetAttribute("Tagged") ~= true then return nil end
    for _, other in Players:GetPlayers() do
        if other ~= player and other:GetAttribute("Team") == "Passers" and other:GetAttribute("Tagged") ~= true then
            local humanoid = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                return humanoid
            end
        end
    end
    return nil
end

-- Switches the camera to follow `target` in third person, or back to your own first person
local function spectate(target: Humanoid?)
    spectating = target
    if target then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMaxZoomDistance = SPECTATE_ZOOM.Y
        player.CameraMinZoomDistance = SPECTATE_ZOOM.X
        camera.CameraSubject = target
    else
        local own = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if own then
            camera.CameraSubject = own
        end
        lockFirstPerson()
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
    BodyPose.SetSliding(sliding)

    local targetFOV = if isSliding then SLIDE_FOV elseif isSprinting then SPRINT_FOV else BASE_FOV
    local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(camera, tweenInfo, { FieldOfView = targetFOV }):Play()
end

function FirstPersonController.Init()
    camera.FieldOfView = BASE_FOV

    lockFirstPerson()
    player.CharacterAdded:Connect(lockFirstPerson)
    buildWind()

    -- RenderStepped loop for head bobbing, slide dip, and camera tilt
    RunService.RenderStepped:Connect(function(deltaTime: number)
        local target = spectateTarget()
        if target ~= spectating then
            spectate(target)
        end
        if spectating then
            setWind(0)
            return
        end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not humanoid or not root or humanoid.Health <= 0 then
            setWind(0)
            return
        end

        local velocity = root.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

        -- 1. Head Bobbing
        local bobOffset = Vector3.zero
        if horizontalSpeed > 1 and humanoid.FloorMaterial ~= Enum.Material.Air and not isSliding then
            local speedMultiplier = math.clamp(horizontalSpeed / 16, 0.8, 1.8)
            bobTimer += deltaTime * BOB_FREQUENCY * speedMultiplier
            local bobX = math.cos(bobTimer * 0.5) * BOB_AMPLITUDE * 0.5
            local bobY = math.sin(bobTimer) * BOB_AMPLITUDE
            bobOffset = Vector3.new(bobX, bobY, 0)
        else
            bobTimer = 0
        end

        -- 2. Slide Camera Dip (Crouch low to ground)
        local targetDip = if isSliding then SLIDE_CAMERA_DIP else 0
        currentCameraDip = currentCameraDip + (targetDip - currentCameraDip) * math.clamp(deltaTime * 16, 0, 1)
        local dipOffset = Vector3.new(0, currentCameraDip, 0)

        -- 3. Directional Strafe Tilt
        local moveDirection = humanoid.MoveDirection
        local tiltAngle = 0
        if moveDirection.Magnitude > 0 then
            local rightDot = moveDirection:Dot(camera.CFrame.RightVector)
            tiltAngle = math.rad(-rightDot * TILT_MAX_ANGLE)
        end

        -- Apply procedural offsets to camera CFrame
        local tiltCFrame = CFrame.Angles(0, 0, tiltAngle)
        local offsetCFrame = CFrame.new(bobOffset + dipOffset)
        camera.CFrame = camera.CFrame * offsetCFrame * tiltCFrame

        -- 4. Wind
        setWind(math.clamp((horizontalSpeed - WIND_START_SPEED) / (WIND_FULL_SPEED - WIND_START_SPEED), 0, 1))
    end)
end

return FirstPersonController
