--!strict
--[[
    HUDController.luau
    Client presentation controller managing the full-screen competitive HUD:
    Scoreboard, match phase & countdown timer, role indicator, stamina gauge,
    crosshair, and animated event banners ("TUBIG!", "TAGGED!").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local MovementController = require(script.Parent.MovementController)

local HUDController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local timerLabel: TextLabel
local scoreLabel: TextLabel
local roleBadgeLabel: TextLabel
local staminaFill: Frame
local bannerLabel: TextLabel
local bannerFrame: Frame

local function formatTime(seconds: number): string
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

local function showBanner(text: string, color: Color3)
    bannerLabel.Text = text
    bannerLabel.TextColor3 = color
    bannerFrame.Visible = true
    bannerFrame.BackgroundTransparency = 0.3
    bannerLabel.TextTransparency = 0

    bannerFrame.Size = UDim2.new(0, 380, 0, 80)
    bannerFrame:TweenSize(
        UDim2.new(0, 420, 0, 90),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Back,
        0.3,
        true,
        function()
            task.delay(1.5, function()
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local fadeTween = TweenService:Create(bannerFrame, tweenInfo, { BackgroundTransparency = 1 })
                local textFade = TweenService:Create(bannerLabel, tweenInfo, { TextTransparency = 1 })
                fadeTween:Play()
                textFade:Play()
                textFade.Completed:Connect(function()
                    bannerFrame.Visible = false
                end)
            end)
        end
    )
end

local function buildUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PatinteroHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- 1. Top Bar Container
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(0, 450, 0, 80)
    topBar.Position = UDim2.new(0.5, -225, 0, 15)
    topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    topBar.BackgroundTransparency = 0.25
    topBar.BorderSizePixel = 0
    topBar.Parent = screenGui

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 8)
    topCorner.Parent = topBar

    local topStroke = Instance.new("UIStroke")
    topStroke.Color = Color3.fromRGB(60, 60, 70)
    topStroke.Thickness = 1.5
    topStroke.Parent = topBar

    -- Match Timer / Phase Label
    timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(1, 0, 0, 30)
    timerLabel.Position = UDim2.new(0, 0, 0, 8)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.Text = "WAITING FOR PLAYERS..."
    timerLabel.Parent = topBar

    -- Score Label
    scoreLabel = Instance.new("TextLabel")
    scoreLabel.Name = "ScoreLabel"
    scoreLabel.Size = UDim2.new(1, 0, 0, 30)
    scoreLabel.Position = UDim2.new(0, 0, 0, 42)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.Font = Enum.Font.GothamMedium
    scoreLabel.TextSize = 16
    scoreLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    scoreLabel.Text = "PASSERS: 0   |   GUARDS: 0"
    scoreLabel.Parent = topBar

    -- Role Badge
    local roleBadge = Instance.new("Frame")
    roleBadge.Name = "RoleBadge"
    roleBadge.Size = UDim2.new(0, 360, 0, 32)
    roleBadge.Position = UDim2.new(0.5, -180, 0, 105)
    roleBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    roleBadge.BackgroundTransparency = 0.3
    roleBadge.BorderSizePixel = 0
    roleBadge.Parent = screenGui

    local roleCorner = Instance.new("UICorner")
    roleCorner.CornerRadius = UDim.new(0, 6)
    roleCorner.Parent = roleBadge

    roleBadgeLabel = Instance.new("TextLabel")
    roleBadgeLabel.Name = "RoleBadgeLabel"
    roleBadgeLabel.Size = UDim2.new(1, 0, 1, 0)
    roleBadgeLabel.BackgroundTransparency = 1
    roleBadgeLabel.Font = Enum.Font.GothamBold
    roleBadgeLabel.TextSize = 14
    roleBadgeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    roleBadgeLabel.Text = "ROLE: SPECTATOR"
    roleBadgeLabel.Parent = roleBadge

    -- 2. Minimalist Center Crosshair
    local crosshair = Instance.new("Frame")
    crosshair.Name = "Crosshair"
    crosshair.Size = UDim2.new(0, 6, 0, 6)
    crosshair.Position = UDim2.new(0.5, -3, 0.5, -3)
    crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    crosshair.BackgroundTransparency = 0.4
    crosshair.BorderSizePixel = 0
    crosshair.Parent = screenGui

    local crossCorner = Instance.new("UICorner")
    crossCorner.CornerRadius = UDim.new(1, 0)
    crossCorner.Parent = crosshair

    -- 3. Stamina Gauge
    local staminaContainer = Instance.new("Frame")
    staminaContainer.Name = "StaminaContainer"
    staminaContainer.Size = UDim2.new(0, 240, 0, 14)
    staminaContainer.Position = UDim2.new(0.5, -120, 1, -55)
    staminaContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    staminaContainer.BorderSizePixel = 0
    staminaContainer.Parent = screenGui

    local stamCorner = Instance.new("UICorner")
    stamCorner.CornerRadius = UDim.new(0, 4)
    stamCorner.Parent = staminaContainer

    staminaFill = Instance.new("Frame")
    staminaFill.Name = "StaminaFill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaContainer

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = staminaFill

    -- 4. Event Announcement Banner
    bannerFrame = Instance.new("Frame")
    bannerFrame.Name = "BannerFrame"
    bannerFrame.Size = UDim2.new(0, 400, 0, 80)
    bannerFrame.Position = UDim2.new(0.5, -200, 0.35, -40)
    bannerFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bannerFrame.BackgroundTransparency = 1
    bannerFrame.BorderSizePixel = 0
    bannerFrame.Visible = false
    bannerFrame.Parent = screenGui

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 12)
    bCorner.Parent = bannerFrame

    bannerLabel = Instance.new("TextLabel")
    bannerLabel.Name = "BannerLabel"
    bannerLabel.Size = UDim2.new(1, 0, 1, 0)
    bannerLabel.BackgroundTransparency = 1
    bannerLabel.Font = Enum.Font.GothamBlack
    bannerLabel.TextSize = 32
    bannerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bannerLabel.Text = ""
    bannerLabel.Parent = bannerFrame
