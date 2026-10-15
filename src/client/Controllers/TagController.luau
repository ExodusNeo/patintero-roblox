--!strict
--[[
    TagController.luau
    Client tagging controller for Guards.
    Handles tag inputs, client-side targeting, reach prediction, arm swipe VFX,
    audio whoosh feedback, and hit response.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local SoundController = require(script.Parent.SoundController)
local TouchLayout = require(script.Parent.TouchLayout)

local TagController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local isGuard = false
local lastRole: string? = nil
local lastTagTime = 0
local slashTrack: AnimationTrack? = nil -- loaded once per character

local SWING_ARM = { "RightUpperArm", "RightLowerArm", "RightHand" }

local function findTaggablePasser(): Player?
    local character = player.Character
    if not character then return nil end

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return nil end

    local bestPlayer: Player? = nil
    local style = Styles.Get(player:GetAttribute("Style") :: string?)
    local activeReach = (character:GetAttribute("ReachBonus") :: number?) or 0
    local bestDistance = Config.Tagging.BaseReachDistance + style.reachBonus + activeReach

    -- Check all other players in the game
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer == player or otherPlayer:GetAttribute("Team") ~= "Passers" then continue end

        local otherChar = otherPlayer.Character
        local otherRoot = if otherChar then otherChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if not otherRoot or (otherChar :: Model):GetAttribute("TagImmune") then continue end

        local toTarget = otherRoot.Position - root.Position
        local distance = toTarget.Magnitude

        if distance <= bestDistance then
            -- Verify target is in front of the camera (within ~120 degree cone)
            local forward = camera.CFrame.LookVector
            local directionToTarget = toTarget.Unit
            if forward:Dot(directionToTarget) > 0.3 then
                bestDistance = distance
                bestPlayer = otherPlayer
            end
        end
    end

    return bestPlayer
end

-- Swipe with the Animate script's sword-slash animation. Played on our own character, so it replicates:
-- everyone sees the guard swing.
local function playSwingAnimation()
    local track = slashTrack
    if not track then
        local character = player.Character
        local animate = character and character:FindFirstChild("Animate")
        local holder = animate and animate:FindFirstChild("toolslash")
        local animation = holder and holder:FindFirstChildOfClass("Animation")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if not (animation and animator) then return end
        local loaded = animator:LoadAnimation(animation)
        loaded.Priority = Enum.AnimationPriority.Action
        slashTrack = loaded
        track = loaded
    end
    track:Play(0.05, 1, 1.6)
end

-- First person hides your own body; show the swinging arm while the swipe plays.
local function showSwingArm()
    local track = slashTrack
    local character = player.Character
    if not (track and track.IsPlaying and character) then return end
    for _, name in SWING_ARM do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            part.LocalTransparencyModifier = 0
        end
    end
end

local function playSwingEffect()
    playSwingAnimation()

    -- Arm whoosh sound
    SoundController.PlaySFX("SlideWhoosh", Vector2.new(1.35, 1.55), 0.6)

    -- Camera punch effect
    local originalCFrame = camera.CFrame
    local punchCFrame = originalCFrame * CFrame.Angles(math.rad(-3), 0, 0)
    local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
    TweenService:Create(camera, tweenInfo, { CFrame = punchCFrame }):Play()
end

local function triggerTagAttempt()
    if not isGuard then return end

    local now = os.clock()
    if (now - lastTagTime) < Config.Tagging.TagCooldown then return end
    lastTagTime = now

    playSwingEffect()

    local target = findTaggablePasser()
    if target then
        local tagAttemptRemote = Remotes.GetEvent("TagAttempt")
        tagAttemptRemote:FireServer(target.UserId)
    end
end

-- Guard-only controls (with touch buttons): Tag and Line Hop. Unbound for Passers so they
-- don't see buttons they can't use.
local function setGuardControls(enabled: boolean)
    if not enabled then
        ContextActionService:UnbindAction("Tag")
        ContextActionService:UnbindAction("SwitchLine")
        return
    end

    ContextActionService:BindAction("Tag", function(_, inputState: Enum.UserInputState)
        if inputState == Enum.UserInputState.Begin then
            triggerTagAttempt()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
    ContextActionService:SetTitle("Tag", "TAG")
    TouchLayout.place("Tag")

    ContextActionService:BindAction("SwitchLine", function(_, inputState: Enum.UserInputState)
        if inputState == Enum.UserInputState.Begin then
            Remotes.GetEvent("SwitchLine"):FireServer()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonR1)
    ContextActionService:SetTitle("SwitchLine", "HOP")
    TouchLayout.place("SwitchLine")
end

function TagController.Init()
    player.CharacterAdded:Connect(function()
        slashTrack = nil
    end)
    RunService:BindToRenderStep("PatinteroSwingArm", Enum.RenderPriority.Camera.Value + 1, showSwingArm)

    -- Listen to player role updates
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        local nowGuard = state.team == "Guards"
        if nowGuard ~= isGuard then
            isGuard = nowGuard
            setGuardControls(isGuard)
        end
        -- Line hop landed (same guard, new line): whoosh
        local role = if nowGuard then state.guardRole else nil
        if role and lastRole and role ~= lastRole then
            SoundController.PlaySFX("DashWhoosh", Vector2.new(1.05, 1.2), 0.7)
        end
        lastRole = role
    end)

    -- Listen to confirmed tags from server
    local tagConfirmedEvent = Remotes.GetEvent("TagConfirmed")
    tagConfirmedEvent.OnClientEvent:Connect(function(taggerUserId: number, targetUserId: number, hitPosition: Vector3)
        -- Camera shake for victim
        if targetUserId == player.UserId then
            local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 2, true)
            local shakeCFrame = camera.CFrame * CFrame.Angles(0, math.rad(5), math.rad(-5))
            TweenService:Create(camera, tweenInfo, { CFrame = shakeCFrame }):Play()
        end
    end)
end

return TagController
