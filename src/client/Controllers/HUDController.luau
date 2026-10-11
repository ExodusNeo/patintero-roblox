--!strict
--[[
    HUDController.luau
    Client presentation controller managing the full-screen competitive HUD:
    Scoreboard, match phase & countdown timer, role indicator, stamina gauge,
    crosshair, and animated event banners ("TUBIG!", "TAGGED!").
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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
local bannerStroke: UIStroke
local bannerScale: UIScale
local timerScale: UIScale
local hitMarker: Frame
local hitRing: UIStroke
local hitScale: UIScale

local PASSER_COLOR = Color3.fromRGB(100, 220, 255)
local GUARD_COLOR = Color3.fromRGB(255, 120, 80)
local SIDE_COLORS: { [Types.Side]: Color3 } = { Red = Color3.fromRGB(240, 85, 75), Blue = Color3.fromRGB(80, 155, 255) }
local STAMINA_LOW, STAMINA_MID, STAMINA_HIGH = Color3.fromRGB(220, 50, 50), Color3.fromRGB(255, 215, 0), Color3.fromRGB(50, 205, 50)

-- Every HUD block scales with the screen height so it fits phones and stays crisp on big monitors.
local deviceScale = 1
local scaledBlocks: { UIScale } = {}
local bannerToken = 0
local bannerFades: { Tween } = {}

local function autoScale(block: GuiObject): UIScale
    local scale = Instance.new("UIScale")
    scale.Scale = deviceScale
    scale.Parent = block
    table.insert(scaledBlocks, scale)
    return scale
end

local function updateDeviceScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    deviceScale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.3)
    for _, scale in scaledBlocks do
        scale.Scale = deviceScale
    end
end

-- "RED: 5" in the side's color; your own side is underlined so you know which score is yours.
local function sideScore(side: Types.Side, score: number): string
    local text = `<font color="#{SIDE_COLORS[side]:ToHex()}">{string.upper(side)}:</font> {score}`
    return if player:GetAttribute("Side") == side then `<u>{text}</u>` else text
end

local function formatTime(seconds: number): string
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Pops in, holds, fades. A newer banner cancels the older one's fade so it never hides the new text.
local function showBanner(text: string, color: Color3)
    bannerToken += 1
    local token = bannerToken
    for _, fade in bannerFades do
        fade:Cancel()
    end
    table.clear(bannerFades)

    bannerLabel.Text = text
    bannerLabel.TextColor3 = color
    bannerStroke.Color = color
    bannerFrame.Visible = true
    bannerFrame.BackgroundTransparency = 0.25
    bannerLabel.TextTransparency = 0
    bannerStroke.Transparency = 0.2

    bannerScale.Scale = deviceScale * 0.7
    TweenService:Create(bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = deviceScale }):Play()

    task.delay(1.8, function()
        if token ~= bannerToken then return end
        local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        bannerFades = {
            TweenService:Create(bannerFrame, info, { BackgroundTransparency = 1 }),
            TweenService:Create(bannerStroke, info, { Transparency = 1 }),
            TweenService:Create(bannerLabel, info, { TextTransparency = 1 }),
        }
        bannerFades[3].Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed and token == bannerToken then
                bannerFrame.Visible = false
            end
        end)
        for _, fade in bannerFades do
            fade:Play()
        end
    end)
end

-- Red ring that pops around the crosshair when your tag lands.
local function showHitMarker()
    hitMarker.Visible = true
    hitRing.Transparency = 0
    hitScale.Scale = 0.5
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(hitScale, info, { Scale = 1.3 }):Play()
    local fade = TweenService:Create(hitRing, info, { Transparency = 1 })
    fade.Completed:Once(function(state)
        if state == Enum.PlaybackState.Completed then
            hitMarker.Visible = false
        end
    end)
    fade:Play()
end

