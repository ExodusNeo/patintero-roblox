--!strict
--[[
    SpinController.luau
    Hub-only Styles menu (G or the STYLES button), in the "jeepney chrome" style (UIKit):
    - a showcase of your own avatar looping the style's dance (StyleAnimator) over spinning sunburst rays
    - the style's name, rarity, skills and passives, and the roll odds per tier as bars
    - SPIN: names shuffle and tick, then the reveal flashes, bursts the rays and (Epic/Legendary)
      throws banderita confetti
    The SPIN button is Modal so the mouse is free even if the camera is mouse-locked.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local SoundController = require(script.Parent.SoundController)
local StyleAnimator = require(script.Parent.StyleAnimator)
local UIKit = require(script.Parent.UIKit)

local C, F, M = UIKit.Color, UIKit.Font, UIKit.Motion
local make, text = UIKit.make, UIKit.text

local SpinController = {}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(860, 500) -- the board is laid out at this size, then scaled to fit the screen
local PODIUM_TOP = -3
local CONFETTI = { C.Red, C.Yellow, C.Teal, Color3.fromRGB(64, 128, 242), C.Cream }

type SkillCard = { icon: ImageLabel, name: TextLabel, cooldown: TextLabel }

local backdrop: Frame
local holder: Frame
local panel: Frame
local openScale: UIScale
local hintButton: TextButton
local hintCount: TextLabel
local showcase: Frame
local showcaseFill: CanvasGroup
local rays: ImageLabel
local raysTween: Tween?
local viewport: ViewportFrame
local worldModel: WorldModel
local revealFlash: Frame
local showcaseRim: ImageLabel
local nameLabel: TextLabel
local nameGradient: UIGradient
local nameSweep: Tween?
local rarityChip: Frame
local rarityText: TextLabel
local equippedChip: Frame
local descLabel: TextLabel
local skillCards: { [Types.SkillSlot]: SkillCard } = {}
local statLabels: { TextLabel } = {}
local oddsFills: { { fill: Frame, share: number } } = {}
local spinButton: TextButton
local spinText: TextLabel
local spinChip: Frame
local spinChipText: TextLabel
local spinSheen: Frame

local spinning = false
local avatar: Model? = nil
local avatarSource: Model? = nil -- the character the preview was copied from
local posing: string? = nil -- showcase animation the preview avatar is looping

local function getSpins(): number
    return (player:GetAttribute("Spins") :: number?) or 0
end

local function equippedId(): string
    return Styles.Get(player:GetAttribute("Style") :: string?).id
end

-- Copy of your current character for the preview: scripts and sounds stripped (scripts would run
-- inside PlayerGui), root anchored, name tag hidden. Rebuilt after you respawn.
local function ensureAvatar()
    local character = player.Character
    if not character or character == avatarSource then return end
    if avatar then
        avatar:Destroy()
    end
    avatar, avatarSource, posing = nil, nil, nil

    local wasArchivable = character.Archivable
    character.Archivable = true
    local clone = character:Clone()
    character.Archivable = wasArchivable
    if not clone then return end

    for _, item in clone:GetDescendants() do
        if item:IsA("LuaSourceContainer") or item:IsA("Sound") then
            item:Destroy()
        end
    end
    local humanoid = clone:FindFirstChildOfClass("Humanoid")
    local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or not root then
        clone:Destroy()
        return
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    root.Anchored = true
    clone:PivotTo(CFrame.new()) -- faces -Z, toward the preview camera
    local box, size = clone:GetBoundingBox()
    clone:PivotTo(CFrame.new(0, PODIUM_TOP - (box.Position.Y - size.Y / 2), 0)) -- stand on the podium, any avatar height
    clone.Parent = worldModel
    avatar, avatarSource = clone, character
end

-- Loops the style's showcase dance on the preview avatar (kept running across refreshes).
local function playPose(style: Types.StyleDef)
    ensureAvatar()
    local name = `{style.id}_Pose`
    if not avatar or posing == name then return end
    StyleAnimator.Play(avatar, name)
    posing = name
end

local function setRaySpeed(seconds: number)
    if raysTween then
        raysTween:Cancel()
    end
    raysTween = UIKit.spin(rays, seconds)
end

-- Epic and Legendary names get a light sweeping through the lettering
local function paintName(color: Color3, sweep: boolean)
    if nameSweep then
        nameSweep:Cancel()
        nameSweep = nil
    end
    nameGradient.Offset = Vector2.zero
    if sweep then
        local light = color:Lerp(C.White, 0.85)
        nameGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(0.4, color),
            ColorSequenceKeypoint.new(0.5, light),
            ColorSequenceKeypoint.new(0.6, color),
            ColorSequenceKeypoint.new(1, color),
        })
        if not UIKit.reducedMotion() then
            nameGradient.Offset = Vector2.new(-1, 0)
            local sweepTween = TweenService:Create(nameGradient, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.2), { Offset = Vector2.new(1, 0) })
            sweepTween:Play()
            nameSweep = sweepTween
        end
    else
        nameGradient.Color = ColorSequence.new(color:Lerp(C.White, 0.25), color)
    end
