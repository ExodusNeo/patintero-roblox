--!strict
--[[
    UIKit.luau
    The "Kanto Night" look every screen shares: a barangay court under a sodium streetlamp at night.
    Chalk strokes and torn dark patches on the asphalt, brushed amber paint for the main action and big
    callouts, Sarpanch for names and numbers, Titillium Web for everything else (Figma "Patintero UI",
    Direction B; the hand-drawn shapes are made by tools/ui_kanto.py).
    Color is reserved for meaning (rarity, team, role, urgency); sodium amber marks the main action and
    what is yours. One crisp motion vocabulary, no overshoot.
    Respects the player's Reduced Motion setting (shakes, wipes and blur pulses are skipped).
]]

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local SoundController = require(script.Parent.SoundController)

local UIKit = {}

UIKit.Color = table.freeze({
    Ink = Color3.fromRGB(14, 15, 18), -- night: backdrops, text on paint
    Patch = Color3.fromRGB(11, 12, 14), -- torn patches under HUD pieces
    Chalk = Color3.fromRGB(240, 239, 233), -- text and chalk strokes
    Dim = Color3.fromRGB(138, 143, 153), -- secondary text
    Sodium = Color3.fromRGB(242, 163, 58), -- streetlamp amber: the main action and what is yours
    Signal = Color3.fromRGB(210, 69, 63), -- urgency: last seconds, tagged
    White = Color3.new(1, 1, 1),
})

local SARPANCH = "rbxasset://fonts/families/Sarpanch.json"
local TITILLIUM = "rbxasset://fonts/families/TitilliumWeb.json"
UIKit.Font = table.freeze({
    Display = Font.new(SARPANCH, Enum.FontWeight.Heavy), -- names, scores, callouts
    Number = Font.new(SARPANCH, Enum.FontWeight.ExtraBold), -- clock, stats, odds, key letters
    Body = Font.new(TITILLIUM, Enum.FontWeight.Regular),
    Semi = Font.new(TITILLIUM, Enum.FontWeight.SemiBold),
    Bold = Font.new(TITILLIUM, Enum.FontWeight.Bold),
})

-- Hand-drawn shapes from the Figma mockup, all white so ImageColor3 tints them (tools/ui_kanto.py)
UIKit.Art = table.freeze({
    Patch = "rbxassetid://104932187263089", -- torn dark patch (scoreboard, buttons)
    SlotPatch = "rbxassetid://83786577683272", -- square patch under a skill slot
    SlotEdge = "rbxassetid://118164769852155", -- chalk square around a skill slot
    KeyBox = "rbxassetid://84175775865031", -- chalk square around a key letter
    Underline = "rbxassetid://100900496608958", -- heavy chalk underline (style name)
    Divider = "rbxassetid://80328492052347",
    Stroke = "rbxassetid://119099865602860", -- double chalk stroke (stamina)
    Paint = "rbxassetid://129666207123068", -- brushed paint plate (SPIN)
    Callout = "rbxassetid://82451337390345", -- wide paint plate (event callouts)
    TeamMark = "rbxassetid://123140937052663", -- chalk underline under a team's score
    YourSide = "rbxassetid://86199617049508", -- amber scribble under your side
    Tick = "rbxassetid://121727782111665", -- round tick
    Lamp = "rbxassetid://94112457561331", -- streetlamp glow, its light cone, pool and the shadow below
    Cone = "rbxassetid://92906161084480",
    Pool = "rbxassetid://125103351430007",
    Shadow = "rbxassetid://84425250187625",
})

UIKit.Image = table.freeze({
    Glow = "rbxassetid://126764346582106",
    Ring = "rbxassetid://75433959061612", -- soft ring (shared with SkillEffects)
})

-- Embossed skill-kind icons (white, tinted per style)
UIKit.Icon = table.freeze({
    Dash = "rbxassetid://135013657870440",
    Blink = "rbxassetid://71972459740827",
    Haste = "rbxassetid://130893599015323",
    SecondWind = "rbxassetid://82734775353746",
    LongArm = "rbxassetid://98982487639325",
    Slow = "rbxassetid://130965629788735",
    Veil = "rbxassetid://124329657309804",
}) :: { [string]: string }

-- Crisp, no overshoot: things snap into place rather than bounce
UIKit.Motion = table.freeze({
    Quick = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Snap = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Slide = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Fade = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
})

function UIKit.reducedMotion(): boolean
    local ok, enabled = pcall(function()
        return (GuiService :: any).ReducedMotionEnabled
    end)
    return ok and enabled == true
end

-- Instance.new + properties, parented last (one layout pass, no flicker)
function UIKit.make(className: string, props: { [string]: any }, parent: Instance?): any
    local inst = Instance.new(className)
    for key, value in props do
        (inst :: any)[key] = value
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end
local make = UIKit.make

function UIKit.corner(gui: GuiObject, radius: number?): UICorner
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, gui)
end

function UIKit.stroke(gui: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
    return make("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = if gui:IsA("TextLabel") or gui:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
    }, gui)
end

-- Roblox's TextSize is the line height, Figma's font size the em; both house fonts set a line at ~1.4 em.
-- Mockup font sizes times this land at the mockup's glyph size (Roblox caps TextSize at 100).
UIKit.EM = 1.4

-- Text label with the house defaults. TextSize is given as the mockup's font size.
function UIKit.text(props: { [string]: any }, parent: Instance?): TextLabel
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        FontFace = UIKit.Font.Bold,
        TextColor3 = UIKit.Color.Chalk,
        TextSize = 16,
    }, nil)
    for key, value in props do
        (label :: any)[key] = value
    end
    label.TextSize = math.min(math.round(label.TextSize * UIKit.EM), 100)
    label.Parent = parent
    return label