local function buildUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PatinteroHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    screenGui.Parent = playerGui
    updateDeviceScale()

    -- 1. Top Bar Container
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.AnchorPoint = Vector2.new(0.5, 0)
    topBar.Size = UDim2.new(0, 450, 0, 80)
    topBar.Position = UDim2.new(0.5, 0, 0, 12)
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
    autoScale(topBar)

    local topShade = Instance.new("UIGradient")
    topShade.Rotation = 90
    topShade.Transparency = NumberSequence.new(0, 0.35)
    topShade.Parent = topBar

    -- Match Timer / Phase Label
    timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(1, 0, 0, 30)
    timerLabel.Position = UDim2.new(0, 0, 0, 8)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBlack
    timerLabel.TextSize = 22
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.Text = "WAITING FOR PLAYERS..."
    timerLabel.Parent = topBar
    timerScale = Instance.new("UIScale")
    timerScale.Parent = timerLabel

    -- Score Label
    scoreLabel = Instance.new("TextLabel")
    scoreLabel.Name = "ScoreLabel"
    scoreLabel.Size = UDim2.new(1, 0, 0, 30)
    scoreLabel.Position = UDim2.new(0, 0, 0, 42)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.Font = Enum.Font.GothamBold
    scoreLabel.TextSize = 17
    scoreLabel.RichText = true
    scoreLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    scoreLabel.Text = "RED: 0   |   BLUE: 0"
    scoreLabel.Parent = topBar

    -- Role Badge
    local roleBadge = Instance.new("Frame")
    roleBadge.Name = "RoleBadge"
    roleBadge.AnchorPoint = Vector2.new(0.5, 0)
    roleBadge.Size = UDim2.new(0, 360, 0, 32)
    roleBadge.Position = UDim2.new(0.5, 0, 1, 8) -- hangs under the top bar and scales with it
    roleBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    roleBadge.BackgroundTransparency = 0.3
    roleBadge.BorderSizePixel = 0
    roleBadge.Parent = topBar

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

    hitMarker = Instance.new("Frame")
    hitMarker.Name = "HitMarker"
    hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    hitMarker.Position = UDim2.fromScale(0.5, 0.5)
    hitMarker.Size = UDim2.fromOffset(28, 28)
    hitMarker.BackgroundTransparency = 1
    hitMarker.Visible = false
    hitMarker.Parent = screenGui
    local hitCorner = Instance.new("UICorner")
    hitCorner.CornerRadius = UDim.new(1, 0)
    hitCorner.Parent = hitMarker
    hitRing = Instance.new("UIStroke")
    hitRing.Color = Color3.fromRGB(255, 70, 70)
    hitRing.Thickness = 3
    hitRing.Parent = hitMarker
    hitScale = Instance.new("UIScale")
    hitScale.Parent = hitMarker

    -- 3. Stamina Gauge
    local staminaContainer = Instance.new("Frame")
    staminaContainer.Name = "StaminaContainer"
    staminaContainer.AnchorPoint = Vector2.new(0.5, 1)
    staminaContainer.Size = UDim2.new(0, 240, 0, 14)
    staminaContainer.Position = UDim2.new(0.5, 0, 1, -41)
    staminaContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    staminaContainer.BorderSizePixel = 0
    staminaContainer.Parent = screenGui

    local stamCorner = Instance.new("UICorner")
    stamCorner.CornerRadius = UDim.new(0, 4)
    stamCorner.Parent = staminaContainer
    autoScale(staminaContainer)
    local stamStroke = Instance.new("UIStroke")
    stamStroke.Color = Color3.fromRGB(10, 10, 12)
    stamStroke.Thickness = 1.5
    stamStroke.Parent = staminaContainer

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
    bannerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    bannerFrame.Size = UDim2.new(0, 420, 0, 90)
    bannerFrame.Position = UDim2.fromScale(0.5, 0.35)
    bannerFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bannerFrame.BackgroundTransparency = 1
    bannerFrame.BorderSizePixel = 0
    bannerFrame.Visible = false
    bannerFrame.Parent = screenGui

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 12)
    bCorner.Parent = bannerFrame
    bannerStroke = Instance.new("UIStroke")
    bannerStroke.Thickness = 2
    bannerStroke.Parent = bannerFrame
    bannerScale = autoScale(bannerFrame)

    bannerLabel = Instance.new("TextLabel")
    bannerLabel.Name = "BannerLabel"
    bannerLabel.Size = UDim2.new(1, 0, 1, 0)
    bannerLabel.BackgroundTransparency = 1
    bannerLabel.Font = Enum.Font.GothamBlack
    bannerLabel.TextSize = 32
    bannerLabel.TextWrapped = true
    bannerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bannerLabel.Text = ""
    bannerLabel.Parent = bannerFrame