end

function HUDController.Init()
    buildUI()

    -- Hook Stamina Updates
    MovementController.SetStaminaChangedCallback(function(current: number, max: number)
        local ratio = math.clamp(current / max, 0, 1)
        staminaFill.Size = UDim2.new(ratio, 0, 1, 0)

        if ratio > 0.5 then
            staminaFill.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
        elseif ratio > 0.25 then
            staminaFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        else
            staminaFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        end
    end)

    -- Match State Updates
    local matchStateEvent = Remotes.GetEvent("MatchStateUpdated")
    matchStateEvent.OnClientEvent:Connect(function(state: Types.MatchState)
        scoreLabel.Text = `PASSERS: {state.passerScore}   |   GUARDS: {state.guardScore}`

        if state.phase == "Lobby" then
            timerLabel.Text = "LOBBY - WAITING FOR PLAYERS..."
        elseif state.phase == "Countdown" then
            timerLabel.Text = `ROUND STARTING IN: {state.timeRemaining}s`
        elseif state.phase == "RoundActive" then
            timerLabel.Text = `ROUND {state.roundNumber}  |  {formatTime(state.timeRemaining)}`
        elseif state.phase == "RoundEnded" then
            timerLabel.Text = "ROUND ENDED - SWAPPING SIDES!"
        elseif state.phase == "MatchOver" then
            timerLabel.Text = "MATCH OVER!"
            local winText = if state.passerScore > state.guardScore then "PASSERS WIN!" elseif state.guardScore > state.passerScore then "GUARDS WIN!" else "MATCH DRAW!"
            showBanner(winText, Color3.fromRGB(255, 215, 0))
        end
    end)

    -- Player State Updates
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        if state.team == "Passers" then
            roleBadgeLabel.Text = if state.hasReachedEndZone then "ROLE: RUNNER - RETURN TO HOME BASE!" else "ROLE: RUNNER - REACH THE SAFEHOUSE!"
            roleBadgeLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
        elseif state.team == "Guards" then
            local roleName = if state.guardRole then state.guardRole else "Guard"
            roleBadgeLabel.Text = `ROLE: GUARD ({roleName}) - DEFEND YOUR LINE!`
            roleBadgeLabel.TextColor3 = Color3.fromRGB(255, 120, 80)
        else
            roleBadgeLabel.Text = "ROLE: SPECTATOR"
            roleBadgeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end

        if state.isTagged then
            showBanner("YOU WERE TAGGED!", Color3.fromRGB(255, 60, 60))
        end
    end)

    -- Checkpoint Event
    local checkpointEvent = Remotes.GetEvent("ZoneCheckpointReached")
    checkpointEvent.OnClientEvent:Connect(function(targetUserId: number, zoneName: string, _score: number)
        if targetUserId == player.UserId then
            showBanner(`{zoneName} REACHED! (+1)`, Color3.fromRGB(100, 255, 100))
        end
    end)

    -- Tubig Scored Event!
    local tubigEvent = Remotes.GetEvent("TubigScored")
    tubigEvent.OnClientEvent:Connect(function(_targetUserId: number, playerName: string, _score: number)
        showBanner(`TUBIG! {playerName} SCORED! (+5)`, Color3.fromRGB(255, 215, 0))
    end)
end

return HUDController
