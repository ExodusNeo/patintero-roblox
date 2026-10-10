--!strict
--[[
    SpinController.luau
    Hub-only style menu (toggle with G): shows the equipped style, spins left, and rolls a new style.
    The SPIN button is Modal so the mouse is free even if the camera is mouse-locked.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local SoundController = require(script.Parent.SoundController)

local SpinController = {}

local player = Players.LocalPlayer

local panel: Frame
local hintLabel: TextButton -- tap/click target for touch and mouse; G toggles too
local nameLabel: TextLabel
local rarityLabel: TextLabel
local descLabel: TextLabel
local skillsLabel: TextLabel
local spinButton: TextButton

local spinning = false

local function getSpins(): number
    return (player:GetAttribute("Spins") :: number?) or 0
end

local function makeLabel(parent: Instance, y: number, height: number, textSize: number, font: Enum.Font): TextLabel
    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(16, y)
    label.Size = UDim2.new(1, -32, 0, height)
    label.BackgroundTransparency = 1
    label.Font = font
    label.TextSize = textSize
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function showStyle(style: Types.StyleDef)
    local color = Styles.RarityColors[style.rarity]
    nameLabel.Text = string.upper(style.name)
    nameLabel.TextColor3 = color
    rarityLabel.Text = string.upper(style.rarity)
    rarityLabel.TextColor3 = color
    descLabel.Text = style.description
    local q, e = style.skills.Q, style.skills.E
    skillsLabel.Text = `[Q] {q.name} ({q.cooldown}s)    [E] {e.name} ({e.cooldown}s)\n`
        .. `Speed x{style.speedMult}  ·  Stamina x{style.staminaMult}  ·  Reach +{style.reachBonus}`
end

local function refresh()
    local spins = getSpins()
    hintLabel.Text = `STYLES  ·  SPINS: {spins}`
    if not spinning then
        showStyle(Styles.Get(player:GetAttribute("Style") :: string?))
    end
    spinButton.Text = if spinning then "ROLLING..."
        elseif spins < 1 then "NO SPINS LEFT"
        else `SPIN  ({spins} left)`
    spinButton.BackgroundColor3 = if spinning or spins < 1
        then Color3.fromRGB(70, 70, 80)
        else Color3.fromRGB(230, 60, 60)
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

    -- Shuffle through the roster while the server rolls
    local started = os.clock()
    local i = 0
    while os.clock() - started < 1.2 or not done do
        i += 1
        showStyle(Styles.List[i % #Styles.List + 1])
        task.wait(0.07)
    end

    spinning = false
    refresh()
    if result then
        local style = Styles.Get(result)
        showStyle(style)
        local big = style.rarity == "Epic" or style.rarity == "Legendary"
        SoundController.PlaySFX(if big then "TubigFanfare" else "CheckpointChime")
    end
end

local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpinMenu"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    hintLabel = Instance.new("TextButton")
    hintLabel.Position = UDim2.fromOffset(16, 16) -- top-left; bottom-left is the touch thumbstick
    hintLabel.Size = UDim2.fromOffset(220, 44) -- 44px: comfortable touch target
    hintLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hintLabel.BackgroundTransparency = 0.3
    hintLabel.Font = Enum.Font.GothamBold
    hintLabel.TextSize = 14
    hintLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    hintLabel.Parent = gui
    Instance.new("UICorner").Parent = hintLabel
    hintLabel.Activated:Connect(function()
        panel.Visible = not panel.Visible
    end)

    panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(420, 290)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    panel.BackgroundTransparency = 0.1
    panel.Visible = false
    panel.Parent = gui
    Instance.new("UICorner").Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 85)
    stroke.Thickness = 1.5
    stroke.Parent = panel

    local title = makeLabel(panel, 12, 20, 14, Enum.Font.GothamBold)
    title.Text = "YOUR STYLE"
    title.TextColor3 = Color3.fromRGB(170, 170, 185)

    nameLabel = makeLabel(panel, 34, 44, 38, Enum.Font.GothamBlack)
    rarityLabel = makeLabel(panel, 78, 20, 16, Enum.Font.GothamBold)
    descLabel = makeLabel(panel, 104, 40, 15, Enum.Font.Gotham)
    skillsLabel = makeLabel(panel, 148, 44, 14, Enum.Font.GothamMedium)

    spinButton = Instance.new("TextButton")
    spinButton.AnchorPoint = Vector2.new(0.5, 1)
    spinButton.Position = UDim2.new(0.5, 0, 1, -16)
    spinButton.Size = UDim2.new(1, -32, 0, 52)
    spinButton.Font = Enum.Font.GothamBlack
    spinButton.TextSize = 22
    spinButton.TextColor3 = Color3.new(1, 1, 1)
    spinButton.Modal = true
    spinButton.Parent = panel
    Instance.new("UICorner").Parent = spinButton
    spinButton.Activated:Connect(spin)

    local close = Instance.new("TextButton")
    close.Position = UDim2.new(1, -40, 0, 8)
    close.Size = UDim2.fromOffset(32, 32)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.TextSize = 20
    close.TextColor3 = Color3.fromRGB(200, 200, 210)
    close.Text = "X"
    close.Parent = panel
    close.Activated:Connect(function()
        panel.Visible = false
    end)
end

function SpinController.Init()
    buildUI()
    refresh()
    player:GetAttributeChangedSignal("Spins"):Connect(refresh)
    player:GetAttributeChangedSignal("Style"):Connect(refresh)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.G then
            panel.Visible = not panel.Visible
        end
    end)
end

return SpinController