end

function HUDController.Init()
    buildUI()
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateDeviceScale)
    end

    -- Hook Stamina Updates
    MovementController.SetStaminaChangedCallback(function(current: number, max: number)
        local ratio = math.clamp(current / max, 0, 1)
        staminaFill.Size = UDim2.new(ratio, 0, 1, 0)
        -- Smooth green -> yellow -> red as stamina drains
        staminaFill.BackgroundColor3 = if ratio > 0.5
            then STAMINA_MID:Lerp(STAMINA_HIGH, (ratio - 0.5) * 2)
            else STAMINA_LOW:Lerp(STAMINA_MID, ratio * 2)
    end)

    -- Match State Updates
    local matchStateEvent = Remotes.GetEvent("MatchStateUpdated")
    local lastPulse = -1
    matchStateEvent.OnClientEvent:Connect(function(state: Types.MatchState)
        scoreLabel.Text = `{sideScore("Red", state.redScore)}   |   {sideScore("Blue", state.blueScore)}`
        timerLabel.TextColor3 = Color3.new(1, 1, 1)

        if state.phase == "Lobby" then
            timerLabel.Text = "LOBBY - WAITING FOR PLAYERS..."
        elseif state.phase == "Countdown" then
            timerLabel.Text = `ROUND STARTING IN: {state.timeRemaining}s`
        elseif state.phase == "RoundActive" then
            timerLabel.Text = `ROUND {state.roundNumber}  |  {formatTime(state.timeRemaining)}`
            -- Last 10 seconds: the clock turns red and pulses each second
            if state.timeRemaining <= 10 then
                timerLabel.TextColor3 = Color3.fromRGB(255, 90, 80)
                if state.timeRemaining ~= lastPulse then
                    lastPulse = state.timeRemaining
                    timerScale.Scale = 1.2
                    TweenService:Create(timerScale, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
                end
            end
        elseif state.phase == "RoundEnded" then
            timerLabel.Text = "ROUND ENDED - SWAPPING SIDES!"
        elseif state.phase == "MatchOver" then
            timerLabel.Text = "MATCH OVER!"
            local winner: Types.Side? = if state.redScore > state.blueScore then "Red" elseif state.blueScore > state.redScore then "Blue" else nil
            if winner then
                showBanner(`{string.upper(winner)} WINS!`, SIDE_COLORS[winner])
            else
                showBanner("MATCH DRAW!", Color3.fromRGB(255, 215, 0))
            end
        end
    end)

    -- Player State Updates
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        if state.team == "Passers" then
            roleBadgeLabel.Text = if state.hasReachedEndZone then "ROLE: RUNNER - RETURN TO HOME BASE!" else "ROLE: RUNNER - REACH THE SAFEHOUSE!"
            roleBadgeLabel.TextColor3 = PASSER_COLOR
        elseif state.team == "Guards" then
            local roleName = if state.guardRole then state.guardRole else "Guard"
            roleBadgeLabel.Text = `ROLE: GUARD ({roleName}) - DEFEND YOUR LINE!`
            roleBadgeLabel.TextColor3 = GUARD_COLOR
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

    Remotes.GetEvent("TagConfirmed").OnClientEvent:Connect(function(taggerUserId: number)
        if taggerUserId == player.UserId then
            showHitMarker()
        end
    end)
end

return HUDController
