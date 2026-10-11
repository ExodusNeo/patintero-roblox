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

type SlotUI = { root: Frame, icon: ImageLabel, edge: ImageLabel, timer: TextLabel, glow: ImageLabel, ready: boolean }
local slotUI: { [string]: SlotUI } = {}
local styleName: TextLabel
local rarityColor = UIKit.Color.Chalk

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
    local C, F, A, make, text, art = UIKit.Color, UIKit.Font, UIKit.Art, UIKit.make, UIKit.text, UIKit.art
    local gui: ScreenGui = make("ScreenGui", { Name = "SkillBar", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets }, nil)

    local bar: Frame = make("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -56),
        Size = UDim2.fromOffset(152, 94),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(bar)

    -- Style name in its rarity color over two chalked slots
    styleName = text({ FontFace = F.Number, TextSize = 15, Size = UDim2.new(1, 60, 0, 20), Position = UDim2.fromOffset(-30, 0) }, bar)
    UIKit.stroke(styleName, C.Ink, 1, 0.4) -- rarity colors can match the ground (Legendary on a yellow pad)
    local row: Frame = make("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1 }, bar)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, row)

    for i, slot in SLOTS do
        local root: Frame = make("Frame", { Name = `Slot{slot}`, LayoutOrder = i, Size = UDim2.fromOffset(68, 68), BackgroundTransparency = 1 }, row)
        -- Glow that flashes behind the slot when the skill is ready again
        local glow = art(UIKit.Image.Glow, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 120), ImageTransparency = 1 }, root)
        art(A.SlotPatch, { Position = UDim2.fromOffset(-2, -2), Size = UDim2.fromOffset(72, 72), ImageColor3 = C.Patch, ImageTransparency = 0.22 }, root)
        local edge = art(A.SlotEdge, { Position = UDim2.fromOffset(-3.5, -3.5), Size = UDim2.fromOffset(75, 75), ImageColor3 = C.Chalk, ZIndex = 2 }, root)
        local icon = art("", { Position = UDim2.fromOffset(15, 15), Size = UDim2.fromOffset(38, 38), ImageColor3 = C.Chalk, ZIndex = 2 }, root)
        local timer = text({ FontFace = F.Display, TextSize = 28, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, root)
        text({ Text = slot, FontFace = F.Number, TextSize = 14, TextColor3 = C.Sodium, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(9, 4), Size = UDim2.fromOffset(16, 18), ZIndex = 3 }, root)
        slotUI[slot] = { root = root, icon = icon, edge = edge, timer = timer, glow = glow, ready = true }
    end
    gui.Parent = player:WaitForChild("PlayerGui")
end

local function refresh()
    local style = currentStyle()
    rarityColor = Styles.RarityColors[style.rarity]
    table.clear(lastCast)
    styleName.Text = string.upper(style.name)
    styleName.TextColor3 = rarityColor
    for _, slot in SLOTS do
        local skill = skillFor(style, slot)
        local ui = slotUI[slot]
        ui.icon.Image = UIKit.Icon[skill.kind] or ""
        UIKit.pop(ui.root, 1.06)
        ContextActionService:SetTitle(`Skill{slot}`, skill.name) -- touch button label
    end
end

-- Skill came back: snap the slot, flash its chalk edge in the rarity color and a faint glow behind it
local function ping(ui: SlotUI)
    UIKit.pop(ui.root, 1.08)
    ui.edge.ImageColor3 = rarityColor
    TweenService:Create(ui.edge, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { ImageColor3 = UIKit.Color.Chalk }):Play()
    ui.glow.ImageColor3 = rarityColor
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
            ui.timer.Text = if remaining > 0 then tostring(math.ceil(remaining)) else ""
            ui.icon.ImageTransparency = if remaining > 0 then 0.7 else 0
            local ready = remaining <= 0
            if ready and not ui.ready then
                ping(ui)
            end
            ui.ready = ready
        end
    end)
end

return StyleController
