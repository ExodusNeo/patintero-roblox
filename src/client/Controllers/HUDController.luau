--!strict
--[[
    HUDController.luau
    Match HUD in the "Kanto Night" style (UIKit): a torn scoreboard patch with the Red/Blue scores over
    chalk team marks (an amber scribble under your side), the clock and round ticks, the role line,
    crosshair + hit marker, the chalk stamina stroke, and painted callouts for events
    ("TUBIG!", zones, tags, the winner). Layout follows the 1366x768 mockup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local MovementController = require(script.Parent.MovementController)
local UIKit = require(script.Parent.UIKit)

local C, F, M, A = UIKit.Color, UIKit.Font, UIKit.Motion, UIKit.Art
local make, text, art = UIKit.make, UIKit.text, UIKit.art

local HUDController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local PASSER_COLOR = Color3.fromRGB(79, 184, 240)
local GUARD_COLOR = Color3.fromRGB(240, 122, 58)
local SIDE_COLORS: { [Types.Side]: Color3 } = { Red = Color3.fromRGB(210, 69, 63), Blue = Color3.fromRGB(61, 123, 224) }
local ROUNDS = 2 -- MatchService plays two rounds
local STAMINA_WIDTH = 243
local CALLOUT_SIZE = UDim2.fromOffset(610, 112)

type ScoreBlock = { number: TextLabel, mine: ImageLabel }

local clockLabel: TextLabel
local ticks: { ImageLabel } = {}
local scoreBlocks: { [Types.Side]: ScoreBlock } = {}
local roleName: TextLabel
local roleHint: TextLabel
local staminaClip: Frame
local staminaFill: ImageLabel
local hitMarker: Frame
local hitRing: UIStroke
local hitScale: UIScale
local callout: CanvasGroup
local calloutClip: Frame
local calloutPaint: ImageLabel
local calloutTitle: TextLabel
local calloutSub: TextLabel

local calloutToken = 0
local calloutFade: Tween? = nil

local function formatTime(seconds: number): string
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Painted callout: the plate brushes on left to right, the word slams in, holds, then fades.
-- Light paint gets ink lettering, dark paint chalk. A newer callout takes over cleanly.
local function showCallout(title: string, sub: string?, paint: Color3, big: boolean?)
    calloutToken += 1
    local token = calloutToken
    if calloutFade then
        calloutFade:Cancel()
        calloutFade = nil
    end

    local light = paint.R * 0.299 + paint.G * 0.587 + paint.B * 0.114 > 0.5
    calloutPaint.ImageColor3 = paint
    calloutTitle.TextColor3 = if light then C.Ink else C.Chalk
    calloutTitle.Text = string.upper(title) -- zone and side names arrive in any case
    calloutSub.Text = sub or ""
    callout.Visible = true
    callout.GroupTransparency = 0
    UIKit.wipe(calloutClip, CALLOUT_SIZE, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
    UIKit.pop(calloutTitle, 1.3)
    if big then
        UIKit.shake(callout, 5)
    end

    task.delay(1.9, function()
        if token ~= calloutToken then return end
        local fade = TweenService:Create(callout, M.Slide, { GroupTransparency = 1 })
        fade.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed and token == calloutToken then
                callout.Visible = false
            end
        end)
        calloutFade = fade
        fade:Play()
    end)
end

-- Red ring that snaps around the crosshair when your tag lands.
local function showHitMarker()
    hitMarker.Visible = true
    hitRing.Transparency = 0
    hitScale.Scale = 0.5
    local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(hitScale, info, { Scale = 1.25 }):Play()
    local fade = TweenService:Create(hitRing, info, { Transparency = 1 })
    fade.Completed:Once(function(state)
        if state == Enum.PlaybackState.Completed then
            hitMarker.Visible = false
        end
    end)
    fade:Play()
end

-- Score on the patch with its team's chalk mark below; `x` is the column center on the patch
local function makeScore(board: Frame, side: Types.Side, x: number): ScoreBlock
    local number = text({
        Name = `{side}Score`,
        Text = "0",
        FontFace = F.Display,
        TextSize = 50,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(x, 2),
        Size = UDim2.fromOffset(80, 62),
        ZIndex = 2,
    }, board)
    art(A.TeamMark, { ImageColor3 = SIDE_COLORS[side], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 59), Size = UDim2.fromOffset(73, 18), ZIndex = 2 }, board)
    local mine = art(A.YourSide, { ImageColor3 = C.Sodium, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 69), Size = UDim2.fromOffset(68, 13), ZIndex = 3, Visible = false }, board)
    return { number = number, mine = mine }
end