end

local function showStyle(style: Types.StyleDef, withPose: boolean)
    local color = Styles.RarityColors[style.rarity]
    nameLabel.Text = string.upper(style.name)
    paintName(color, not spinning and (style.rarity == "Epic" or style.rarity == "Legendary"))
    rarityChip.BackgroundColor3 = color
    rarityText.Text = string.upper(style.rarity)
    equippedChip.Visible = style.id == equippedId() and not spinning
    descLabel.Text = style.description
    for slot, card in skillCards do
        local skill = if slot == "Q" then style.skills.Q else style.skills.E
        card.icon.Image = UIKit.Icon[skill.kind] or ""
        card.icon.ImageColor3 = color:Lerp(C.White, 0.15)
        card.name.Text = skill.name
        card.cooldown.Text = `{skill.cooldown}s`
    end
    statLabels[1].Text = `Speed x{style.speedMult}`
    statLabels[2].Text = `Stamina x{style.staminaMult}`
    statLabels[3].Text = `Reach +{style.reachBonus}`
    showcaseFill.BackgroundColor3 = color:Lerp(C.InkDeep, 0.72)
    rays.ImageColor3 = color
    showcaseRim.ImageColor3 = color:Lerp(C.White, 0.5)
    if withPose then
        playPose(style)
    end
end

local function refresh()
    local spins = getSpins()
    hintCount.Text = tostring(spins)

    -- The server sets Style the moment it rolls; keep the result hidden until the reveal.
    if spinning then
        spinText.Text = "ROLLING..."
        spinChip.Visible = false
        spinSheen.Visible = false
        spinButton.BackgroundColor3 = C.RedDark
        return
    end

    showStyle(Styles.Get(equippedId()), panel.Visible)
    local canSpin = spins >= 1
    spinText.Text = if canSpin then "SPIN" else "NO SPINS LEFT"
    spinText.TextColor3 = if canSpin then C.Cream else C.Muted
    spinChip.Visible = canSpin
    spinChipText.Text = tostring(spins)
    spinSheen.Visible = canSpin and not UIKit.reducedMotion()
    spinButton.BackgroundColor3 = if canSpin then C.Red else C.InkLight
end

