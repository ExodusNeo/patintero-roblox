--!strict
--[[
    HUDController.luau
    Match HUD in the "jeepney chrome" style (UIKit): a route-sign plate with the Red/Blue scores and the
    round clock, the role pill, crosshair + hit marker, the stamina pill, and ribbon banners for events
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

local PASSER_COLOR = Color3.fromRGB(100, 220, 255)
local GUARD_COLOR = Color3.fromRGB(255, 140, 90)
local SIDE_COLORS: { [Types.Side]: Color3 } = { Red = Color3.fromRGB(224, 48, 63), Blue = Color3.fromRGB(56, 128, 240) }
local STAMINA_LOW, STAMINA_MID, STAMINA_HIGH = Color3.fromRGB(230, 60, 60), C.Yellow, Color3.fromRGB(70, 214, 110)
local URGENT = Color3.fromRGB(255, 96, 86)

type ScoreBlock = { frame: Frame, number: TextLabel, mark: UIStroke }

local phaseLabel: TextLabel
local timerLabel: TextLabel
local scoreBlocks: { [Types.Side]: ScoreBlock } = {}
local roleBadge: Frame
local roleLabel: TextLabel
local staminaFill: Frame
local hitMarker: Frame
local hitRing: UIStroke
local hitScale: UIScale
local banner: CanvasGroup
local bannerBody: Frame
local bannerRibbon: ImageLabel
local bannerRays: ImageLabel
local bannerLabel: TextLabel

local bannerToken = 0
local bannerTweens: { Tween } = {}

local function formatTime(seconds: number): string
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Ribbon pops in (scale + tilt), holds, then floats up and fades. A newer banner takes over cleanly.
-- `big` adds spinning sunburst rays behind it (Tubig, the winner).
local function showBanner(message: string, color: Color3, big: boolean?)
    bannerToken += 1
    local token = bannerToken
    for _, tween in bannerTweens do
        tween:Cancel()
    end
    table.clear(bannerTweens)

    bannerLabel.Text = message
    bannerRibbon.ImageColor3 = color
    bannerRays.ImageColor3 = color:Lerp(C.Yellow, 0.5)
    bannerRays.Visible = big == true
    banner.Visible = true
    banner.GroupTransparency = 0
    bannerBody.Position = UDim2.fromScale(0.5, 0.5)
    bannerBody.Rotation = -7
    UIKit.pop(bannerBody, 0.35)
    TweenService:Create(bannerBody, M.Pop, { Rotation = 0 }):Play()

    task.delay(1.9, function()
        if token ~= bannerToken then return end
        bannerTweens = {
            TweenService:Create(banner, M.Slide, { GroupTransparency = 1 }),
            TweenService:Create(bannerBody, M.Slide, { Position = UDim2.new(0.5, 0, 0.5, -24) }),
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

local function makeScoreBlock(parent: Frame, side: Types.Side, alignRight: boolean): ScoreBlock
    local frame: Frame = make("Frame", {
        Name = `{side}Score`,
        AnchorPoint = Vector2.new(if alignRight then 1 else 0, 0),
        Position = UDim2.new(if alignRight then 1 else 0, if alignRight then -16 else 16, 0, 16),
        Size = UDim2.fromOffset(96, 70),
        BackgroundColor3 = SIDE_COLORS[side],
    }, parent)
    UIKit.corner(frame, UDim.new(0, 16))
    UIKit.wash(frame, 0.7)
    -- Your own side wears a sun-yellow outline
    local mark = UIKit.stroke(frame, C.Yellow, 3, 1)
    text({ Text = string.upper(side), FontFace = F.Heavy, TextSize = 13, TextColor3 = C.Cream, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 5) }, frame)
    local number = text({
        Name = "Number",
        Text = "0",
        FontFace = F.Display,
        TextSize = 38,
        TextColor3 = C.White,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 44),
    }, frame)
    UIKit.stroke(number, C.InkDeep, 2.5, 0.2)
    return { frame = frame, number = number, mark = mark }
end

local function buildUI()
    local gui: ScreenGui = make("ScreenGui", {
        Name = "PatinteroHUD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    }, nil)

    -- Route-sign plate: scores on the sides, phase + clock in the middle
    local plate: Frame = make("Frame", {
        Name = "TopBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(460, 102),
        BackgroundColor3 = C.Ink,
        BackgroundTransparency = 0.08,
    }, gui)
    UIKit.wash(plate, 0.75)
    UIKit.plate(plate)
    UIKit.fitScreen(plate)

    scoreBlocks.Red = makeScoreBlock(plate, "Red", false)
    scoreBlocks.Blue = makeScoreBlock(plate, "Blue", true)

    phaseLabel = text({
        Name = "Phase",
        Text = "LOBBY",
        FontFace = F.Heavy,
        TextSize = 14,
        TextColor3 = C.Muted,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.fromOffset(224, 18),
    }, plate)
    timerLabel = text({
        Name = "Timer",
        Text = "WAITING FOR PLAYERS...",
        FontFace = F.Display,
        TextScaled = true,
        TextColor3 = C.Cream,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 34),
        Size = UDim2.fromOffset(224, 54),
    }, plate)
    make("UITextSizeConstraint", { MaxTextSize = 48 }, timerLabel)
    UIKit.stroke(timerLabel, C.InkDeep, 3, 0.1)

    -- Role pill hanging under the plate
    roleBadge = make("Frame", {
        Name = "RoleBadge",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 16),
        Size = UDim2.fromOffset(0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.InkLight,
    }, plate)
    UIKit.corner(roleBadge, UDim.new(1, 0))
    make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, roleBadge)
    roleLabel = text({
        Text = "ROLE: SPECTATOR",
        FontFace = F.Heavy,
        TextSize = 15,
        TextColor3 = C.InkDeep,
        Size = UDim2.fromScale(0, 1),
        AutomaticSize = Enum.AutomaticSize.X,
    }, roleBadge)

    -- Crosshair + hit marker
    local crosshair: Frame = make("Frame", {
        Name = "Crosshair",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = C.White,
        BackgroundTransparency = 0.35,
    }, gui)
    UIKit.corner(crosshair, UDim.new(1, 0))
    UIKit.stroke(crosshair, C.InkDeep, 1, 0.5)
    hitMarker = make("Frame", {
        Name = "HitMarker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        Visible = false,
    }, gui)
    UIKit.corner(hitMarker, UDim.new(1, 0))
    hitRing = UIKit.stroke(hitMarker, Color3.fromRGB(255, 70, 70), 3)
    hitScale = make("UIScale", {}, hitMarker)

    -- Stamina pill with a thin chrome rim
    local stamina: Frame = make("Frame", {
        Name = "Stamina",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -26),
        Size = UDim2.fromOffset(280, 16),
        BackgroundColor3 = C.InkDeep,
        BackgroundTransparency = 0.15,
    }, gui)
    UIKit.plate(stamina, nil, 0.12)
    UIKit.fitScreen(stamina)
    staminaFill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = STAMINA_HIGH }, stamina)
    UIKit.corner(staminaFill, UDim.new(1, 0))
    UIKit.wash(staminaFill, 0.72)

    -- Event banner: a ribbon (Blender) over optional spinning rays
    banner = make("CanvasGroup", {
        Name = "Banner",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.32),
        Size = UDim2.fromOffset(700, 240),
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
        Size = UDim2.fromOffset(300, 300),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Rays,
        ImageTransparency = 0.2,
        Visible = false,
    }, bannerBody)
    UIKit.spin(bannerRays, 9)
    bannerRibbon = make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(680, 170), -- the ribbon's own 4:1 shape (9-slice mangles its tails)
        BackgroundTransparency = 1,
        Image = UIKit.Image.Ribbon,
    }, bannerBody)
    bannerLabel = text({
        Text = "",
        FontFace = F.Display,
        TextScaled = true,
        TextColor3 = C.Cream,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -3),
        Size = UDim2.fromOffset(450, 56),
    }, bannerBody)
    make("UITextSizeConstraint", { MaxTextSize = 40 }, bannerLabel)
    UIKit.stroke(bannerLabel, C.InkDeep, 3, 0.15)

    gui.Parent = playerGui
