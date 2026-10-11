--!strict
--[[
    SpinController.luau
    Hub-only Styles menu (G or the STYLES button), in the "Kanto Night" style (UIKit), laid out on the
    1366x768 mockup and scaled to the screen:
    - your own avatar under a sodium streetlamp, looping the style's dance (StyleAnimator)
    - the style's rarity, name (chalk underline), description, skills, passives and the roll odds per tier
    - SPIN on a brushed paint plate: names shuffle and tick while the lamp flickers, then the reveal lands
      with the lamp flaring in the rarity color, a shockwave ring and a flash
      (Legendary: a double ring, a shake and a blur pulse)
    Opening blurs the world behind the menu. The SPIN button is Modal so the mouse is free even if
    the camera is mouse-locked.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local SoundController = require(script.Parent.SoundController)
local StyleAnimator = require(script.Parent.StyleAnimator)
local UIKit = require(script.Parent.UIKit)

local C, F, M, A = UIKit.Color, UIKit.Font, UIKit.Motion, UIKit.Art
local make, text, art = UIKit.make, UIKit.text, UIKit.art

local SpinController = {}

local player = Players.LocalPlayer

local DESIGN = Vector2.new(1366, 768) -- the menu is laid out at the mockup's size, then scaled to fit the screen
local PODIUM_TOP = -3 -- feet height of the preview avatar
local CONE_REST = 0.66 -- light cone transparency when the lamp is steady
local UNDERLINE = UDim2.fromScale(1.03, 0.14) -- of the name label, so it always spans the name

type SkillRow = { icon: ImageLabel, name: TextLabel, cooldown: TextLabel }

local backdrop: Frame
local flash: Frame
local holder: Frame
local panel: Frame
local openScale: UIScale
local hintGui: ScreenGui
local hintButton: TextButton
local hintCount: TextLabel
local showcase: Frame
local lamp: ImageLabel
local cone: ImageLabel
local viewport: ViewportFrame
local previewCamera: Camera
local worldModel: WorldModel
local rarityLabel: TextLabel
local equippedLabel: TextLabel
local nameLabel: TextLabel
local nameGradient: UIGradient
local nameSweep: Tween?
local underlineClip: Frame
local descLabel: TextLabel
local skillRows: { [Types.SkillSlot]: SkillRow } = {}
local statValues: { TextLabel } = {}
local spinButton: TextButton
local spinPaint: ImageLabel
local spinText: TextLabel
local spinCount: TextLabel

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

-- Frames the whole avatar (tall hats and weapons included) with headroom, feet on the light pool
local function frameAvatar(height: number)
    local h = math.max(height, 5.5) + 1.2
    local distance = h / (2 * math.tan(math.rad(previewCamera.FieldOfView / 2)))
    local center = PODIUM_TOP + h / 2 - 0.15
    previewCamera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.2, center + 0.6, -distance), Vector3.new(0, center, 0)) -- 3/4 view
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
    clone:PivotTo(CFrame.new(0, PODIUM_TOP - (box.Position.Y - size.Y / 2), 0)) -- feet on the light pool, any avatar height
    frameAvatar(size.Y)
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

-- Epic and Legendary names get a cold light passing through the letters
local function paintName(color: Color3, sweep: boolean)
    if nameSweep then
        nameSweep:Cancel()
        nameSweep = nil
    end
    nameGradient.Offset = Vector2.zero
    if not sweep then
        nameGradient.Color = ColorSequence.new(C.Chalk)
        return
    end
    local tint = C.Chalk:Lerp(color, 0.55)
    nameGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.Chalk),
        ColorSequenceKeypoint.new(0.42, C.Chalk),
        ColorSequenceKeypoint.new(0.5, tint),
        ColorSequenceKeypoint.new(0.58, C.Chalk),
        ColorSequenceKeypoint.new(1, C.Chalk),
    })
    if UIKit.reducedMotion() then return end
    nameGradient.Offset = Vector2.new(-1, 0)
    local sweepTween = TweenService:Create(nameGradient, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.6), { Offset = Vector2.new(1, 0) })
    sweepTween:Play()
    nameSweep = sweepTween
