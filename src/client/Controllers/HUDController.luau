--!strict
--[[
    HUDController.luau
    Match HUD in the "night court" style (UIKit): a broadcast scoreboard with the Red/Blue scores and the
    round clock, the role tag, crosshair + hit marker, the stamina bar, and broadcast strips for events
    ("TUBIG!", zones, tags, the winner).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local MovementController = require(script.Parent.MovementController)
local UIKit = require(script.Parent.UIKit)

local C, F, M = UIKit.Color, UIKit.Font, UIKit.Motion
local make, text = UIKit.make, UIKit.text

local HUDController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local PASSER_COLOR = Color3.fromRGB(79, 184, 240)
local GUARD_COLOR = Color3.fromRGB(240, 122, 58)
local SIDE_COLORS: { [Types.Side]: Color3 } = { Red = Color3.fromRGB(201, 58, 63), Blue = Color3.fromRGB(52, 113, 217) }
local STAMINA_LOW, STAMINA_MID, STAMINA_HIGH = C.Signal, C.Amber, Color3.fromRGB(88, 196, 120)

type ScoreBlock = { frame: Frame, number: TextLabel, mark: Frame }

local phaseLabel: TextLabel
local timerLabel: TextLabel
local scoreBlocks: { [Types.Side]: ScoreBlock } = {}
local roleAccent: Frame
local roleLabel: TextLabel
local staminaFill: Frame
local hitMarker: Frame
local hitRing: UIStroke
local hitScale: UIScale
local banner: CanvasGroup
local bannerBody: Frame
local bannerAccent: Frame
local bannerRays: ImageLabel
local bannerLabel: TextLabel

local bannerToken = 0
local bannerTweens: { Tween } = {}

-- Fades a strip out at both ends, like a broadcast graphic
local EDGE_FADE = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.14, 0),
    NumberSequenceKeypoint.new(0.86, 0),
    NumberSequenceKeypoint.new(1, 1),
})

local function formatTime(seconds: number): string
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Broadcast strip: slides in from the left, holds, slides on to the right and fades.
-- `big` adds slow rays behind it (Tubig, the winner). A newer strip takes over cleanly.
local function showBanner(message: string, color: Color3, big: boolean?)
    bannerToken += 1
    local token = bannerToken
    for _, tween in bannerTweens do
        tween:Cancel()
    end
    table.clear(bannerTweens)

    bannerLabel.Text = string.upper(message) -- broadcast caps, whatever case the zone/player name arrives in
    bannerAccent.BackgroundColor3 = color
    bannerRays.ImageColor3 = color
    bannerRays.Visible = big == true
    banner.Visible = true
    banner.GroupTransparency = 1
    bannerBody.Position = UDim2.new(0.5, -60, 0.5, 0)
    TweenService:Create(banner, M.Fade, { GroupTransparency = 0 }):Play()
    TweenService:Create(bannerBody, M.Slide, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
    UIKit.pop(bannerLabel, 1.08)

    task.delay(1.9, function()
        if token ~= bannerToken then return end
        bannerTweens = {
            TweenService:Create(banner, M.Slide, { GroupTransparency = 1 }),
            TweenService:Create(bannerBody, M.Slide, { Position = UDim2.new(0.5, 60, 0.5, 0) }),
        }
        bannerTweens[1].Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed and token == bannerToken then
                banner.Visible = false
            end
        end)
        for _, tween in bannerTweens do
            tween:Play()
        end
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

local function makeScoreBlock(parent: Frame, side: Types.Side, alignRight: boolean): ScoreBlock
    local frame: Frame = make("Frame", {
        Name = `{side}Score`,
        AnchorPoint = Vector2.new(if alignRight then 1 else 0, 0),
        Position = UDim2.new(if alignRight then 1 else 0, if alignRight then -12 else 12, 0, 12),
        Size = UDim2.fromOffset(92, 62),
        BackgroundColor3 = SIDE_COLORS[side]:Lerp(C.Deep, 0.3),
    }, parent)
    UIKit.corner(frame, 3)
    UIKit.wash(frame, 0.75)
    text({ Text = string.upper(side), FontFace = F.Label, TextSize = 12, TextColor3 = C.Chalk, TextTransparency = 0.2, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 4) }, frame)
    local number = text({
        Name = "Number",
        Text = "0",
        FontFace = F.Display,
        TextSize = 34,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 40),
    }, frame)
    -- Your own side gets an amber underline
    local mark: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 4),
        Size = UDim2.new(1, -16, 0, 3),
        BackgroundColor3 = C.Amber,
        BorderSizePixel = 0,
        Visible = false,
    }, frame)
    return { frame = frame, number = number, mark = mark }
