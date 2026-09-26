--!strict
--[[
    TagController.luau
    Client tagging controller for Guards.
    Handles tag inputs, client-side targeting, reach prediction, arm swipe VFX,
    audio whoosh feedback, and hit response.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local SoundController = require(script.Parent.SoundController)

local TagController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local isGuard = false
local lastTagTime = 0

local function findTaggablePasser(): Player?
    local character = player.Character
    if not character then return nil end

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return nil end

    local bestPlayer: Player? = nil
    local bestDistance = Config.Tagging.BaseReachDistance

    -- Check all other players in the game
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer == player then continue end

        local otherChar = otherPlayer.Character
        local otherRoot = if otherChar then otherChar:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if not otherRoot then continue end

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

local function playSwingEffect()
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

function TagController.Init()
    -- Listen to player role updates
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        isGuard = (state.team == "Guards")
    end)

    -- Tag input: Left click or F key
    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
            triggerTagAttempt()
        end
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