end

-- One of the hand-drawn shapes (UIKit.Art), filling its parent unless props say otherwise
function UIKit.art(image: string, props: { [string]: any }, parent: Instance?): ImageLabel
    local label = make("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = image,
        Active = false,
    }, nil)
    for key, value in props do
        (label :: any)[key] = value
    end
    label.Parent = parent
    return label
end

-- Draws `clip`'s contents in left to right, like a chalk or paint stroke (contents need Offset sizes)
function UIKit.wipe(clip: GuiObject, full: UDim2, info: TweenInfo?)
    clip.ClipsDescendants = true
    if UIKit.reducedMotion() then
        clip.Size = full
        return
    end
    clip.Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset)
    TweenService:Create(clip, info or UIKit.Motion.Slide, { Size = full }):Play()
end

-- Hover nudges up, press dips, release snaps back with a click. Mouse, touch and gamepad selection.
function UIKit.button(button: GuiButton, onActivated: () -> ())
    local scale: UIScale = make("UIScale", { Name = "Juice" }, button)
    local hovering = false
    local function to(value: number)
        TweenService:Create(scale, UIKit.Motion.Quick, { Scale = value }):Play()
    end
    button.MouseEnter:Connect(function()
        hovering = true
        to(1.03)
    end)
    button.MouseLeave:Connect(function()
        hovering = false
        to(1)
    end)
    button.SelectionGained:Connect(function()
        to(1.03)
    end)
    button.SelectionLost:Connect(function()
        to(1)
    end)
    button.MouseButton1Down:Connect(function()
        to(0.96)
    end)
    button.Activated:Connect(function()
        SoundController.PlaySFX("UIClick")
        scale.Scale = 0.95
        TweenService:Create(scale, UIKit.Motion.Snap, { Scale = if hovering then 1.03 else 1 }):Play()
        onActivated()
    end)
end

-- Short scale snap on an element via its own UIScale ("Pop"); don't use on buttons (they have Juice).
function UIKit.pop(gui: GuiObject, amount: number?)
    local scale = gui:FindFirstChild("Pop") :: UIScale?
    if not scale then
        scale = make("UIScale", { Name = "Pop" }, gui)
    end
    local s = scale :: UIScale
    s.Scale = amount or 1.12
    TweenService:Create(s, UIKit.Motion.Snap, { Scale = 1 }):Play()
end

-- Rolls a number label up (or down) to `target` instead of snapping.
function UIKit.countTo(label: TextLabel, target: number)
    local value = label:FindFirstChild("Count") :: NumberValue?
    if not value then
        local created: NumberValue = make("NumberValue", { Name = "Count", Value = tonumber(label.Text) or 0 }, label)
        created.Changed:Connect(function(v: number)
            label.Text = tostring(math.round(v))
        end)
        value = created
    end
    TweenService:Create(value :: NumberValue, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = target }):Play()
end

-- Short hard shake for big moments (a few px, a quarter second)
function UIKit.shake(gui: GuiObject, strength: number?)
    if UIKit.reducedMotion() then return end
    local home = gui.Position
    task.spawn(function()
        for i = 1, 6 do
            local s = (strength or 5) * (1 - i / 7)
            gui.Position = home + UDim2.fromOffset(math.random(-10, 10) / 10 * s, math.random(-10, 10) / 10 * s)
            task.wait(0.03)
        end
        gui.Position = home
    end)
end

-- Ring that blasts outward from the center of `layer` and fades (reveals, big moments)
function UIKit.shockwave(layer: GuiObject, color: Color3, size: number?)
    local ring: ImageLabel = make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromScale(0.2, 0.2),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Ring,
        ImageColor3 = color,
        ImageTransparency = 0.05,
        ZIndex = 8,
    }, layer)
    make("UIAspectRatioConstraint", {}, ring)
    local finish = size or 1.6
    TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(finish, finish),
        ImageTransparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.6)
end

-- Blurs the world behind a menu. `pulse` briefly deepens it (a hit of focus on big reveals).
local blur: BlurEffect? = nil
function UIKit.blur(on: boolean, pulse: boolean?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    if not blur or blur.Parent ~= camera then
        blur = make("BlurEffect", { Name = "MenuBlur", Size = 0 }, camera)
    end
    local effect = blur :: BlurEffect
    local target = if on then 12 else 0
    if pulse and not UIKit.reducedMotion() then
        effect.Size = 24
    end
    TweenService:Create(effect, UIKit.Motion.Slide, { Size = target }):Play()
end

-- HUD blocks are laid out at the mockup's 1366x768 and scale with screen height, so they keep the
-- mockup's proportions on phones and big monitors.
local fitted: { UIScale } = {}
local function screenScale(): number
    local camera = Workspace.CurrentCamera
    return if camera then math.clamp(camera.ViewportSize.Y / 768, 0.6, 1.5) else 1
end

function UIKit.fitScreen(root: GuiObject): UIScale
    local scale: UIScale = make("UIScale", { Name = "Fit", Scale = screenScale() }, root)
    if #fitted == 0 and Workspace.CurrentCamera then
        (Workspace.CurrentCamera :: Camera):GetPropertyChangedSignal("ViewportSize"):Connect(function()
            local s = screenScale()
            for _, each in fitted do
                each.Scale = s
            end
        end)
    end
    table.insert(fitted, scale)
    return scale
end

return UIKit