local function setOpen(open: boolean)
    if open == panel.Visible then return end
    -- The skill bar peeks out under the menu and would spoil a roll's new skill names
    local skillBar = player.PlayerGui:FindFirstChild("SkillBar")
    if skillBar and skillBar:IsA("ScreenGui") then
        skillBar.Enabled = not open
    end
    if open then
        panel.Visible = true
        backdrop.Visible = true
        TweenService:Create(backdrop, M.Fade, { BackgroundTransparency = 0.45 }):Play()
        openScale.Scale = 0.86
        panel.Position = UDim2.new(0.5, 0, 0.5, 30)
        TweenService:Create(openScale, M.Pop, { Scale = 1 }):Play()
        TweenService:Create(panel, M.Slide, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
        -- Odds bars fill in, one tier after another
        for i, bar in oddsFills do
            bar.fill.Size = UDim2.fromScale(0, 1)
            TweenService:Create(bar.fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.12 + i * 0.07),
                { Size = UDim2.fromScale(bar.share, 1) }):Play()
        end
        refresh()
        if UserInputService.GamepadEnabled then
            GuiService.SelectedObject = spinButton
        end
    else
        TweenService:Create(backdrop, M.Quick, { BackgroundTransparency = 1 }):Play()
        local shrink = TweenService:Create(openScale, M.Quick, { Scale = 0.9 })
        shrink.Completed:Once(function()
            panel.Visible = false
            backdrop.Visible = false
        end)
        shrink:Play()
        if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
            GuiService.SelectedObject = nil
        end
        if avatar then
            StyleAnimator.Stop(avatar)
            posing = nil
        end
    end
end

