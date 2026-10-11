--!strict
--[[
    UIKit.luau
    The "jeepney chrome" look every screen shares: color and type tokens, the Blender-made images
    (tools/blender/ui_assets.py), one motion vocabulary, and builders for the recurring pieces —
    chrome-rimmed plates, juicy buttons, pops, shimmer sweeps, spinning rays, count-ups, confetti.
    Respects the player's Reduced Motion setting (loops, shakes and confetti are skipped).
]]

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local SoundController = require(script.Parent.SoundController)

local UIKit = {}

UIKit.Color = table.freeze({
    Ink = Color3.fromRGB(23, 26, 51), -- street indigo: panel base
    InkDeep = Color3.fromRGB(13, 15, 32),
    InkLight = Color3.fromRGB(40, 46, 86),
    Red = Color3.fromRGB(224, 48, 63), -- jeepney red
    RedDark = Color3.fromRGB(140, 22, 38),
    Yellow = Color3.fromRGB(255, 201, 60), -- sun yellow
    Teal = Color3.fromRGB(31, 181, 168), -- banderita teal
    Cream = Color3.fromRGB(255, 243, 214), -- warm white for text
    Muted = Color3.fromRGB(158, 166, 204),
    White = Color3.new(1, 1, 1),
})

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
UIKit.Font = table.freeze({
    Display = Font.new("rbxasset://fonts/families/LuckiestGuy.json"), -- sign-painter lettering
    Body = Font.new(BUILDER, Enum.FontWeight.Medium),
    Bold = Font.new(BUILDER, Enum.FontWeight.Bold),
    Heavy = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
})

UIKit.Image = table.freeze({
    Rim = "rbxassetid://108785768754838", -- 512 px chrome tube, 9-slice Rect(170, 170, 342, 342)
    Rays = "rbxassetid://131045294298750",
    Glow = "rbxassetid://126764346582106",
    Ribbon = "rbxassetid://93159918664261", -- 1024x256; show at 4:1 (Stretch), not 9-slice
    Bunting = "rbxassetid://82260993349261", -- tileable banderitas, 512x128
    Flag = "rbxassetid://107036126615407",
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

UIKit.Motion = table.freeze({
    Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Pop = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    Slide = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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

function UIKit.corner(gui: GuiObject, radius: UDim?): UICorner
    return make("UICorner", { CornerRadius = radius or UDim.new(0, 12) }, gui)
end

function UIKit.stroke(gui: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
    return make("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = if gui:IsA("TextLabel") or gui:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
    }, gui)
end

-- Text label with the house defaults (transparent, no wrap surprises)
function UIKit.text(props: { [string]: any }, parent: Instance?): TextLabel
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        FontFace = UIKit.Font.Bold,
        TextColor3 = UIKit.Color.Cream,
        TextSize = 16,
    }, nil)
    for key, value in props do
        (label :: any)[key] = value
    end
    label.Parent = parent
    return label
end

-- Rounded plate with the chrome rim sitting on its edge. `slice` sets the rim thickness
-- (0.3 ≈ 11 px tube, 32 px corners); the frame's UICorner is matched to the rim.
function UIKit.plate(frame: GuiObject, tint: Color3?, slice: number?): ImageLabel
    local s = slice or 0.3
    local margin = math.round(41 * s) -- the tube's centerline is 41 px in from the image edge
    local corner = frame:FindFirstChildOfClass("UICorner") or UIKit.corner(frame)
    corner.CornerRadius = UDim.new(0, math.round(107 * s))
    return make("ImageLabel", {
        Name = "Rim",
        BackgroundTransparency = 1,
        Image = UIKit.Image.Rim,
        ImageColor3 = tint or UIKit.Color.White,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(170, 170, 342, 342),
        SliceScale = s,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, margin * 2, 1, margin * 2),
        ZIndex = 20,
        Active = false,
    }, frame)
end

-- Vertical light-to-dark wash so flat plates read as painted metal
function UIKit.wash(gui: GuiObject, bottom: number?)
    local b = bottom or 0.62
    make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(b, b, b)) }, gui)