end

local function showStyle(style: Types.StyleDef, withPose: boolean)
    local color = Styles.RarityColors[style.rarity]
    nameLabel.Text = string.upper(style.name)
    paintName(color, not spinning and (style.rarity == "Epic" or style.rarity == "Legendary"))
    rarityLabel.Text = style.rarity
    rarityLabel.TextColor3 = color
    equippedLabel.Visible = style.id == equippedId() and not spinning
    descLabel.Text = style.description
    for slot, row in skillRows do
        local skill = if slot == "Q" then style.skills.Q else style.skills.E
        row.icon.Image = UIKit.Icon[skill.kind] or ""
        row.name.Text = skill.name
        row.cooldown.Text = `{skill.cooldown}s cooldown`
    end
    statValues[1].Text = `x{style.speedMult}`
    statValues[2].Text = `x{style.staminaMult}`
    statValues[3].Text = `+{style.reachBonus}`
    if withPose then
        playPose(style)
    end
end

local function refresh()
    local spins = getSpins()
    hintCount.Text = tostring(spins)

    -- The server sets Style the moment it rolls; keep the result hidden until the reveal.
    if spinning then
        spinText.Text = "ROLLING"
        spinCount.Visible = false
        spinPaint.ImageColor3 = C.Sodium:Lerp(C.Ink, 0.35)
        return
    end

    showStyle(Styles.Get(equippedId()), panel.Visible)
    local canSpin = spins >= 1
    spinText.Text = "SPIN"
    spinCount.Visible = true
    spinCount.Text = `{spins} left`
    spinPaint.ImageColor3 = if canSpin then C.Sodium else C.Dim:Lerp(C.Ink, 0.45)
end

-- Steady sodium lamp, or a flicker frame while a roll is running
local function setLamp(flicker: boolean)
    local dim = if flicker and not UIKit.reducedMotion() then math.random() * 0.5 else 0
    cone.ImageColor3 = C.Sodium
    cone.ImageTransparency = CONE_REST + dim * (1 - CONE_REST)
    lamp.ImageTransparency = 0.1 + dim
end