-- Dark gradients behind the top and bottom HUD so it reads over a bright court
local function buildScrims()
    local gui: ScreenGui = make("ScreenGui", { Name = "HUDScrim", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = -1 }, nil)
    for _, spec in { { y = 0, h = 0.26, from = 0.4, to = 1 }, { y = 1, h = 0.22, from = 1, to = 0.45 } } do
        local scrim: Frame = make("Frame", {
            AnchorPoint = Vector2.new(0, spec.y),
            Position = UDim2.fromScale(0, spec.y),
            Size = UDim2.fromScale(1, spec.h),
            BackgroundColor3 = C.Ink,
            BorderSizePixel = 0,
        }, gui)
        make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(spec.from, spec.to) }, scrim)
    end
    gui.Parent = playerGui
end

local function buildUI()
    buildScrims()
    local gui: ScreenGui = make("ScreenGui", {
        Name = "PatinteroHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    }, nil)

    -- Scoreboard patch: Red | clock + round ticks | Blue, the role line hanging below it
    local board: Frame = make("Frame", {
        Name = "Scoreboard",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 9),
        Size = UDim2.fromOffset(434, 86),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(board)
    art(A.Patch, { ImageColor3 = C.Patch, ImageTransparency = 0.18 }, board)

    scoreBlocks.Red = makeScore(board, "Red", 74)
    scoreBlocks.Blue = makeScore(board, "Blue", 360)

    clockLabel = text({
        Name = "Clock",
        Text = "WAITING",
        FontFace = F.Number,
        TextScaled = true,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(217, 9),
        Size = UDim2.fromOffset(180, 50),
        ZIndex = 2,
    }, board)
    make("UITextSizeConstraint", { MaxTextSize = math.round(40 * UIKit.EM) }, clockLabel)
    for i = 1, ROUNDS do
        ticks[i] = art(A.Tick, { Position = UDim2.fromOffset(217 - ROUNDS * 12 + (i - 1) * 24 - 2, 58), Size = UDim2.fromOffset(28, 14), ImageColor3 = C.Chalk, ZIndex = 2 }, board)
    end

    local role: Frame = make("Frame", {
        Name = "Role",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 5),
        Size = UDim2.fromOffset(0, 27),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
    }, board)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, role)
    roleName = text({ LayoutOrder = 1, Text = "Spectating", FontFace = F.Bold, TextSize = 18, TextColor3 = C.Dim, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, role)
    roleHint = text({ LayoutOrder = 2, Text = "", FontFace = F.Body, TextSize = 18, TextTransparency = 0.1, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, role)
    -- Faint ink outline: the line sits below the scrim and has to read against bright sky
    UIKit.stroke(roleName, C.Ink, 1, 0.5)
    UIKit.stroke(roleHint, C.Ink, 1, 0.5)

    -- Crosshair dot + hit marker
    local crosshair: Frame = make("Frame", {
        Name = "Crosshair",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = C.Chalk,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, crosshair)
    hitMarker = make("Frame", {
        Name = "HitMarker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, hitMarker)
    hitRing = UIKit.stroke(hitMarker, C.Signal, 2.5)
    hitScale = make("UIScale", {}, hitMarker)

    -- Stamina: a faint chalk stroke, drawn over in bright chalk up to the current amount
    local stamina: Frame = make("Frame", {
        Name = "Stamina",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -33),
        Size = UDim2.fromOffset(STAMINA_WIDTH, 13),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(stamina)
    art(A.Stroke, { ImageColor3 = C.Chalk, ImageTransparency = 0.65 }, stamina)
    staminaClip = make("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, stamina)
    staminaFill = art(A.Stroke, { Size = UDim2.fromOffset(STAMINA_WIDTH, 13), ImageColor3 = C.Chalk, ImageTransparency = 0.05 }, staminaClip)

    -- Event callout: paint plate, big word, a line under it
    callout = make("CanvasGroup", {
        Name = "Callout",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.31),
        Size = UDim2.fromOffset(610, 150),
        BackgroundTransparency = 1,
        Visible = false,
    }, gui)
    UIKit.fitScreen(callout)
    calloutClip = make("Frame", { Size = CALLOUT_SIZE, BackgroundTransparency = 1, ClipsDescendants = true }, callout)
    calloutPaint = art(A.Callout, { Size = CALLOUT_SIZE }, calloutClip)
    -- The mockup's 92 px word is past Roblox's TextSize cap: scale its holder up instead
    local big = 92 * UIKit.EM / 100
    local titleHolder: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(305, 58),
        Size = UDim2.fromOffset(560 / big, 100),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, callout)
    make("UIScale", { Scale = big }, titleHolder)
    calloutTitle = text({ FontFace = F.Display, TextScaled = true, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, titleHolder)
    calloutSub = text({
        FontFace = F.Bold,
        TextSize = 20,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(305, 112),
        Size = UDim2.fromOffset(600, 28),
        ZIndex = 2,
    }, callout)
    UIKit.stroke(calloutSub, C.Ink, 1, 0.5)

    gui.Parent = playerGui
end

local function renderOwnSide()
    local mine = player:GetAttribute("Side")
    for side, block in scoreBlocks do
        block.mine.Visible = side == mine
    end
end

local function renderRound(round: number)
    for i, tick in ticks do
        tick.ImageTransparency = if i <= round then 0.05 else 0.72
    end
end

function HUDController.Init()
    buildUI()
    renderOwnSide()
    renderRound(0)
    player:GetAttributeChangedSignal("Side"):Connect(renderOwnSide)

    -- Stamina: chalk, turning sodium amber below half and signal red (flickering) when nearly empty
    MovementController.SetStaminaChangedCallback(function(current: number, max: number)
        local ratio = math.clamp(current / max, 0, 1)
        staminaClip.Size = UDim2.fromScale(ratio, 1)
        staminaFill.ImageColor3 = if ratio > 0.5
            then C.Sodium:Lerp(C.Chalk, (ratio - 0.5) * 2)
            else C.Signal:Lerp(C.Sodium, ratio * 2)
        staminaFill.ImageTransparency = if ratio < 0.25 then 0.05 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 12)) else 0.05
    end)

    local scores: { [Types.Side]: number } = { Red = 0, Blue = 0 }
    local lastTick = -1
    local lastRound = -1
    Remotes.GetEvent("MatchStateUpdated").OnClientEvent:Connect(function(state: Types.MatchState)
        for side, value in { Red = state.redScore, Blue = state.blueScore } :: { [Types.Side]: number } do
            if value ~= scores[side] then
                scores[side] = value
                UIKit.countTo(scoreBlocks[side].number, value)
                UIKit.pop(scoreBlocks[side].number, 1.2)
            end
        end
        if state.roundNumber ~= lastRound then
            lastRound = state.roundNumber
            renderRound(state.roundNumber)
        end

        clockLabel.TextColor3 = C.Chalk
        if state.phase == "Lobby" then
            clockLabel.Text = "WAITING"
        elseif state.phase == "Countdown" then
            clockLabel.Text = tostring(state.timeRemaining)
            if state.timeRemaining ~= lastTick then
                lastTick = state.timeRemaining
                UIKit.pop(clockLabel, 1.25)
            end
        elseif state.phase == "RoundActive" then
            clockLabel.Text = formatTime(state.timeRemaining)
            -- Last 10 seconds: the clock turns signal red and snaps each second
            if state.timeRemaining <= 10 then
                clockLabel.TextColor3 = C.Signal
                if state.timeRemaining ~= lastTick then
                    lastTick = state.timeRemaining
                    UIKit.pop(clockLabel, 1.15)
                end
            end
        elseif state.phase == "RoundEnded" then
            clockLabel.Text = "SWAP SIDES"
        elseif state.phase == "MatchOver" then
            clockLabel.Text = "MATCH OVER"
            local winner: Types.Side? = if state.redScore > state.blueScore then "Red" elseif state.blueScore > state.redScore then "Blue" else nil
            if winner then
                showCallout(`{winner} wins`, nil, SIDE_COLORS[winner], true)
            else
                showCallout("Draw", nil, C.Dim, true)
            end
        end
    end)

    Remotes.GetEvent("PlayerStateUpdated").OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        local color: Color3
        if state.team == "Passers" then
            roleName.Text = "Runner"
            roleHint.Text = if state.hasReachedEndZone then "back to home base" else "reach the safehouse"
            color = PASSER_COLOR
        elseif state.team == "Guards" then
            roleName.Text = "Guard"
            local line = (string.gsub(state.guardRole or "your line", "(%a)(%d)", "%1 %2")) -- "Line2" -> "Line 2"
            roleHint.Text = `defend {line}`
            color = GUARD_COLOR
        else
            roleName.Text = "Spectating"
            roleHint.Text = ""
            color = C.Dim
        end
        if roleName.TextColor3 ~= color then
            TweenService:Create(roleName, M.Fade, { TextColor3 = color }):Play()
            UIKit.pop(roleName, 1.12)
        end

        if state.isTagged then
            showCallout("Tagged!", nil, C.Signal)
        end
    end)

    Remotes.GetEvent("ZoneCheckpointReached").OnClientEvent:Connect(function(targetUserId: number, zoneName: string, _score: number)
        if targetUserId == player.UserId then
            -- "Zone 2 (Second Quarter)" -> "Zone 2", "Safehouse / End Zone" -> "Safehouse"
            local short = string.match(zoneName, "^(.-)%s*[(/]") or zoneName
            showCallout(short, "+1", PASSER_COLOR)
        end
    end)

    Remotes.GetEvent("TubigScored").OnClientEvent:Connect(function(_targetUserId: number, playerName: string, _score: number)
        showCallout("Tubig!", `{playerName} scored +5`, C.Sodium, true)
    end)

    Remotes.GetEvent("TagConfirmed").OnClientEvent:Connect(function(taggerUserId: number)
        if taggerUserId == player.UserId then
            showHitMarker()
        end
    end)
end

return HUDController