end

-- Hover grows, press squishes, release pops with a click. Mouse, touch and gamepad selection.
function UIKit.button(button: GuiButton, onActivated: () -> ())
    local scale: UIScale = make("UIScale", { Name = "Juice" }, button)
    local hovering = false
    local function to(value: number)
        TweenService:Create(scale, UIKit.Motion.Quick, { Scale = value }):Play()
    end
    button.MouseEnter:Connect(function()
        hovering = true
        to(1.06)
    end)
    button.MouseLeave:Connect(function()
        hovering = false
        to(1)
    end)
    button.SelectionGained:Connect(function()
        to(1.06)
    end)
    button.SelectionLost:Connect(function()
        to(1)
    end)
    button.MouseButton1Down:Connect(function()
        to(0.92)
    end)
    button.Activated:Connect(function()
        SoundController.PlaySFX("UIClick")
        scale.Scale = 0.9
        TweenService:Create(scale, UIKit.Motion.Pop, { Scale = if hovering then 1.06 else 1 }):Play()
        onActivated()
    end)
end

-- Scale punch on an element via its own UIScale ("Pop"); don't use on Juice buttons.
function UIKit.pop(gui: GuiObject, amount: number?)
    local scale = gui:FindFirstChild("Pop") :: UIScale?
    if not scale then
        scale = make("UIScale", { Name = "Pop" }, gui)
    end
    local s = scale :: UIScale
    s.Scale = amount or 1.25
    TweenService:Create(s, UIKit.Motion.Pop, { Scale = 1 }):Play()
end

-- Bright diagonal sheen sweeping across `gui` every `pause` seconds. Returns the sheen frame.
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
            NumberSequenceKeypoint.new(0.42, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(0.58, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sheen)
    if UIKit.reducedMotion() then
        sheen.Visible = false
    else
        TweenService:Create(gradient, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, pause or 2.4),
            { Offset = Vector2.new(1.2, 0) }):Play()
    end
    return sheen
end

-- Endless rotation (rays, halos). Returns the tween so callers can swap speeds.
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
    TweenService:Create(value :: NumberValue, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = target }):Play()
end

-- Little shake for big moments (a few px, a quarter second)
function UIKit.shake(gui: GuiObject, strength: number?)
    if UIKit.reducedMotion() then return end
    local home = gui.Position
    task.spawn(function()
        for i = 1, 6 do
            local s = (strength or 5) * (1 - i / 7)
            gui.Position = home + UDim2.fromOffset(math.random(-10, 10) / 10 * s, math.random(-10, 10) / 10 * s)
            task.wait(0.035)
        end
        gui.Position = home
    end)
end

-- Banderita flags burst up from `origin` (scale position in `layer`) and flutter down.
function UIKit.confetti(layer: GuiObject, count: number, colors: { Color3 }, origin: Vector2?)
    if UIKit.reducedMotion() then return end
    local from = origin or Vector2.new(0.5, 0.45)
    for _ = 1, count do
        local size = math.random(16, 30)
        local flag: ImageLabel = make("ImageLabel", {
            BackgroundTransparency = 1,
            Image = UIKit.Image.Flag,
            ImageColor3 = colors[math.random(1, #colors)],
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            Position = UDim2.fromScale(from.X, from.Y),
            Rotation = math.random(0, 360),
            ZIndex = 50,
        }, layer)
        local dx = (math.random() - 0.5) * 0.9
        local rise = TweenService:Create(flag, TweenInfo.new(0.35 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(from.X + dx * 0.6, from.Y - 0.2 - math.random() * 0.3),
            Rotation = flag.Rotation + math.random(-180, 180),
        })
        rise.Completed:Once(function()
            local fall = 1.1 + math.random() * 0.8
            TweenService:Create(flag, TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
                Position = UDim2.fromScale(from.X + dx, 1.1),
                Rotation = flag.Rotation + math.random(-360, 360),
                ImageTransparency = 0.6,
            }):Play()
            Debris:AddItem(flag, fall + 0.1)
        end)
        rise:Play()
    end
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