local function setOpen(open: boolean)
    if open == panel.Visible then return end
    -- The skill bar peeks out under the menu and would spoil a roll's new skill names
    local skillBar = player.PlayerGui:FindFirstChild("SkillBar")
    if skillBar and skillBar:IsA("ScreenGui") then
        skillBar.Enabled = not open
    end
    hintGui.Enabled = not open -- the menu has its own close; the button would sit over the rarity line
    UIKit.blur(open)
    if open then
        panel.Visible = true
        backdrop.Visible = true
        TweenService:Create(backdrop, M.Fade, { BackgroundTransparency = 0.1 }):Play()
        openScale.Scale = 0.97
        panel.Position = UDim2.fromOffset(0, 16)
        TweenService:Create(openScale, M.Snap, { Scale = 1 }):Play()
        TweenService:Create(panel, M.Slide, { Position = UDim2.fromOffset(0, 0) }):Play()
        UIKit.wipe(underlineClip, UNDERLINE, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.1)) -- chalk drawn under the name
        setLamp(false)
        refresh()
        if UserInputService.GamepadEnabled then
            GuiService.SelectedObject = spinButton
        end
    else
        TweenService:Create(backdrop, M.Quick, { BackgroundTransparency = 1 }):Play()
        local shrink = TweenService:Create(openScale, M.Quick, { Scale = 0.98 })
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
    UIKit.pop(nameLabel, 1.15)
    UIKit.pop(rarityLabel, 1.25)
    UIKit.pop(viewport, 1.05)
    UIKit.shockwave(showcase, color, if big then 2.2 else 1.6)
    UIKit.wipe(underlineClip, UNDERLINE)

    -- The lamp flares in the rarity color, then settles back to sodium
    cone.ImageColor3 = color
    cone.ImageTransparency = if big then 0.1 else 0.35
    lamp.ImageTransparency = 0
    TweenService:Create(cone, TweenInfo.new(if big then 1.2 else 0.7, Enum.EasingStyle.Quad), { ImageColor3 = C.Sodium, ImageTransparency = CONE_REST }):Play()

    if style.rarity == "Legendary" then
        SoundController.PlaySFX("RevealBoom", Vector2.new(1, 1))
        task.delay(0.12, UIKit.shockwave, showcase, C.White, 2.6)
        UIKit.shake(holder, 6)
        UIKit.blur(true, true)
    end
    SoundController.PlaySFX(if big then "TubigFanfare" else "CheckpointChime", if style.rarity == "Rare" then Vector2.new(1.15, 1.2) else nil)

    flash.BackgroundColor3 = color:Lerp(C.White, 0.3)
    flash.BackgroundTransparency = if big then 0.55 else 0.8
    flash.Visible = true
    local fade = TweenService:Create(flash, TweenInfo.new(if big then 0.7 else 0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
    fade.Completed:Once(function()
        flash.Visible = false
    end)
    fade:Play()
end

local function spin()
    if spinning or getSpins() < 1 then return end
    spinning = true
    refresh()

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
        UIKit.pop(nameLabel, 1.04)
        setLamp(true)
        local pitch = 1.25 - math.min(os.clock() - started, 1.4) * 0.2 -- ticks drop in pitch as the roll slows
        SoundController.PlaySFX("SpinTick", Vector2.new(pitch, pitch))
        task.wait(0.06 + (os.clock() - started) * 0.06)
    end

    -- A beat of tension (the lamp cuts out) before the big ones land
    local style = if result then Styles.Get(result) else nil
    if style and (style.rarity == "Epic" or style.rarity == "Legendary") then
        cone.ImageTransparency = 0.95
        lamp.ImageTransparency = 0.8
        UIKit.shake(showcase, 3)
        task.wait(0.25)
    end

    spinning = false
    refresh()
    if style then
        reveal(style)
    else
        setLamp(false)
    end
end

-- Fit the mockup into the core-UI safe area (below the Roblox top bar)
local function fitBoard(gui: ScreenGui, scale: UIScale)
    local area = gui.AbsoluteSize
    if area.X > 0 and area.Y > 0 then
        scale.Scale = math.min(area.X / DESIGN.X, area.Y / DESIGN.Y)
    end
end

local function buildHintButton()
    -- Own ScreenGui inside the core-UI safe area (the menu's backdrop is full-bleed)
    local gui: ScreenGui = make("ScreenGui", { Name = "StylesButton", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets }, nil)
    hintGui = gui
    local slot: Frame = make("Frame", {
        Position = UDim2.fromOffset(18, 18), -- top-left; bottom-left is the touch thumbstick
        Size = UDim2.fromOffset(176, 50),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(slot) -- the button itself carries the hover/press scale
    hintButton = make("TextButton", {
        Name = "StylesButton",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    }, slot)
    art(A.Patch, { ImageColor3 = C.Patch, ImageTransparency = 0.12 }, hintButton)
    text({ Text = "STYLES", FontFace = F.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 2 }, hintButton)
    hintCount = text({
        Text = "0",
        FontFace = F.Number,
        TextSize = 22,
        TextColor3 = C.Sodium,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.fromOffset(40, 50),
        ZIndex = 2,
    }, hintButton)
    UIKit.button(hintButton, function()
        setOpen(not panel.Visible)
    end)
    gui.Parent = player:WaitForChild("PlayerGui")
end

-- The avatar on the right, under the streetlamp. Image positions include the blur margins of the art.
local function buildShowcase()
    lamp = art(A.Lamp, { Position = UDim2.fromOffset(882, -52), Size = UDim2.fromOffset(206, 88), ImageColor3 = C.Sodium, ImageTransparency = 0.1 }, panel)
    cone = art(A.Cone, { Position = UDim2.fromOffset(595, -40), Size = UDim2.fromOffset(780, 810), ImageColor3 = C.Sodium, ImageTransparency = CONE_REST }, panel)
    art(A.Pool, { Position = UDim2.fromOffset(672, 648), Size = UDim2.fromOffset(626, 134), ImageColor3 = C.Sodium, ImageTransparency = 0.7 }, panel)
    art(A.Shadow, { Position = UDim2.fromOffset(798, 680), Size = UDim2.fromOffset(368, 68), ImageColor3 = Color3.new(), ImageTransparency = 0.25 }, panel)

    -- Wider than the mockup's 475 px avatar box so wide dance poses aren't cut off at the edges
    showcase = make("Frame", { Name = "Showcase", Position = UDim2.fromOffset(635, 66), Size = UDim2.fromOffset(700, 650), BackgroundTransparency = 1, ZIndex = 2 }, panel)
    viewport = make("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(78, 80, 92),
        LightColor = Color3.fromRGB(255, 208, 150), -- sodium lamp overhead
        LightDirection = Vector3.new(-0.25, -1, 0.35),
        ZIndex = 2,
    }, showcase)
    worldModel = make("WorldModel", {}, viewport)
    previewCamera = make("Camera", { FieldOfView = 30 }, viewport)
    viewport.CurrentCamera = previewCamera
    frameAvatar(5.5)
end

local function buildInfo()
    local function label(props: { [string]: any }): TextLabel
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        props.ZIndex = 3
        return text(props, panel)
    end

    local rarityLine: Frame = make("Frame", { Position = UDim2.fromOffset(76, 70), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3 }, panel)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, rarityLine)
    rarityLabel = text({ LayoutOrder = 1, FontFace = F.Bold, TextSize = 20, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, rarityLine)
    equippedLabel = text({ LayoutOrder = 2, Text = "equipped", FontFace = F.Body, TextSize = 20, TextColor3 = C.Dim, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, rarityLine)

    -- The mockup's 112 px name is past Roblox's TextSize cap: the label sits at 100 in a holder scaled
    -- up to match. The label hugs its text, so the chalk underline (a child) always fits the name.
    local big = 112 * UIKit.EM / 100
    local nameHolder: Frame = make("Frame", { Position = UDim2.fromOffset(72, 150 - 50 * big), Size = UDim2.fromOffset(564 / big, 100), BackgroundTransparency = 1, ZIndex = 3 }, panel)
    make("UIScale", { Scale = big }, nameHolder)
    nameLabel = text({ FontFace = F.Display, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(0, 100), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3 }, nameHolder)
    nameLabel.TextSize = 100
    nameGradient = make("UIGradient", {}, nameLabel)
    underlineClip = make("Frame", { Position = UDim2.fromScale(-0.015, 0.88), Size = UNDERLINE, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3 }, nameLabel)
    art(A.Underline, { ImageColor3 = C.Chalk, ZIndex = 3 }, underlineClip)

    descLabel = label({ FontFace = F.Body, TextSize = 19, TextColor3 = C.Dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(76, 240), Size = UDim2.fromOffset(520, 52) })

    for i, slot in { "Q", "E" } :: { Types.SkillSlot } do
        local y = 305 + (i - 1) * 64
        art(A.KeyBox, { Position = UDim2.fromOffset(70, y), Size = UDim2.fromOffset(55, 55), ImageColor3 = C.Chalk, ZIndex = 3 }, panel)
        label({ Text = slot, FontFace = F.Number, TextSize = 22, TextColor3 = C.Sodium, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(70, y), Size = UDim2.fromOffset(55, 55) })
        skillRows[slot] = {
            icon = art("", { Position = UDim2.fromOffset(136, y + 10), Size = UDim2.fromOffset(36, 36), ImageColor3 = C.Chalk, ZIndex = 3 }, panel),
            name = label({ FontFace = F.Bold, TextSize = 22, Position = UDim2.fromOffset(188, y + 3), Size = UDim2.fromOffset(400, 30) }),
            cooldown = label({ FontFace = F.Body, TextSize = 15, TextColor3 = C.Dim, Position = UDim2.fromOffset(188, y + 29), Size = UDim2.fromOffset(400, 22) }),
        }
    end

    -- Passives: big number over a small label
    for i, name in { "Speed", "Stamina", "Reach" } do
        local x = 76 + (i - 1) * 150
        statValues[i] = label({ FontFace = F.Number, TextSize = 34, Position = UDim2.fromOffset(x, 446), Size = UDim2.fromOffset(140, 44) })
        label({ Text = name, FontFace = F.Body, TextSize = 16, TextColor3 = C.Dim, Position = UDim2.fromOffset(x, 488), Size = UDim2.fromOffset(140, 22) })
    end

    art(A.Divider, { Position = UDim2.fromOffset(70, 520), Size = UDim2.fromOffset(482, 14), ImageColor3 = C.Chalk, ImageTransparency = 0.65, ZIndex = 3 }, panel)

    -- Roll odds per tier, two columns: chance in the rarity color, then every style in that tier
    local weights = Config.Styles.RarityWeights :: { [string]: number }
    local total = 0
    for _, rarity in Styles.RarityOrder do
        total += weights[rarity] or 0
    end
    for i, rarity in Styles.RarityOrder do
        local x, y = 76 + (i - 1) % 2 * 250, 546 + (i - 1) // 2 * 44
        local names = {}
        for _, style in Styles.List do
            if style.rarity == rarity then
                table.insert(names, style.name)
            end
        end
        label({ Text = `{math.round((weights[rarity] or 0) / total * 100)}%`, FontFace = F.Number, TextSize = 18, TextColor3 = Styles.RarityColors[rarity], Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(50, 24) })
        label({ Text = rarity, FontFace = F.Semi, TextSize = 16, Position = UDim2.fromOffset(x + 52, y - 1), Size = UDim2.fromOffset(190, 22) })
        label({ Text = table.concat(names, ", "), FontFace = F.Body, TextSize = 13, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(x + 52, y + 19), Size = UDim2.fromOffset(190, 18) })
    end

    spinButton = make("TextButton", {
        Name = "SpinButton",
        Position = UDim2.fromOffset(67, 641),
        Size = UDim2.fromOffset(358, 86),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Modal = true,
        ZIndex = 3,
    }, panel)
    spinPaint = art(A.Paint, { ImageColor3 = C.Sodium, ZIndex = 3 }, spinButton)
    spinText = text({ FontFace = F.Display, TextSize = 40, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(39, 15), Size = UDim2.fromOffset(200, 56), ZIndex = 4 }, spinButton)
    spinCount = text({ FontFace = F.Bold, TextSize = 17, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(319, 30), Size = UDim2.fromOffset(100, 26), ZIndex = 4 }, spinButton)
    UIKit.button(spinButton, spin)
end

local function buildUI()
    buildHintButton()
    -- Full-bleed night + reveal flash behind the menu; the menu itself stays clear of the core UI
    local back: ScreenGui = make("ScreenGui", { Name = "SpinBackdrop", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = 4 }, nil)
    backdrop = make("Frame", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, back)
    flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false }, back)
    back.Parent = player:WaitForChild("PlayerGui")

    local gui: ScreenGui = make("ScreenGui", { Name = "SpinMenu", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 5 }, nil)
    holder = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
        BackgroundTransparency = 1,
    }, gui)
    local boardScale: UIScale = make("UIScale", { Name = "Fit" }, holder)
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        fitBoard(gui, boardScale)
    end)

    panel = make("Frame", { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, holder)
    openScale = make("UIScale", { Name = "Open" }, panel)

    buildShowcase()
    buildInfo()

    local close: TextButton = make("TextButton", {
        Name = "Close",
        Position = UDim2.fromOffset(1290, 18),
        Size = UDim2.fromOffset(44, 56),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        FontFace = F.Body,
        Text = "×",
        TextSize = math.round(38 * UIKit.EM),
        TextColor3 = C.Dim,
        ZIndex = 4,
    }, panel)
    UIKit.button(close, function()
        setOpen(false)
    end)

    gui.Parent = player:WaitForChild("PlayerGui")
    fitBoard(gui, boardScale)
end

function SpinController.Init()
    buildUI()
    refresh()
    local lastSpins = getSpins()
    player:GetAttributeChangedSignal("Spins"):Connect(function()
        local spins = getSpins()
        if spins > lastSpins then
            UIKit.pop(hintCount, 1.3) -- earned spins
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