end

local function buildUI()
    local gui: ScreenGui = make("ScreenGui", {
        Name = "PatinteroHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    }, nil)

    -- Scoreboard: scores on the sides, phase + clock in the middle
    local board: Frame = make("Frame", {
        Name = "TopBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(440, 86),
        BackgroundColor3 = C.Night,
        BackgroundTransparency = 0.06,
    }, gui)
    UIKit.wash(board, 0.8)
    UIKit.panel(board)
    UIKit.fitScreen(board)

    scoreBlocks.Red = makeScoreBlock(board, "Red", false)
    scoreBlocks.Blue = makeScoreBlock(board, "Blue", true)

    phaseLabel = text({
        Name = "Phase",
        Text = "LOBBY",
        FontFace = F.Label,
        TextSize = 13,
        TextColor3 = C.Dim,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.fromOffset(224, 16),
    }, board)
    timerLabel = text({
        Name = "Timer",
        Text = "WAITING FOR PLAYERS...",
        FontFace = F.Display,
        TextScaled = true,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 26),
        Size = UDim2.fromOffset(224, 50),
    }, board)
    make("UITextSizeConstraint", { MaxTextSize = 46 }, timerLabel)

    -- Role tag under the scoreboard, with an accent bar in the role's color
    local role: Frame = make("Frame", {
        Name = "RoleBadge",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 12),
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.Night,
        BackgroundTransparency = 0.1,
    }, board)
    roleAccent = (UIKit.panel(role, C.Dim, "Left", 3)) :: Frame
    roleLabel = text({
        Text = "ROLE: SPECTATOR",
        FontFace = F.Label,
        TextSize = 14,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
    }, role)
    -- Padding on the text, not the tag, so the accent bar stays on the tag's edge
    make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12) }, roleLabel)

    -- Crosshair + hit marker
    local crosshair: Frame = make("Frame", {
        Name = "Crosshair",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = C.Chalk,
        BackgroundTransparency = 0.25,
    }, gui)
    UIKit.corner(crosshair, 2)
    UIKit.stroke(crosshair, C.Deep, 1, 0.4)
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

    -- Thin stamina bar
    local stamina: Frame = make("Frame", {
        Name = "Stamina",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -28),
        Size = UDim2.fromOffset(260, 6),
        BackgroundColor3 = C.Deep,
        BackgroundTransparency = 0.1,
    }, gui)
    UIKit.corner(stamina, 2)
    UIKit.stroke(stamina, C.Steel, 1, 0.2)
    UIKit.fitScreen(stamina)
    staminaFill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = STAMINA_HIGH, BorderSizePixel = 0 }, stamina)
    UIKit.corner(staminaFill, 2)

    -- Event strip
    banner = make("CanvasGroup", {
        Name = "Banner",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.32),
        Size = UDim2.fromOffset(900, 220),
        BackgroundTransparency = 1,
        Visible = false,
    }, gui)
    UIKit.fitScreen(banner)
    bannerBody = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, banner)
    bannerRays = make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 260),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Rays,
        ImageTransparency = 0.72,
        Visible = false,
    }, bannerBody)
    UIKit.spin(bannerRays, 20)
    local strip: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(820, 74),
        BackgroundColor3 = C.Night,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
    }, bannerBody)
    make("UIGradient", { Transparency = EDGE_FADE }, strip)
    bannerAccent = make("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Chalk, BorderSizePixel = 0 }, strip)
    make("UIGradient", { Transparency = EDGE_FADE }, bannerAccent)
    local underline: Frame = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Steel, BorderSizePixel = 0 }, strip)
    make("UIGradient", { Transparency = EDGE_FADE }, underline)
    bannerLabel = text({
        Text = "",
        FontFace = F.Display,
        TextScaled = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(600, 46),
    }, strip)
    make("UITextSizeConstraint", { MaxTextSize = 38 }, bannerLabel)

    gui.Parent = playerGui
end

local function renderOwnSide()
    local mine = player:GetAttribute("Side")
    for side, block in scoreBlocks do
        block.mark.Visible = side == mine
    end
end

