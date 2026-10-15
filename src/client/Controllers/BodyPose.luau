--!strict
--[[
    BodyPose.luau
    Match: poses every character's arms by role, on each client (nothing to replicate). Passers pump their
    arms side to side across the body as they run (scaled by speed); Guards hold them wide, blocking.
    Steps aside while a style animation or an Action animation (the tag swipe) plays.
    Slides drop the body SLIDE_DROP studs (FirstPersonController dips the camera as far), leaning back with one
    leg out: your own from SetSliding, other players' from the relayed "Slide" cosmetic action.
    First person shows your forearms and hands while posed, and your legs while sliding.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local StyleAnimator = require(script.Parent.StyleAnimator)

local BodyPose = {}
BodyPose.SLIDE_DROP = 1.8 -- studs the body (and the first-person camera) drops in a slide

local player = Players.LocalPlayer

-- Joint Transforms are in the parent part's frame: +X rotation swings an arm forward, +Z swings the right
-- arm out (the left arm mirrors with -Z)
-- (legs the same way: +X swings a leg forward, -X bends a knee; +X on Root leans the body back)
local JOINTS = {
    "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow",
    "Root", "Waist", "RightHip", "LeftHip", "RightKnee", "LeftKnee",
}
-- Shown in first person; the upper arms and torso sit right at the camera and would block the view
local ARM_PARTS = { "RightLowerArm", "RightHand", "LeftLowerArm", "LeftHand" }
local LEG_PARTS = { "LowerTorso", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }
local RUN_SPEED = 20 -- studs/s where the runner's pump is at full swing
local PUMP_PER_STUD = 0.6 -- radians of arm cycle per stud run
local BLEND_RATE = 10 -- how fast a pose blends in/out (per second)
local SLIDE_BLEND_RATE = 16 -- same rate as FirstPersonController's camera dip, so body and camera drop together
local SHOW_ABOVE = 0.05 -- pose weight above which your own limbs show in first person

local sliding = false -- your own slide

type State = { joints: { [string]: any }, weight: number, phase: number, slide: number, slideUntil: number }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local rad = math.rad

local function findJoints(character: Model): { [string]: any }
    local joints = {}
    for _, item in character:GetDescendants() do
        if (item:IsA("Motor6D") or item:IsA("AnimationConstraint")) and table.find(JOINTS, item.Name) then
            joints[item.Name] = item
        end
    end
    return joints
end

-- An Action (or higher) track, e.g. the guard's tag swipe, owns the arms while it plays
local function actionPlaying(humanoid: Humanoid): boolean
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in animator:GetPlayingAnimationTracks() do
        local priority = track.Priority -- Core's enum value (1000) sorts above Action, so exclude it
        if priority ~= Enum.AnimationPriority.Core and priority.Value >= Enum.AnimationPriority.Action.Value then
            return true
        end
    end
    return false
end

-- Runner: elbows bent, arms pumping forward/back, each hand swinging in across the chest as it comes forward
local function runnerPose(phase: number): { [string]: CFrame }
    local s = math.sin(phase)
    return {
        RightShoulder = CFrame.Angles(rad(-5 + 35 * s), 0, rad(-6 - 16 * math.max(s, 0))),
        LeftShoulder = CFrame.Angles(rad(-5 - 35 * s), 0, rad(6 + 16 * math.max(-s, 0))),
        RightElbow = CFrame.Angles(rad(60 + 12 * s), 0, 0),
        LeftElbow = CFrame.Angles(rad(60 - 12 * s), 0, 0),
    }
end

-- Guard: arms spread wide and a little forward at shoulder height, forearms bent in, leaning with the strafe
local function guardPose(lean: number, t: number): { [string]: CFrame }
    local breathe = math.sin(t * 2.2) * 3
    return {
        RightShoulder = CFrame.Angles(0, rad(30), rad(82 + breathe + lean * 10)),
        LeftShoulder = CFrame.Angles(0, rad(-30), rad(-82 - breathe + lean * 10)),
        RightElbow = CFrame.Angles(rad(30), 0, 0),
        LeftElbow = CFrame.Angles(rad(30), 0, 0),
    }
end

-- Own slide: body dropped and leaning back, right leg out in front, left leg tucked, arms out for balance
local function slidePose(): { [string]: CFrame }
    return {
        Root = CFrame.new(0, -BodyPose.SLIDE_DROP, 0) * CFrame.Angles(rad(20), 0, 0),
        Waist = CFrame.Angles(rad(-15), 0, 0),
        RightHip = CFrame.Angles(rad(65), 0, 0),
        RightKnee = CFrame.Angles(rad(-10), 0, 0),
        LeftHip = CFrame.Angles(rad(45), 0, rad(-10)),
        LeftKnee = CFrame.Angles(rad(-75), 0, 0),
        RightShoulder = CFrame.Angles(rad(30), 0, rad(40)),
        LeftShoulder = CFrame.Angles(rad(-20), 0, rad(-50)),
        RightElbow = CFrame.Angles(rad(25), 0, 0),
        LeftElbow = CFrame.Angles(rad(15), 0, 0),
    }
end

local function apply(joints: { [string]: any }, pose: { [string]: CFrame }, weight: number)
    for name, value in pose do
        local joint = joints[name]
        if joint then
            joint.Transform = (joint.Transform :: CFrame):Lerp(value, weight)
        end
    end
end

local function step(deltaTime: number)
    local now = os.clock()
    for _, other in Players:GetPlayers() do
        local character = other.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not (character and humanoid and root) then continue end

        local state = states[character]
        if not state or not state.joints.RightShoulder then
            state = { joints = findJoints(character), weight = 0, phase = 0, slide = 0, slideUntil = 0 }
            states[character] = state
        end

        local team = other:GetAttribute("Team")
        local velocity = root.AssemblyLinearVelocity
        local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        local busy = humanoid.Health <= 0 or StyleAnimator.IsPlaying(character) or actionPlaying(humanoid)

        local target = 0
        local pose: { [string]: CFrame }? = nil
        if team == "Passers" then
            state.phase += speed * deltaTime * PUMP_PER_STUD
            target = math.clamp(speed / RUN_SPEED, 0, 1)
            pose = runnerPose(state.phase)
        elseif team == "Guards" then
            target = 1
            pose = guardPose(math.clamp(root.CFrame.RightVector:Dot(velocity) / 26, -1, 1), now)
        end
        if busy then
            target = 0
        end
        state.weight += (target - state.weight) * math.min(1, deltaTime * BLEND_RATE)

        if pose and state.weight > 0.001 then
            apply(state.joints, pose, state.weight)
        end

        local slideOn = if other == player then sliding else now < state.slideUntil
        state.slide += ((if slideOn then 1 else 0) - state.slide) * math.min(1, deltaTime * SLIDE_BLEND_RATE)
        if state.slide > 0.001 then
            apply(state.joints, slidePose(), state.slide)
        end
    end
end

local function show(character: Model, names: { string })
    for _, name in names do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            part.LocalTransparencyModifier = 0
        end
    end
end

-- First person hides your own body; show what is posed (after the camera sets transparency)
local function showOwnLimbs()
    local character = player.Character
    local state = character and states[character]
    if not (character and state) then return end
    if state.weight > SHOW_ABOVE or state.slide > SHOW_ABOVE then
        show(character, ARM_PARTS)
    end
    if state.slide > SHOW_ABOVE then
        show(character, LEG_PARTS)
    end
end

function BodyPose.SetSliding(on: boolean)
    sliding = on
end

function BodyPose.Init()
    RunService.PreSimulation:Connect(step) -- after the Animator, like StyleAnimator
    RunService:BindToRenderStep("PatinteroBodyPose", Enum.RenderPriority.Camera.Value + 1, showOwnLimbs)

    -- Other players' slides (the server adds who slid)
    Remotes.GetEvent("CosmeticAction").OnClientEvent:Connect(function(actionType: string, _position: Vector3, userId: number?)
        local other = if actionType == "Slide" and userId then Players:GetPlayerByUserId(userId) else nil
        local state = other and other.Character and states[other.Character]
        if state then
            state.slideUntil = os.clock() + Config.Movement.SlideDuration
        end
    end)
end

return BodyPose
