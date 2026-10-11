--!strict
--[[
    UIKit.luau
    The "night court" look every screen shares: chalk lines on dark asphalt, read like a sports broadcast.
    Color and type tokens, the Blender-made images (tools/blender/ui_assets.py), one crisp motion
    vocabulary, and builders for the recurring pieces — steel-edged panels with an accent bar, buttons,
    snaps, sheen, spinning rays, count-ups, shakes, shockwave rings and the menu blur.
    Color is reserved for meaning (rarity, team, role, urgency); everything else is slate and chalk.
    Respects the player's Reduced Motion setting (loops, shakes and blur pulses are skipped).
]]

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local SoundController = require(script.Parent.SoundController)

local UIKit = {}

UIKit.Color = table.freeze({
    Night = Color3.fromRGB(19, 24, 32), -- panel base: night asphalt
    Deep = Color3.fromRGB(11, 14, 19), -- insets, tracks
    Slab = Color3.fromRGB(28, 35, 48), -- cards
    Steel = Color3.fromRGB(54, 65, 82), -- 1 px edges
    Chalk = Color3.fromRGB(230, 232, 227), -- text, like the court's chalk lines
    Dim = Color3.fromRGB(135, 144, 160), -- secondary text
    Signal = Color3.fromRGB(217, 54, 62), -- the main action and urgency
    SignalDark = Color3.fromRGB(120, 28, 34),
    Amber = Color3.fromRGB(233, 162, 59), -- marks what is yours
    White = Color3.new(1, 1, 1),
})

local OSWALD = "rbxasset://fonts/families/Oswald.json"
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
UIKit.Font = table.freeze({
    Display = Font.new(OSWALD, Enum.FontWeight.Bold), -- condensed scoreboard face: titles, numbers
    Label = Font.new(OSWALD, Enum.FontWeight.Medium), -- small uppercase labels
    Body = Font.new(BUILDER, Enum.FontWeight.Medium),
    Bold = Font.new(BUILDER, Enum.FontWeight.Bold),
})

UIKit.Image = table.freeze({
    Rays = "rbxassetid://131045294298750",
    Glow = "rbxassetid://126764346582106",
    Grain = "rbxassetid://109853492875949", -- tileable asphalt grain, 256 px
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

-- Text label with the house defaults
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
    label.Parent = parent
    return label
end

-- Subtle vertical light falloff so flat slabs read as surfaces
function UIKit.wash(gui: GuiObject, bottom: number?)
    local b = bottom or 0.7
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(b, b, b)) }, gui)
end

-- Steel-edged panel: small radius, 1 px edge, asphalt grain, and an accent bar on one side whose
-- color carries meaning (rarity, team, role). Returns the accent bar and the edge stroke.
function UIKit.panel(frame: GuiObject, accent: Color3?, side: ("Top" | "Left")?, radius: number?): (Frame?, UIStroke)
    UIKit.corner(frame, radius or 4)
    local edge = UIKit.stroke(frame, UIKit.Color.Steel, 1, 0.1)
    edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- panels can be (blank) buttons; edge the box, not the text
    make("ImageLabel", {
        Name = "Grain",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = UIKit.Image.Grain,
        ImageTransparency = 0.9,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(128, 128),
        ZIndex = 0,
        Active = false,
    }, frame)
    if not accent then
        return nil, edge
    end
    local left = side == "Left"
    local bar: Frame = make("Frame", {
        Name = "Accent",
        Size = if left then UDim2.new(0, 3, 1, -8) else UDim2.new(1, -8, 0, 2),
        Position = if left then UDim2.fromOffset(0, 4) else UDim2.fromOffset(4, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, frame)
    return bar, edge
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

-- Faint diagonal sheen sweeping across `gui` every `pause` seconds. Returns the sheen frame.
function UIKit.shimmer(gui: GuiObject, pause: number?): Frame
    local sheen: Frame = make("Frame", {
        Name = "Sheen",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = UIKit.Color.White,
        BorderSizePixel = 0,
        ZIndex = 15,
        Active = false,
    }, gui)
    local corner = gui:FindFirstChildOfClass("UICorner")
    if corner then
        corner:Clone().Parent = sheen
    end
    local gradient: UIGradient = make("UIGradient", {
        Rotation = 20,
        Offset = Vector2.new(-1.2, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.44, 1),
            NumberSequenceKeypoint.new(0.5, 0.82),
            NumberSequenceKeypoint.new(0.56, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sheen)
    if UIKit.reducedMotion() then
        sheen.Visible = false
    else
        TweenService:Create(gradient, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, pause or 3),
            { Offset = Vector2.new(1.2, 0) }):Play()
    end
    return sheen
end

-- Endless rotation (rays). Returns the tween so callers can swap speeds.
function UIKit.spin(gui: GuiObject, seconds: number): Tween?
    if UIKit.reducedMotion() then return nil end
    gui.Rotation = gui.Rotation % 360
    local tween = TweenService:Create(gui, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        { Rotation = gui.Rotation + 360 })
    tween:Play()
    return tween
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

-- Every HUD block scales with screen height so it fits phones and stays crisp on big monitors.
local fitted: { UIScale } = {}
local function screenScale(): number
    local camera = Workspace.CurrentCamera
    return if camera then math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.3) else 1
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