function HUDController.Init()
    buildUI()
    renderOwnSide()
    player:GetAttributeChangedSignal("Side"):Connect(renderOwnSide)

    -- Stamina: smooth green -> amber -> red, flickering when nearly empty
    MovementController.SetStaminaChangedCallback(function(current: number, max: number)
        local ratio = math.clamp(current / max, 0, 1)
        staminaFill.Size = UDim2.fromScale(ratio, 1)
        staminaFill.BackgroundColor3 = if ratio > 0.5
            then STAMINA_MID:Lerp(STAMINA_HIGH, (ratio - 0.5) * 2)
            else STAMINA_LOW:Lerp(STAMINA_MID, ratio * 2)
        staminaFill.BackgroundTransparency = if ratio < 0.25 then 0.1 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 12)) else 0
    end)

    local scores: { [Types.Side]: number } = { Red = 0, Blue = 0 }
    local lastTick = -1
    Remotes.GetEvent("MatchStateUpdated").OnClientEvent:Connect(function(state: Types.MatchState)
        for side, value in { Red = state.redScore, Blue = state.blueScore } :: { [Types.Side]: number } do
            if value ~= scores[side] then
                scores[side] = value
                UIKit.countTo(scoreBlocks[side].number, value)
                UIKit.pop(scoreBlocks[side].number, 1.2)
            end
        end

        timerLabel.TextColor3 = C.Chalk
        if state.phase == "Lobby" then
            phaseLabel.Text = "LOBBY"
            timerLabel.Text = "WAITING FOR PLAYERS..."
        elseif state.phase == "Countdown" then
            phaseLabel.Text = "ROUND STARTING IN"
            timerLabel.Text = tostring(state.timeRemaining)
            if state.timeRemaining ~= lastTick then
                lastTick = state.timeRemaining
                UIKit.pop(timerLabel, 1.25)
            end
        elseif state.phase == "RoundActive" then
            phaseLabel.Text = `ROUND {state.roundNumber}`
            timerLabel.Text = formatTime(state.timeRemaining)
            -- Last 10 seconds: the clock turns signal red and snaps each second
            if state.timeRemaining <= 10 then
                timerLabel.TextColor3 = C.Signal
                if state.timeRemaining ~= lastTick then
                    lastTick = state.timeRemaining
                    UIKit.pop(timerLabel, 1.15)
                end
            end
        elseif state.phase == "RoundEnded" then
            phaseLabel.Text = "ROUND ENDED"
            timerLabel.Text = "SWAPPING SIDES!"
        elseif state.phase == "MatchOver" then
            phaseLabel.Text = ""
            timerLabel.Text = "MATCH OVER!"
            local winner: Types.Side? = if state.redScore > state.blueScore then "Red" elseif state.blueScore > state.redScore then "Blue" else nil
            if winner then
                showBanner(`{string.upper(winner)} WINS!`, SIDE_COLORS[winner], true)
            else
                showBanner("MATCH DRAW!", C.Chalk, true)
            end
        end
    end)

    Remotes.GetEvent("PlayerStateUpdated").OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        local color: Color3
        if state.team == "Passers" then
            roleLabel.Text = if state.hasReachedEndZone then "ROLE: RUNNER - RETURN TO HOME BASE!" else "ROLE: RUNNER - REACH THE SAFEHOUSE!"
            color = PASSER_COLOR
        elseif state.team == "Guards" then
            roleLabel.Text = `ROLE: GUARD ({state.guardRole or "Guard"}) - DEFEND YOUR LINE!`
            color = GUARD_COLOR
        else
            roleLabel.Text = "ROLE: SPECTATOR"
            color = C.Dim
        end
        if roleAccent.BackgroundColor3 ~= color then
            TweenService:Create(roleAccent, M.Fade, { BackgroundColor3 = color }):Play()
            UIKit.pop(roleLabel, 1.08)
        end

        if state.isTagged then
            showBanner("YOU WERE TAGGED!", C.Signal)
        end
    end)

    Remotes.GetEvent("ZoneCheckpointReached").OnClientEvent:Connect(function(targetUserId: number, zoneName: string, _score: number)
        if targetUserId == player.UserId then
            showBanner(`{zoneName} REACHED! (+1)`, PASSER_COLOR)
        end
    end)

    Remotes.GetEvent("TubigScored").OnClientEvent:Connect(function(_targetUserId: number, playerName: string, _score: number)
        showBanner(`TUBIG! {playerName} SCORED! (+5)`, C.Amber, true)
    end)

    Remotes.GetEvent("TagConfirmed").OnClientEvent:Connect(function(taggerUserId: number)
        if taggerUserId == player.UserId then
            showHitMarker()
        end
    end)
end

return HUDController