local function reveal(style: Types.StyleDef)
    local big = style.rarity == "Epic" or style.rarity == "Legendary"
    local color = Styles.RarityColors[style.rarity]
    showStyle(style, true)
    setRaySpeed(24)
    UIKit.pop(rays, if big then 1.7 else 1.35)
    UIKit.pop(nameLabel, 1.5)
    UIKit.pop(rarityChip, 1.8)
    UIKit.pop(viewport, 1.12)

    if style.rarity == "Legendary" then
        SoundController.PlaySFX("RevealBoom", Vector2.new(1, 1))
        UIKit.shake(holder, 8)
    end
    SoundController.PlaySFX(if big then "TubigFanfare" else "CheckpointChime", if style.rarity == "Rare" then Vector2.new(1.15, 1.2) else nil)

    revealFlash.BackgroundColor3 = color:Lerp(C.White, 0.4)
    revealFlash.BackgroundTransparency = if big then 0.05 else 0.45
    revealFlash.Visible = true
    local fade = TweenService:Create(revealFlash, TweenInfo.new(if big then 0.9 else 0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
    fade.Completed:Once(function()
        revealFlash.Visible = false
    end)
    fade:Play()

    if big then
        local colors = table.clone(CONFETTI)
        table.insert(colors, color)
        UIKit.confetti(panel, if style.rarity == "Legendary" then 54 else 26, colors, Vector2.new(0.21, 0.42))
    end
end

local function spin()
    if spinning or getSpins() < 1 then return end
    spinning = true
    refresh()
    setRaySpeed(3)

    local result: string? = nil
    local done = false
    task.spawn(function()
        local ok, rolled = pcall(function()
            return Remotes.GetFunction("Spin"):InvokeServer()
        end)
        result = if ok and typeof(rolled) == "string" then rolled else nil
        done = true
    end)

    -- Shuffle through the roster (text only; poses would hit the track limit), slowing as it settles
    local started = os.clock()
    local i = 0
    while os.clock() - started < 1.4 or not done do
        i += 1
        showStyle(Styles.List[i % #Styles.List + 1], false)
        UIKit.pop(nameLabel, 1.08)
        local pitch = 1.25 - math.min(os.clock() - started, 1.4) * 0.2 -- ticks drop in pitch as the roll slows
        SoundController.PlaySFX("SpinTick", Vector2.new(pitch, pitch))
        task.wait(0.06 + (os.clock() - started) * 0.06)
    end

    -- A beat of anticipation before the big ones land
    local style = if result then Styles.Get(result) else nil
    if style and (style.rarity == "Epic" or style.rarity == "Legendary") then
        UIKit.shake(showcase, 4)
        task.wait(0.28)
    end

    spinning = false
    refresh()
    if style then
        reveal(style)
    else
        setRaySpeed(24)
    end
end

local function chip(parent: Instance, color: Color3, label: string, order: number): (Frame, TextLabel)
    local frame: Frame = make("Frame", {
        LayoutOrder = order,
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = color,
    }, parent)
    UIKit.corner(frame, UDim.new(1, 0))
    make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
    local labelText = text({ Text = label, FontFace = F.Heavy, TextSize = 14, TextColor3 = C.InkDeep, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, frame)
    return frame, labelText
end

local function row(parent: Instance, order: number, height: number, padding: number): Frame
    local frame: Frame = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 }, parent)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, frame)
    return frame
end

local function fitBoard(scale: UIScale)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    scale.Scale = math.min(view.X * 0.94 / DESIGN.X, view.Y * 0.86 / DESIGN.Y, 1.25)
end

local function buildHintButton()
    -- Own ScreenGui inside the core-UI safe area (the menu's backdrop is full-bleed)
    local gui: ScreenGui = make("ScreenGui", { Name = "StylesButton", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets }, nil)
    local slot: Frame = make("Frame", {
        Position = UDim2.fromOffset(18, 18), -- top-left; bottom-left is the touch thumbstick
        Size = UDim2.fromOffset(196, 54),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(slot) -- the button itself carries the hover/press scale
    hintButton = make("TextButton", {
        Name = "StylesButton",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.Red,
        AutoButtonColor = false,
        Text = "",
    }, slot)
    UIKit.wash(hintButton, 0.7)
    UIKit.plate(hintButton, nil, 0.22)
    UIKit.shimmer(hintButton, 4)
    local label = text({
        Text = "STYLES",
        FontFace = F.Display,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -60, 1, 0),
        ZIndex = 16,
    }, hintButton)
    UIKit.stroke(label, C.InkDeep, 2.5, 0.1)
    local badge: Frame = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = C.Yellow,
        ZIndex = 16,
    }, hintButton)
    UIKit.corner(badge, UDim.new(1, 0))
    UIKit.stroke(badge, C.InkDeep, 2, 0.2)
    hintCount = text({ Text = "0", FontFace = F.Heavy, TextSize = 17, TextColor3 = C.InkDeep, Size = UDim2.fromScale(1, 1), ZIndex = 17 }, badge)
    UIKit.button(hintButton, function()
        setOpen(not panel.Visible)
    end)
    gui.Parent = player:WaitForChild("PlayerGui")
end

local function buildShowcase()
    showcase = make("Frame", {
        Name = "Showcase",
        Position = UDim2.fromOffset(24, 58),
        Size = UDim2.new(0.4, -30, 1, -82),
        BackgroundTransparency = 1,
    }, panel)
    -- Clipped backdrop: rarity-tinted fill, spinning rays, a soft glow behind the avatar
    showcaseFill = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.InkLight }, showcase)
    UIKit.corner(showcaseFill, UDim.new(0, 32))
    UIKit.wash(showcaseFill, 0.55)
    rays = make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.42),
        Size = UDim2.fromScale(1.7, 1.7),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Rays,
        ImageTransparency = 0.45,
    }, showcaseFill)
    make("UIAspectRatioConstraint", {}, rays)
    make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromScale(0.9, 0.9),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Glow,
        ImageTransparency = 0.55,
    }, showcaseFill)

    viewport = make("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(170, 170, 170),
        LightColor = C.White,
        LightDirection = Vector3.new(-0.5, -1, 0.6),
        ZIndex = 2,
    }, showcase)
    worldModel = make("WorldModel", {}, viewport)
    local camera: Camera = make("Camera", {
        FieldOfView = 30,
        CFrame = CFrame.lookAt(Vector3.new(3.8, 1.2, -18.5), Vector3.new(0, 0.3, 0)), -- 3/4 view, whole body
    }, viewport)
    viewport.CurrentCamera = camera
    make("Part", {
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.4, 6, 6),
        CFrame = CFrame.new(0, PODIUM_TOP - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
        Anchored = true,
        Material = Enum.Material.SmoothPlastic,
        Color = Color3.fromRGB(46, 52, 96),
    }, worldModel)

    revealFlash = make("Frame", { Name = "RevealFlash", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 10 }, showcase)
    UIKit.corner(revealFlash, UDim.new(0, 32))
    local rimHolder: Frame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, showcase)
    showcaseRim = UIKit.plate(rimHolder)
    setRaySpeed(24)
