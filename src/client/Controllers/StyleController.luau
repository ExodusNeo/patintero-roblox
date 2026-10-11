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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local MovementController = require(script.Parent.MovementController)
local SoundController = require(script.Parent.SoundController)
local TouchLayout = require(script.Parent.TouchLayout)
local StyleAnimator = require(script.Parent.StyleAnimator)
local SkillEffects = require(script.Parent.SkillEffects)

local StyleController = {}

local player = Players.LocalPlayer
local lastCast: { [string]: number } = {}

type SlotUI = { name: TextLabel, shade: Frame, timer: TextLabel }
local slotUI: { [string]: SlotUI } = {}
local styleLabel: TextLabel

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
    local gui = Instance.new("ScreenGui")
    gui.Name = "SkillBar"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0.5, 1)
    bar.Position = UDim2.new(0.5, 0, 1, -75)
    bar.Size = UDim2.fromOffset(268, 56)
    bar.BackgroundTransparency = 1
    bar.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = bar

    styleLabel = Instance.new("TextLabel")
    styleLabel.AnchorPoint = Vector2.new(0.5, 1)
    styleLabel.Position = UDim2.new(0.5, 0, 1, -135)
    styleLabel.Size = UDim2.fromOffset(268, 22)
    styleLabel.BackgroundTransparency = 1
    styleLabel.Font = Enum.Font.GothamBlack
    styleLabel.TextSize = 16
    styleLabel.TextStrokeTransparency = 0.5
    styleLabel.Parent = gui

    for _, slot in SLOTS do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromOffset(130, 56)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        frame.BackgroundTransparency = 0.25
        frame.ClipsDescendants = true
        frame.Parent = bar
        Instance.new("UICorner").Parent = frame

        local shade = Instance.new("Frame")
        shade.AnchorPoint = Vector2.new(0, 1)
        shade.Position = UDim2.fromScale(0, 1)
        shade.Size = UDim2.fromScale(1, 0)
        shade.BackgroundColor3 = Color3.new(0, 0, 0)
        shade.BackgroundTransparency = 0.35
        shade.BorderSizePixel = 0
        shade.Parent = frame

        local key = Instance.new("TextLabel")
        key.Position = UDim2.fromOffset(8, 4)
        key.Size = UDim2.fromOffset(30, 18)
        key.BackgroundTransparency = 1
        key.Font = Enum.Font.GothamBold
        key.TextSize = 14
        key.TextColor3 = Color3.fromRGB(255, 215, 0)
        key.TextXAlignment = Enum.TextXAlignment.Left
        key.Text = `[{slot}]`
        key.Parent = frame

        local name = Instance.new("TextLabel")
        name.Position = UDim2.fromOffset(8, 24)
        name.Size = UDim2.new(1, -16, 0, 24)
        name.BackgroundTransparency = 1
        name.Font = Enum.Font.GothamBold
        name.TextSize = 15
        name.TextColor3 = Color3.new(1, 1, 1)
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = frame

        local timer = Instance.new("TextLabel")
        timer.Position = UDim2.new(1, -44, 0, 4)
        timer.Size = UDim2.fromOffset(36, 18)
        timer.BackgroundTransparency = 1
        timer.Font = Enum.Font.GothamBold
        timer.TextSize = 14
        timer.TextColor3 = Color3.new(1, 1, 1)
        timer.TextXAlignment = Enum.TextXAlignment.Right
        timer.Parent = frame

        slotUI[slot] = { name = name, shade = shade, timer = timer }
    end
end

local function refresh()
    local style = currentStyle()
    table.clear(lastCast)
    styleLabel.Text = `{string.upper(style.name)}  ·  {style.rarity}`
    styleLabel.TextColor3 = Styles.RarityColors[style.rarity]
    for _, slot in SLOTS do
        local skillName = skillFor(style, slot).name
        slotUI[slot].name.Text = skillName
        ContextActionService:SetTitle(`Skill{slot}`, skillName) -- touch button label
    end
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
            ui.timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
        end
    end)
end

return StyleController
