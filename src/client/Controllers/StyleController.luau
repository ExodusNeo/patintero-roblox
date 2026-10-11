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

type SlotUI = { root: Frame, icon: ImageLabel, rim: ImageLabel, shade: Frame, timer: TextLabel, name: TextLabel, glow: ImageLabel, ready: boolean }
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
    UIKit.pop(slotUI[slot].root, 0.82)
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
        Position = UDim2.new(0.5, 0, 1, -52),
        Size = UDim2.fromOffset(200, 126),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(bar)

    -- Style name in sign lettering, rarity beside it
    local title: Frame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
    }, bar)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, title)
    styleName = text({ FontFace = F.Display, TextSize = 22, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, title)
    UIKit.stroke(styleName, C.InkDeep, 2.5, 0.1)
    styleRarity = text({ FontFace = F.Heavy, TextSize = 13, TextColor3 = C.Cream, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }, title)
    UIKit.stroke(styleRarity, C.InkDeep, 2, 0.3)

    local row: Frame = make("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1 }, bar)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder }, row)

    for i, slot in SLOTS do
        local root: Frame = make("Frame", { Name = `Slot{slot}`, LayoutOrder = i, Size = UDim2.fromOffset(76, 92), BackgroundTransparency = 1 }, row)
        -- Glow that flashes behind the card when the skill is ready again
        local glow: ImageLabel = make("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(38, 38),
            Size = UDim2.fromOffset(150, 150),
            BackgroundTransparency = 1,
            Image = UIKit.Image.Glow,
            ImageTransparency = 1,
        }, root)
        -- CanvasGroup clips the cooldown shade to the rounded card
        local card: CanvasGroup = make("CanvasGroup", { Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.05 }, root)
        UIKit.corner(card, UDim.new(0, 19))
        UIKit.wash(card, 0.7)
        local icon: ImageLabel = make("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(48, 48),
            BackgroundTransparency = 1,
        }, card)
        local shade: Frame = make("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.InkDeep, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 2 }, card)
        local timer = text({ FontFace = F.Display, TextSize = 30, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, card)
        UIKit.stroke(timer, C.InkDeep, 2.5, 0.1)
        -- Rim lives outside the CanvasGroup so it isn't clipped
        local rimHolder: Frame = make("Frame", { Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, ZIndex = 5 }, root)
        local rim = UIKit.plate(rimHolder, nil, 0.18)
        local key: Frame = make("Frame", { Position = UDim2.fromOffset(-7, -7), Size = UDim2.fromOffset(26, 24), BackgroundColor3 = C.Yellow, ZIndex = 30 }, root)
        UIKit.corner(key, UDim.new(0, 8))
        UIKit.stroke(key, C.InkDeep, 2, 0.2)
        text({ Text = slot, FontFace = F.Heavy, TextSize = 15, TextColor3 = C.InkDeep, Size = UDim2.fromScale(1, 1), ZIndex = 31 }, key)
        local name = text({
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.fromOffset(110, 16),
            FontFace = F.Bold,
            TextSize = 14,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, root)
        UIKit.stroke(name, C.InkDeep, 2, 0.3)
        slotUI[slot] = { root = root, icon = icon, rim = rim, shade = shade, timer = timer, name = name, glow = glow, ready = true }
    end
    gui.Parent = player:WaitForChild("PlayerGui")
end

local function refresh()
    local style = currentStyle()
    local color = Styles.RarityColors[style.rarity]
    table.clear(lastCast)
    styleName.Text = string.upper(style.name)
    styleName.TextColor3 = color
    styleRarity.Text = style.rarity
    for _, slot in SLOTS do
        local skill = skillFor(style, slot)
        local ui = slotUI[slot]
        ui.name.Text = skill.name
        ui.icon.Image = UIKit.Icon[skill.kind] or ""
        ui.icon.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15)
        ui.rim.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
        UIKit.pop(ui.root, 1.15)
        ContextActionService:SetTitle(`Skill{slot}`, skill.name) -- touch button label
    end
end

-- Skill came back: punch the card and flash its glow
local function ping(ui: SlotUI)
    UIKit.pop(ui.root, 1.18)
    ui.glow.ImageColor3 = ui.icon.ImageColor3
    ui.glow.ImageTransparency = 0.15
    ui.glow.Size = UDim2.fromOffset(90, 90)
    TweenService:Create(ui.glow, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { ImageTransparency = 1, Size = UDim2.fromOffset(170, 170) }):Play()
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