end

local function buildInfo()
    local info: Frame = make("Frame", {
        Name = "Info",
        Position = UDim2.new(0.4, 10, 0, 58),
        Size = UDim2.new(0.6, -34, 1, -82),
        BackgroundTransparency = 1,
    }, panel)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9) }, info)

    nameLabel = text({
        LayoutOrder = 1,
        FontFace = F.Display,
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.White,
        Size = UDim2.new(1, 0, 0, 52),
    }, info)
    make("UITextSizeConstraint", { MaxTextSize = 52 }, nameLabel)
    nameGradient = make("UIGradient", {}, nameLabel)
    UIKit.stroke(nameLabel, C.InkDeep, 3, 0)

    local chips = row(info, 2, 26, 8)
    rarityChip, rarityText = chip(chips, C.Muted, "", 1)
    equippedChip = chip(chips, C.Teal, "EQUIPPED", 2)

    descLabel = text({
        LayoutOrder = 3,
        FontFace = F.Body,
        TextSize = 17,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = C.Cream,
        Size = UDim2.new(1, 0, 0, 40),
    }, info)

    local skills = row(info, 4, 58, 12)
    for i, slot in { "Q", "E" } :: { Types.SkillSlot } do
        local card: Frame = make("Frame", { LayoutOrder = i, Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = C.InkLight }, skills)
        UIKit.corner(card, UDim.new(0, 14))
        UIKit.wash(card, 0.75)
        local icon: ImageLabel = make("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(38, 38),
            BackgroundTransparency = 1,
        }, card)
        local key: Frame = make("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = C.Yellow, ZIndex = 3 }, card)
        UIKit.corner(key, UDim.new(0, 6))
        text({ Text = slot, FontFace = F.Heavy, TextSize = 13, TextColor3 = C.InkDeep, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, key)
        local name = text({
            FontFace = F.Bold,
            TextSize = 17,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(60, 9),
            Size = UDim2.new(1, -68, 0, 22),
        }, card)
        local cooldown = text({
            FontFace = F.Body,
            TextSize = 14,
            TextColor3 = C.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(60, 31),
            Size = UDim2.new(1, -68, 0, 18),
        }, card)
        skillCards[slot] = { icon = icon, name = name, cooldown = cooldown }
    end

    local stats = row(info, 5, 26, 8)
    for i = 1, 3 do
        local _, label = chip(stats, C.InkLight, "", i)
        label.TextColor3 = C.Cream
        label.FontFace = F.Bold
        statLabels[i] = label
    end

    -- Roll odds per tier: a bar for the chance, then every style in that tier
    local odds: Frame = make("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1 }, info)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, odds)
    local weights = Config.Styles.RarityWeights :: { [string]: number }
    local total = 0
    for _, rarity in Styles.RarityOrder do
        total += weights[rarity] or 0
    end
    for i, rarity in Styles.RarityOrder do
        local color = Styles.RarityColors[rarity]
        local share = (weights[rarity] or 0) / total
        local names = {}
        for _, style in Styles.List do
            if style.rarity == rarity then
                table.insert(names, style.name)
            end
        end
        local line: Frame = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 21), BackgroundTransparency = 1 }, odds)
        text({ Text = string.upper(rarity), FontFace = F.Heavy, TextSize = 13, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(86, 21) }, line)
        local track: Frame = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 88, 0.5, 0), Size = UDim2.fromOffset(110, 10), BackgroundColor3 = C.InkDeep }, line)
        UIKit.corner(track, UDim.new(1, 0))
        local fill: Frame = make("Frame", { Size = UDim2.fromScale(share, 1), BackgroundColor3 = color }, track)
        UIKit.corner(fill, UDim.new(1, 0))
        table.insert(oddsFills, { fill = fill, share = share })
        text({ Text = `{math.round(share * 100)}%`, FontFace = F.Display, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(200, 0), Size = UDim2.fromOffset(42, 21) }, line)
        text({
            Text = table.concat(names, ", "),
            FontFace = F.Body,
            TextSize = 14,
            TextColor3 = C.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(254, 0),
            Size = UDim2.new(1, -254, 0, 21),
        }, line)
    end

    spinButton = make("TextButton", {
        Name = "SpinButton",
        LayoutOrder = 7,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = C.Red,
        AutoButtonColor = false,
        Text = "",
        Modal = true,
    }, info)
    UIKit.wash(spinButton, 0.68)
    UIKit.plate(spinButton, nil, 0.22)
    spinSheen = UIKit.shimmer(spinButton, 1.6)
    local content: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 40),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 16,
    }, spinButton)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    spinText = text({ LayoutOrder = 1, FontFace = F.Display, TextSize = 32, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 16 }, content)
    UIKit.stroke(spinText, C.InkDeep, 3, 0.1)
    spinChip = make("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(38, 32), BackgroundColor3 = C.Yellow, ZIndex = 16 }, content)
    UIKit.corner(spinChip, UDim.new(1, 0))
    UIKit.stroke(spinChip, C.InkDeep, 2, 0.2)
    spinChipText = text({ FontFace = F.Heavy, TextSize = 17, TextColor3 = C.InkDeep, Size = UDim2.fromScale(1, 1), ZIndex = 17 }, spinChip)
    UIKit.button(spinButton, spin)
end

local function buildUI()
    buildHintButton()
    local gui: ScreenGui = make("ScreenGui", { Name = "SpinMenu", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = 5 }, nil)

    backdrop = make("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.InkDeep, BackgroundTransparency = 1, Visible = false }, gui)
    holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
        BackgroundTransparency = 1,
    }, gui)
    local boardScale: UIScale = make("UIScale", { Name = "Fit" }, holder)
    fitBoard(boardScale)
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            fitBoard(boardScale)
        end)
    end

    panel = make("Frame", {
        Name = "Panel",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.Ink,
        Visible = false,
    }, holder)
    openScale = make("UIScale", { Name = "Open" }, panel)
    UIKit.wash(panel, 0.7)
    UIKit.plate(panel, nil, 0.34)

    -- Banderitas strung across the top, gently swaying
    local bunting: ImageLabel = make("ImageLabel", {
        Name = "Bunting",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.new(1, -110, 0, 34),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Bunting,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(136, 34),
    }, panel)
    if not UIKit.reducedMotion() then
        TweenService:Create(bunting, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0.5, 0, 0, 13) }):Play()
    end

    buildShowcase()
    buildInfo()

    local close: TextButton = make("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 14),
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = C.InkLight,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 22,
    }, panel)
    UIKit.plate(close, nil, 0.16)
    text({ Text = "X", FontFace = F.Display, TextSize = 20, Size = UDim2.fromScale(1, 1), ZIndex = 23 }, close)
    UIKit.button(close, function()
        setOpen(false)
    end)

    gui.Parent = player:WaitForChild("PlayerGui")
end

function SpinController.Init()
    buildUI()
    refresh()
    local lastSpins = getSpins()
    player:GetAttributeChangedSignal("Spins"):Connect(function()
        local spins = getSpins()
        if spins > lastSpins then
            UIKit.pop(hintCount, 1.6) -- earned spins
        end
        lastSpins = spins
        refresh()
    end)
    player:GetAttributeChangedSignal("Style"):Connect(refresh)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.G or (input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible) then
            setOpen(not panel.Visible)
        end
    end)
end

return SpinController