end

local function renderOwnSide()
    local mine = player:GetAttribute("Side")
    for side, block in scoreBlocks do
        block.mark.Transparency = if side == mine then 0 else 1
    end
end

function HUDController.Init()
    buildUI()
    renderOwnSide()
    player:GetAttributeChangedSignal("Side"):Connect(renderOwnSide)

    -- Stamina: smooth green -> yellow -> red, blinking when nearly empty
    MovementController.SetStaminaChangedCallback(function(current: number, max: number)
        local ratio = math.clamp(current / max, 0, 1)
        staminaFill.Size = UDim2.fromScale(ratio, 1)
        staminaFill.BackgroundColor3 = if ratio > 0.5
            then STAMINA_MID:Lerp(STAMINA_HIGH, (ratio - 0.5) * 2)
            else STAMINA_LOW:Lerp(STAMINA_MID, ratio * 2)
        staminaFill.BackgroundTransparency = if ratio < 0.25 then 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 12)) else 0
    end)

    local scores: { [Types.Side]: number } = { Red = 0, Blue = 0 }
    local lastTick = -1
    Remotes.GetEvent("MatchStateUpdated").OnClientEvent:Connect(function(state: Types.MatchState)
        for side, value in { Red = state.redScore, Blue = state.blueScore } :: { [Types.Side]: number } do
            if value ~= scores[side] then
                scores[side] = value
                UIKit.countTo(scoreBlocks[side].number, value)
                UIKit.pop(scoreBlocks[side].number, 1.35)
            end
        end

        timerLabel.TextColor3 = C.Cream
        if state.phase == "Lobby" then
            phaseLabel.Text = "LOBBY"
            timerLabel.Text = "WAITING FOR PLAYERS..."
        elseif state.phase == "Countdown" then
            phaseLabel.Text = "ROUND STARTING IN"
            timerLabel.Text = tostring(state.timeRemaining)
            if state.timeRemaining ~= lastTick then
                lastTick = state.timeRemaining
                UIKit.pop(timerLabel, 1.4)
            end
        elseif state.phase == "RoundActive" then
            phaseLabel.Text = `ROUND {state.roundNumber}`
            timerLabel.Text = formatTime(state.timeRemaining)
            -- Last 10 seconds: the clock turns red and punches each second
            if state.timeRemaining <= 10 then
                timerLabel.TextColor3 = URGENT
                if state.timeRemaining ~= lastTick then
                    lastTick = state.timeRemaining
                    UIKit.pop(timerLabel, 1.25)
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
                showBanner("MATCH DRAW!", C.Yellow, true)
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
            color = C.Muted
        end
        if roleBadge.BackgroundColor3 ~= color then
            TweenService:Create(roleBadge, M.Fade, { BackgroundColor3 = color }):Play()
            UIKit.pop(roleLabel, 1.15)
        end

        if state.isTagged then
            showBanner("YOU WERE TAGGED!", Color3.fromRGB(200, 40, 50))
        end
    end)

    Remotes.GetEvent("ZoneCheckpointReached").OnClientEvent:Connect(function(targetUserId: number, zoneName: string, _score: number)
        if targetUserId == player.UserId then
            showBanner(`{zoneName} REACHED! (+1)`, Color3.fromRGB(46, 160, 90))
        end
    end)

    Remotes.GetEvent("TubigScored").OnClientEvent:Connect(function(_targetUserId: number, playerName: string, _score: number)
        showBanner(`TUBIG! {playerName} SCORED! (+5)`, C.Teal, true)
    end)

    Remotes.GetEvent("TagConfirmed").OnClientEvent:Connect(function(taggerUserId: number)
        if taggerUserId == player.UserId then
            showHitMarker()
        end
    end)
end

return HUDController
