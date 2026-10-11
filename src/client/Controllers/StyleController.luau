--!strict
--[[
    StyleController.luau
    Q/E skill input with local cooldown prediction, the skill bar HUD, and every player's casts
    (SkillCast from the server): the style's own animation (StyleAnimator), effects (SkillEffects) and sound.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local MovementController = require(script.Parent.MovementController)
local SoundController = require(script.Parent.SoundController)
local TouchLayout = require(script.Parent.TouchLayout)
local StyleAnimator = require(script.Parent.StyleAnimator)
local SkillEffects = require(script.Parent.SkillEffects)
local UIKit = require(script.Parent.UIKit)

local StyleController = {}

local player = Players.LocalPlayer
local lastCast: { [string]: number } = {}

type SlotUI = { root: Frame, icon: ImageLabel, edge: UIStroke, shade: Frame, timer: TextLabel, name: TextLabel, glow: ImageLabel, ready: boolean }
local slotUI: { [string]: SlotUI } = {}
local styleName: TextLabel
local styleRarity: TextLabel

local SLOTS: { Types.SkillSlot } = { "Q", "E" }

-- Cast sound per skill kind (names from SoundController), with a pitch range for variety
local SKILL_SFX: { [Types.SkillKind]: { sound: string, pitch: Vector2 } } = {
    Dash = { sound = "DashWhoosh", pitch = Vector2.new(0.95, 1.1) },
    Blink = { sound = "BlinkZap", pitch = Vector2.new(1, 1.15) },
    Haste = { sound = "DashWhoosh", pitch = Vector2.new(1.25, 1.4) },
    SecondWind = { sound = "CheckpointChime", pitch = Vector2.new(1.2, 1.3) },
    LongArm = { sound = "SlideWhoosh", pitch = Vector2.new(0.7, 0.8) },
    Slow = { sound = "FreezeIce", pitch = Vector2.new(0.95, 1.05) },
    Veil = { sound = "BlinkZap", pitch = Vector2.new(0.55, 0.65) },
}
local ICE_COLOR = Color3.fromRGB(150, 215, 255)

-- Your own screen gets an icy tint while you're slowed (others see a highlight on you instead)
local slowedTint = Instance.new("ColorCorrectionEffect")
slowedTint.Name = "SlowedTint"
slowedTint.TintColor = Color3.fromRGB(200, 230, 255)
slowedTint.Saturation = -0.35
slowedTint.Enabled = false

local function currentStyle(): Types.StyleDef
    return Styles.Get(player:GetAttribute("Style") :: string?)
end

local function skillFor(style: Types.StyleDef, slot: Types.SkillSlot): Types.SkillDef
    return if slot == "Q" then style.skills.Q else style.skills.E
end

local function cast(slot: Types.SkillSlot)
    local style = currentStyle()
    local skill = skillFor(style, slot)
    local now = os.clock()
    if now - (lastCast[slot] or -math.huge) < skill.cooldown then return end

    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if not character or not humanoid or humanoid.Health <= 0 then return end

    lastCast[slot] = now
    StyleAnimator.Play(character, `{style.id}_{slot}`) -- predicted; others play it when SkillCast arrives
    UIKit.pop(slotUI[slot].root, 0.92)
    if skill.kind == "Dash" then
        MovementController.Dash(skill.power or 55, skill.duration or 0.2)
    elseif skill.kind == "Blink" then
        MovementController.Blink(skill.power or 14)
    elseif skill.kind == "SecondWind" then
        MovementController.RestoreStamina(skill.power or 50)
    end
    Remotes.GetEvent("UseSkill"):FireServer(slot)
end

-- Slowed / frozen characters (SlowMult set by the server) glow icy for everyone else.
local function updateSlowFX(character: Model, isLocal: boolean)
    local mult = character:GetAttribute("SlowMult") :: number?
    if isLocal then
        slowedTint.Enabled = mult ~= nil
        return
    end
    local existing = character:FindFirstChild("SlowedFX") :: Highlight?
    if mult == nil then
        if existing then
            existing:Destroy()
        end
        return
    end
    local highlight = existing or Instance.new("Highlight")
    highlight.Name = "SlowedFX"
    highlight.FillColor = ICE_COLOR
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0.3
    highlight.FillTransparency = if mult <= 0 then 0.25 else 0.6 -- frozen looks solid ice
    highlight.Parent = character
end

local function watchSlows(other: Player)
    local function onCharacter(character: Model)
        character:GetAttributeChangedSignal("SlowMult"):Connect(function()
            updateSlowFX(character, other == player)
        end)
        updateSlowFX(character, other == player)
    end
    other.CharacterAdded:Connect(onCharacter)
    if other.Character then
        onCharacter(other.Character)
    end
end

-- Other players see a veiled caster as nearly invisible (local-only transparency).
local function veil(character: Model, duration: number)
    local function setAll(value: number)
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = value
            end
        end
    end
    setAll(0.85)
    task.delay(duration, setAll, 0)
end

local function onSkillCast(casterUserId: any, styleId: any, slot: any, position: any)
    if typeof(position) ~= "Vector3" or (slot ~= "Q" and slot ~= "E") then return end
    local style = Styles.Get(if typeof(styleId) == "string" then styleId else nil)
    local skill = skillFor(style, slot)

    local caster = if typeof(casterUserId) == "number" then Players:GetPlayerByUserId(casterUserId) else nil
    local casterCharacter = if caster then caster.Character else nil

    SkillEffects.Play(style.id, slot, skill, casterCharacter, position)
    local sfx = SKILL_SFX[skill.kind]
    SoundController.PlaySpatialSFX(sfx.sound, position, sfx.pitch)

    if not casterCharacter or caster == player then return end
    StyleAnimator.Play(casterCharacter, `{style.id}_{slot}`)
    if skill.kind == "Veil" then
        veil(casterCharacter, skill.duration or 2)
    end
end

local function buildUI()
    local C, F, make, text = UIKit.Color, UIKit.Font, UIKit.make, UIKit.text
    local gui: ScreenGui = make("ScreenGui", { Name = "SkillBar", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets }, nil)

    local bar: Frame = make("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -48),
        Size = UDim2.fromOffset(200, 118),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(bar)

    -- Style name on the scoreboard face, rarity beside it in its color
    local title: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
    }, bar)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, title)
    styleName = text({ FontFace = F.Display, TextSize = 20, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, title)
    UIKit.stroke(styleName, C.Deep, 1.5, 0.3)
    styleRarity = text({ FontFace = F.Label, TextSize = 13, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }, title)
    UIKit.stroke(styleRarity, C.Deep, 1.5, 0.3)

    local row: Frame = make("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1 }, bar)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, row)

    for i, slot in SLOTS do
        local root: Frame = make("Frame", { Name = `Slot{slot}`, LayoutOrder = i, Size = UDim2.fromOffset(72, 88), BackgroundTransparency = 1 }, row)
        -- Glow that flashes behind the card when the skill is ready again
        local glow: ImageLabel = make("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(36, 36),
            Size = UDim2.fromOffset(120, 120),
            BackgroundTransparency = 1,
            Image = UIKit.Image.Glow,
            ImageTransparency = 1,
        }, root)
        -- CanvasGroup clips the cooldown shade to the card's corners
        local card: CanvasGroup = make("CanvasGroup", { Size = UDim2.fromOffset(72, 72), BackgroundColor3 = C.Slab, BackgroundTransparency = 0.05 }, root)
        UIKit.wash(card, 0.75)
        UIKit.corner(card, 4)
        -- The edge lives on a holder outside the CanvasGroup so the group can't clip it
        local edgeHolder: Frame = make("Frame", { Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 5 }, root)
        UIKit.corner(edgeHolder, 4)
        local edge = UIKit.stroke(edgeHolder, C.Steel, 1, 0.05)
        local icon: ImageLabel = make("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.fromOffset(42, 42),
            BackgroundTransparency = 1,
        }, card)
        local shade: Frame = make("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.Deep, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2 }, card)
        local timer = text({ FontFace = F.Display, TextSize = 28, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, card)
        local key: Frame = make("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.Deep, ZIndex = 4 }, card)
        UIKit.corner(key, 2)
        UIKit.stroke(key, C.Steel, 1, 0)
        text({ Text = slot, FontFace = F.Display, TextSize = 13, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, key)
        local name = text({
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.fromOffset(110, 14),
            FontFace = F.Bold,
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, root)
        UIKit.stroke(name, C.Deep, 1.5, 0.3)
        slotUI[slot] = { root = root, icon = icon, edge = edge, shade = shade, timer = timer, name = name, glow = glow, ready = true }
    end
    gui.Parent = player:WaitForChild("PlayerGui")
end

local function refresh()
    local style = currentStyle()
    local color = Styles.RarityColors[style.rarity]
    table.clear(lastCast)
    styleName.Text = string.upper(style.name)
    styleRarity.Text = string.upper(style.rarity)
    styleRarity.TextColor3 = color
    for _, slot in SLOTS do
        local skill = skillFor(style, slot)
        local ui = slotUI[slot]
        ui.name.Text = skill.name
        ui.icon.Image = UIKit.Icon[skill.kind] or ""
        ui.icon.ImageColor3 = color:Lerp(UIKit.Color.Chalk, 0.4)
        ui.edge.Color = color:Lerp(UIKit.Color.Steel, 0.55)
        UIKit.pop(ui.root, 1.06)
        ContextActionService:SetTitle(`Skill{slot}`, skill.name) -- touch button label
    end
end

-- Skill came back: snap the card, flash its edge in the rarity color and a faint glow behind it
local function ping(ui: SlotUI)
    local rest = ui.edge.Color
    UIKit.pop(ui.root, 1.08)
    ui.edge.Color = ui.icon.ImageColor3
    ui.edge.Thickness = 2
    TweenService:Create(ui.edge, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Color = rest, Thickness = 1 }):Play()
    ui.glow.ImageColor3 = ui.icon.ImageColor3
    ui.glow.ImageTransparency = 0.55
    ui.glow.Size = UDim2.fromOffset(80, 80)
    TweenService:Create(ui.glow, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { ImageTransparency = 1, Size = UDim2.fromOffset(130, 130) }):Play()
end

local function bindSkill(slot: Types.SkillSlot, key: Enum.KeyCode, gamepadButton: Enum.KeyCode)
    ContextActionService:BindAction(`Skill{slot}`, function(_, inputState: Enum.UserInputState)
        if inputState == Enum.UserInputState.Begin then
            cast(slot)
        end
        return Enum.ContextActionResult.Pass
    end, true, key, gamepadButton)
    TouchLayout.place(`Skill{slot}`)
end

function StyleController.Init()
    buildUI()
    bindSkill("Q", Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
    bindSkill("E", Enum.KeyCode.E, Enum.KeyCode.ButtonY)
    refresh()
    player:GetAttributeChangedSignal("Style"):Connect(refresh)

    Remotes.GetEvent("SkillCast").OnClientEvent:Connect(onSkillCast)

    slowedTint.Parent = Workspace.CurrentCamera
    Players.PlayerAdded:Connect(watchSlows)
    for _, other in Players:GetPlayers() do
        watchSlows(other)
    end

    RunService.RenderStepped:Connect(function()
        local style = currentStyle()
        local now = os.clock()
        for _, slot in SLOTS do
            local cooldown = skillFor(style, slot).cooldown
            local remaining = math.max(cooldown - (now - (lastCast[slot] or -math.huge)), 0)
            local ui = slotUI[slot]
            ui.shade.Size = UDim2.fromScale(1, remaining / cooldown)
            ui.timer.Text = if remaining > 0 then tostring(math.ceil(remaining)) else ""
            ui.icon.ImageTransparency = if remaining > 0 then 0.55 else 0
            local ready = remaining <= 0
            if ready and not ui.ready then
                ping(ui)
            end
            ui.ready = ready
        end
    end)
end

return StyleController
