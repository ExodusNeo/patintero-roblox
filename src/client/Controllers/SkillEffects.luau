--!strict
--[[
    SkillEffects.luau
    Per-style skill VFX, played on every client for every cast (SkillCast) — keyed "<styleId>_<slot>".
    Sprites are Blender-rendered (tools/blender/fx_textures.py, uploaded as images) plus Roblox's built-in
    particle textures. Effect timings line up with the matching StyleAnimator animation.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local SoundController = require(script.Parent.SoundController)

local SkillEffects = {}

local TEX = {
    -- Blender sprites (assets/fx)
    Ring = "rbxassetid://75433959061612",
    Rune = "rbxassetid://77308133692410",
    Slash = "rbxassetid://132992677623317",
    Wind = "rbxassetid://115499369665005",
    Leaf = "rbxassetid://115185637809861",
    Feather = "rbxassetid://111998622355000",
    Star = "rbxassetid://116235837035747",
    Streak = "rbxassetid://130618388759980",
    -- Built in
    Smoke = "rbxasset://textures/particles/smoke_main.dds",
    Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
    Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
    Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local WHITE = Color3.new(1, 1, 1)
local THEME: { [string]: Color3 } = {
    Tsinelas = Color3.fromRGB(255, 236, 200),
    Kanto = Color3.fromRGB(110, 230, 140),
    Bantay = Color3.fromRGB(255, 205, 60),
    Sipa = Color3.fromRGB(90, 190, 255),
    Tumbang = Color3.fromRGB(255, 140, 50),
    Habagat = Color3.fromRGB(90, 230, 210),
    Anino = Color3.fromRGB(150, 70, 230),
    Bathala = Color3.fromRGB(255, 215, 90),
}
local DUST = Color3.fromRGB(200, 178, 145)
local SHADOW = Color3.fromRGB(30, 12, 45)
local LEAF_GREEN = Color3.fromRGB(110, 200, 90)

type Cast = {
    character: Model?,
    root: BasePart?,
    position: Vector3, -- caster's root when the server accepted the cast
    ground: Vector3, -- floor under `position`
    color: Color3,
    skill: Types.SkillDef,
}

-- Emitter settings: anything not given keeps ParticleEmitter defaults
type EmitterProps = { [string]: any }

local function makeEmitter(props: EmitterProps): ParticleEmitter
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 0
    emitter.LightEmission = 0.6
    for key, value in props do
        (emitter :: any)[key] = value
    end
    return emitter
end

local function lifetimeOf(props: EmitterProps): number
    local life = props.Lifetime
    return if typeof(life) == "NumberRange" then life.Max else 1
end

-- One-shot burst at a world position
local function burst(position: Vector3, count: number, props: EmitterProps)
    local anchor = Instance.new("Attachment")
    anchor.Position = position -- Terrain sits at the origin, so this is world space
    local emitter = makeEmitter(props)
    emitter.Parent = anchor
    anchor.Parent = Workspace.Terrain
    emitter:Emit(count)
    Debris:AddItem(anchor, lifetimeOf(props) + 0.1)
end

-- Emitter that follows a part for `duration` seconds
local function aura(part: BasePart, duration: number, props: EmitterProps, offset: Vector3?)
    local anchor = Instance.new("Attachment")
    anchor.Position = offset or Vector3.zero
    local emitter = makeEmitter(props)
    emitter.Parent = anchor
    anchor.Parent = part
    task.delay(duration, function()
        emitter.Enabled = false
    end)
    Debris:AddItem(anchor, duration + lifetimeOf(props) + 0.1)
end

-- Flat sprite lying on the ground that grows to `radius` and fades (rings, runes)
local function groundDecal(ground: Vector3, radius: number, color: Color3, texture: string, life: number, spin: number?)
    burst(ground + Vector3.new(0, 0.15, 0), 1, {
        Texture = texture,
        Color = ColorSequence.new(color),
        LightEmission = 1,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
        EmissionDirection = Enum.NormalId.Top,
        Speed = NumberRange.new(0.01),
        Lifetime = NumberRange.new(life),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.3), NumberSequenceKeypoint.new(0.35, radius * 2), NumberSequenceKeypoint.new(1, radius * 2.15) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        RotSpeed = NumberRange.new(spin or 0),
        ZOffset = 0.5,
    })
end

local function flashLight(position: Vector3, color: Color3, range: number, life: number)
    local anchor = Instance.new("Attachment")
    anchor.Position = position
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range
    light.Brightness = 4
    light.Parent = anchor
    anchor.Parent = Workspace.Terrain
    TweenService:Create(light, TweenInfo.new(life, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
    Debris:AddItem(anchor, life)
end

-- Kicked-up dust ring at the feet
local function dust(ground: Vector3, color: Color3, count: number)
    burst(ground + Vector3.new(0, 0.4, 0), count, {
        Texture = TEX.Smoke,
        Color = ColorSequence.new(color),
        LightEmission = 0,
        Lifetime = NumberRange.new(0.5, 0.8),
        Speed = NumberRange.new(5, 10),
        SpreadAngle = Vector2.new(80, 15),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, -4, 0),
        Drag = 4,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
        RotSpeed = NumberRange.new(-60, 60),
    })
end

-- Thin streaks flying back past the body while it moves fast
local function speedLines(root: BasePart, duration: number, color: Color3)
    aura(root, duration, {
        Texture = TEX.Streak,
        Color = ColorSequence.new(color),
        LightEmission = 1,
        Rate = 45,
        Lifetime = NumberRange.new(0.12, 0.2),
        Speed = NumberRange.new(30, 40),
        EmissionDirection = Enum.NormalId.Back,
        SpreadAngle = Vector2.new(25, 25),
        Orientation = Enum.ParticleOrientation.VelocityParallel, -- the streak sprite already runs along the motion
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
    })
end

-- Color streak behind the body
local function trail(root: BasePart, color: Color3, duration: number)
    local top = Instance.new("Attachment")
    top.Position = Vector3.new(0, 0.9, 0)
    local bottom = Instance.new("Attachment")
    bottom.Position = Vector3.new(0, -0.9, 0)
    local streak = Instance.new("Trail")
    streak.Attachment0 = top
    streak.Attachment1 = bottom
    streak.Color = ColorSequence.new(color, WHITE)
    streak.Transparency = NumberSequence.new(0.35, 1)
    streak.Lifetime = 0.3
    streak.LightEmission = 0.7
    streak.FaceCamera = true
    top.Parent = root
    bottom.Parent = root
    streak.Parent = root
    for _, item in { streak, top, bottom } do
        Debris:AddItem(item, duration + streak.Lifetime)
    end
end

-- Neon copies of the body left behind, fading out
local function afterimages(character: Model, color: Color3, count: number, interval: number)
    task.spawn(function()
        for _ = 1, count do
            if not character.Parent then return end
            local ghost = Instance.new("Model")
            ghost.Name = "Afterimage"
            for _, part in character:GetChildren() do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                    local copy = Instance.new("Part")
                    copy.Size = part.Size
                    copy.CFrame = part.CFrame
                    copy.Anchored = true
                    copy.CanCollide = false
                    copy.CanQuery = false
                    copy.CanTouch = false
                    copy.CastShadow = false
                    copy.Material = Enum.Material.Neon
                    copy.Color = color
                    copy.Transparency = 0.5
                    copy.Parent = ghost
                    TweenService:Create(copy, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
                end
            end
            ghost.Parent = Workspace
            Debris:AddItem(ghost, 0.45)
            task.wait(interval)
        end
    end)
end

-- Column of light rising from the ground
local function pillar(ground: Vector3, color: Color3, height: number, life: number)
    local beam = Instance.new("Part")
    beam.Shape = Enum.PartType.Cylinder
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CanTouch = false
    beam.CastShadow = false
    beam.Material = Enum.Material.Neon
    beam.Color = color
    beam.Transparency = 0.2
    beam.Size = Vector3.new(height, 0.5, 0.5)
    beam.CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    beam.Parent = Workspace
    TweenService:Create(beam, TweenInfo.new(life, Enum.EasingStyle.Quad), { Size = Vector3.new(height, 4, 4), Transparency = 1 }):Play()
    Debris:AddItem(beam, life)
    flashLight(ground + Vector3.new(0, 3, 0), color, 18, life)
end

local function featherBurst(position: Vector3, color: Color3, count: number)
    burst(position, count, {
        Texture = TEX.Feather,
        Color = ColorSequence.new(WHITE, color),
        LightEmission = 0.8,
        Lifetime = NumberRange.new(1.2, 2),
        Speed = NumberRange.new(4, 9),
        SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, -3, 0),
        Drag = 2.5,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0.7) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) }),
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-120, 120),
    })
end

local function starBurst(position: Vector3, color: Color3, count: number)
    burst(position, count, {
        Texture = TEX.Star,
        Color = ColorSequence.new(WHITE, color),
        LightEmission = 1,
        Lifetime = NumberRange.new(0.3, 0.55),
        Speed = NumberRange.new(8, 16),
        SpreadAngle = Vector2.new(180, 180),
        Drag = 5,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }),
        Rotation = NumberRange.new(0, 90),
    })
end

local function leafBurst(position: Vector3, count: number, speed: number)
    burst(position, count, {
        Texture = TEX.Leaf,
        Color = ColorSequence.new(LEAF_GREEN, Color3.fromRGB(200, 230, 120)),
        LightEmission = 0.2,
        Lifetime = NumberRange.new(0.8, 1.4),
        Speed = NumberRange.new(speed * 0.6, speed),
        SpreadAngle = Vector2.new(180, 40),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, -6, 0),
        Drag = 2,
        Size = NumberSequence.new(0.8),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-300, 300),
    })
end

-- Big slash crescent in front of the body
local function slash(position: Vector3, color: Color3, size: number)
    burst(position, 1, {
        Texture = TEX.Slash,
        Color = ColorSequence.new(WHITE, color),
        LightEmission = 1,
        Lifetime = NumberRange.new(0.25),
        Speed = NumberRange.new(0.01),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
        Rotation = NumberRange.new(-30, 30),
        ZOffset = 1,
    })
end

local function hand(character: Model?, name: string): BasePart?
    local part = if character then character:FindFirstChild(name) else nil
    return if part and part:IsA("BasePart") then part else nil
end

-- Tin can arcs from the thrower's hand onto the ground, then calls `land`
local function throwCan(from: Vector3, to: Vector3, flight: number, land: () -> ())
    local can = Instance.new("Part")
    can.Shape = Enum.PartType.Cylinder
    can.Size = Vector3.new(1, 0.7, 0.7)
    can.Material = Enum.Material.Metal
    can.Color = Color3.fromRGB(200, 60, 50)
    can.Anchored = true
    can.CanCollide = false
    can.CanQuery = false
    can.CanTouch = false
    can.Parent = Workspace
    local peak = (from + to) / 2 + Vector3.new(0, 4, 0)
    local started = os.clock()
    local connection: RBXScriptConnection
    connection = RunService.RenderStepped:Connect(function()
        local t = math.min((os.clock() - started) / flight, 1)
        local position = from:Lerp(peak, t):Lerp(peak:Lerp(to, t), t) -- quadratic Bezier
        can.CFrame = CFrame.new(position) * CFrame.Angles(t * 12, t * 7, 0)
        if t >= 1 then
            connection:Disconnect()
            can:Destroy()
            land()
        end
    end)
end

-- Rain streaks falling over a circular area for `duration`
local function rain(ground: Vector3, radius: number, duration: number)
    local cloud = Instance.new("Part")
    cloud.Anchored = true
    cloud.CanCollide = false
    cloud.CanQuery = false
    cloud.CanTouch = false
    cloud.Transparency = 1
    cloud.Size = Vector3.new(radius * 1.6, 0.2, radius * 1.6)
    cloud.CFrame = CFrame.new(ground + Vector3.new(0, 14, 0))
    local drops = makeEmitter({
        Texture = TEX.Streak,
        Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)),
        LightEmission = 0.5,
        Rate = 140,
        Lifetime = NumberRange.new(0.35, 0.45),
        Speed = NumberRange.new(38, 45),
        EmissionDirection = Enum.NormalId.Bottom,
        Orientation = Enum.ParticleOrientation.VelocityParallel, -- the streak sprite already runs along the motion
        Size = NumberSequence.new(0.6),
        Transparency = NumberSequence.new(0.3),
    })
    drops.Parent = cloud
    cloud.Parent = Workspace
    task.delay(duration, function()
        drops.Enabled = false
    end)
    Debris:AddItem(cloud, duration + 0.5)
end

local FX: { [string]: (Cast) -> () } = {
    Tsinelas_Q = function(c)
        dust(c.ground, DUST, 14)
        if c.root then
            speedLines(c.root, 0.35, WHITE)
            trail(c.root, c.color, 0.3)
        end
    end,
    Tsinelas_E = function(c) -- Takbo!: wind ring, sparks at the fist pump, speed lines while hasted
        groundDecal(c.ground, 7, WHITE, TEX.Ring, 0.45)
        task.delay(0.22, starBurst, c.position + Vector3.new(0, 2.5, 0), c.color, 8)
        if c.root then
            speedLines(c.root, c.skill.duration or 2.5, c.color)
            trail(c.root, c.color, c.skill.duration or 2.5)
        end
    end,

    Kanto_Q = function(c) -- shoulder charge: dust behind, impact puff ahead
        dust(c.ground, DUST, 12)
        if c.root then
            trail(c.root, c.color, 0.3)
            local root = c.root
            task.delay(0.1, function()
                burst(root.Position + root.CFrame.LookVector * 2.5, 10, {
                    Texture = TEX.Smoke,
                    Color = ColorSequence.new(c.color, WHITE),
                    LightEmission = 0.3,
                    Lifetime = NumberRange.new(0.3, 0.5),
                    Speed = NumberRange.new(6, 12),
                    SpreadAngle = Vector2.new(60, 60),
                    Drag = 6,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.5) }),
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
                })
            end)
        end
    end,
    Kanto_E = function(c) -- Second Wind: green breath rising, ring at the feet, swirl at the chest
        groundDecal(c.ground, 6, c.color, TEX.Ring, 0.6)
        burst(c.position + Vector3.new(0, 1, 0), 1, {
            Texture = TEX.Vortex,
            Color = ColorSequence.new(c.color),
            LightEmission = 1,
            Lifetime = NumberRange.new(0.6),
            Speed = NumberRange.new(0.01),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 1) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
            RotSpeed = NumberRange.new(360),
        })
        if c.root then
            aura(c.root, 1.2, {
                Texture = TEX.Sparkle,
                Color = ColorSequence.new(c.color, WHITE),
                LightEmission = 1,
                Rate = 35,
                Lifetime = NumberRange.new(0.6, 1),
                Speed = NumberRange.new(2, 5),
                SpreadAngle = Vector2.new(60, 60),
                EmissionDirection = Enum.NormalId.Top,
                Acceleration = Vector3.new(0, 4, 0),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
            })
        end
    end,

    Bantay_Q = function(c) -- Lunge: golden slash where the hand thrusts
        if c.root then
            trail(c.root, c.color, 0.3)
            local root = c.root
            task.delay(0.08, function()
                slash(root.Position + root.CFrame.LookVector * 3.5 + Vector3.new(0, 0.6, 0), c.color, 7)
            end)
        end
        dust(c.ground, DUST, 8)
    end,
    Bantay_E = function(c) -- Long Arm: glowing hands for the whole buff, ring as the arms snap open
        task.delay(0.36, groundDecal, c.ground, 6, c.color, TEX.Ring, 0.5)
        local duration = c.skill.duration or 3
        for _, name in { "RightHand", "LeftHand" } do
            local part = hand(c.character, name)
            if part then
                aura(part, duration, {
                    Texture = TEX.Sparkle,
                    Color = ColorSequence.new(c.color, WHITE),
                    LightEmission = 1,
                    Rate = 25,
                    Lifetime = NumberRange.new(0.3, 0.5),
                    Speed = NumberRange.new(0.5, 1.5),
                    SpreadAngle = Vector2.new(180, 180),
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
                })
                local light = Instance.new("PointLight")
                light.Color = c.color
                light.Range = 6
                light.Brightness = 2
                light.Parent = part
                Debris:AddItem(light, duration)
            end
        end
    end,

    Sipa_Q = function(c) -- Hop: blue burst where you left and where you land
        starBurst(c.position, c.color, 10)
        groundDecal(c.ground, 4, c.color, TEX.Ring, 0.4)
        if c.root then
            local root = c.root
            task.delay(0.08, function()
                starBurst(root.Position, c.color, 8)
                burst(root.Position - Vector3.new(0, 2.5, 0), 4, {
                    Texture = TEX.Wind,
                    Color = ColorSequence.new(WHITE, c.color),
                    LightEmission = 1,
                    Lifetime = NumberRange.new(0.35),
                    Speed = NumberRange.new(0.01),
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
                    Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
                    Rotation = NumberRange.new(0, 360),
                    RotSpeed = NumberRange.new(400),
                })
            end)
        end
    end,
    Sipa_E = function(c) -- Takbo!: wind swirling around the legs, puffs at each knee kick
        local duration = c.skill.duration or 2.5
        for _, at in { 0.1, 0.28, 0.46 } do
            task.delay(at, dust, c.ground, c.color, 4)
        end
        if c.root then
            trail(c.root, c.color, duration)
            aura(c.root, duration, {
                Texture = TEX.Wind,
                Color = ColorSequence.new(WHITE, c.color),
                LightEmission = 1,
                Rate = 10,
                Lifetime = NumberRange.new(0.3, 0.45),
                Speed = NumberRange.new(0.01),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 3.5) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
                Rotation = NumberRange.new(0, 360),
                RotSpeed = NumberRange.new(500),
            }, Vector3.new(0, -1.5, 0))
        end
    end,

    Tumbang_Q = function(c)
        dust(c.ground, DUST, 12)
        burst(c.ground + Vector3.new(0, 0.5, 0), 16, {
            Texture = TEX.Sparks,
            Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), c.color),
            LightEmission = 1,
            Lifetime = NumberRange.new(0.3, 0.6),
            Speed = NumberRange.new(10, 18),
            SpreadAngle = Vector2.new(70, 20),
            EmissionDirection = Enum.NormalId.Top,
            Acceleration = Vector3.new(0, -30, 0),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
        })
        if c.root then
            trail(c.root, c.color, 0.3)
        end
    end,
    Tumbang_E = function(c) -- Lata Shock: the can flies, slams, and the shock ring sweeps the radius
        local radius = c.skill.radius or 14
        local thrower = hand(c.character, "RightHand")
        local landAt = c.ground + (if c.root then c.root.CFrame.LookVector * 3 else Vector3.zero)
        local function impact()
            groundDecal(landAt, radius, c.color, TEX.Ring, 0.6)
            groundDecal(landAt, radius * 0.6, WHITE, TEX.Ring, 0.4)
            burst(landAt + Vector3.new(0, 0.5, 0), 30, {
                Texture = TEX.Sparks,
                Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), c.color),
                LightEmission = 1,
                Lifetime = NumberRange.new(0.4, 0.8),
                Speed = NumberRange.new(14, 26),
                SpreadAngle = Vector2.new(80, 30),
                EmissionDirection = Enum.NormalId.Top,
                Acceleration = Vector3.new(0, -35, 0),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
            })
            dust(landAt, DUST, 16)
            flashLight(landAt + Vector3.new(0, 2, 0), c.color, 20, 0.4)
            SoundController.PlaySpatialSFX("TagSlap", landAt, Vector2.new(1.6, 1.8))
        end
        task.delay(0.1, function()
            local from = if thrower then thrower.Position else c.position + Vector3.new(0, 3, 0)
            throwCan(from, landAt + Vector3.new(0, 0.4, 0), 0.22, impact)
        end)
    end,

    Habagat_Q = function(c) -- Gale Step: wind swirl and leaves where you were, afterimages as you spin
        burst(c.position, 5, {
            Texture = TEX.Wind,
            Color = ColorSequence.new(WHITE, c.color),
            LightEmission = 1,
            Lifetime = NumberRange.new(0.45),
            Speed = NumberRange.new(0.01),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 7) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-450),
        })
        leafBurst(c.position, 14, 12)
        if c.character then
            afterimages(c.character, c.color, 3, 0.07)
        end
    end,
    Habagat_E = function(c) -- Monsoon: leaves blast out, the ring sweeps the radius, rain falls over it
        local radius = c.skill.radius or 20
        task.delay(0.42, function()
            groundDecal(c.ground, radius, c.color, TEX.Ring, 0.7)
            groundDecal(c.ground, radius * 0.7, WHITE, TEX.Wind, 0.8, 200)
            leafBurst(c.ground + Vector3.new(0, 1, 0), 40, 26)
            flashLight(c.ground + Vector3.new(0, 3, 0), c.color, 24, 0.5)
        end)
        rain(c.ground, radius, (c.skill.duration or 2.5) + 0.4)
    end,

    Anino_Q = function(c) -- shadow dash: dark afterimages and a smoky trail
        if c.character then
            afterimages(c.character, SHADOW, 5, 0.05)
        end
        if c.root then
            aura(c.root, 0.35, {
                Texture = TEX.Smoke,
                Color = ColorSequence.new(SHADOW, c.color),
                LightEmission = 0,
                Rate = 60,
                Lifetime = NumberRange.new(0.4, 0.6),
                Speed = NumberRange.new(1, 3),
                SpreadAngle = Vector2.new(180, 180),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
            })
        end
    end,
    Anino_E = function(c) -- Shadow Veil: smoke bomb, then purple wisps while veiled
        burst(c.position, 28, {
            Texture = TEX.Smoke,
            Color = ColorSequence.new(SHADOW, c.color),
            LightEmission = 0,
            Lifetime = NumberRange.new(0.8, 1.3),
            Speed = NumberRange.new(6, 12),
            SpreadAngle = Vector2.new(180, 180),
            Drag = 4,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 6) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
            RotSpeed = NumberRange.new(-40, 40),
        })
        if c.root then
            aura(c.root, c.skill.duration or 2.5, {
                Texture = TEX.Smoke,
                Color = ColorSequence.new(c.color, SHADOW),
                LightEmission = 0.4,
                Rate = 18,
                Lifetime = NumberRange.new(0.6, 1),
                Speed = NumberRange.new(0.5, 2),
                SpreadAngle = Vector2.new(180, 180),
                Acceleration = Vector3.new(0, 2, 0),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
            })
        end
    end,

    Bathala_Q = function(c) -- Divine Step: light pillars where you leave and arrive, feathers drift down
        pillar(c.ground, c.color, 16, 0.6)
        featherBurst(c.position + Vector3.new(0, 1, 0), c.color, 12)
        if c.root then
            local root = c.root
            task.delay(0.08, function()
                pillar(root.Position - Vector3.new(0, 2.9, 0), c.color, 16, 0.6)
                starBurst(root.Position, c.color, 8)
            end)
        end
    end,
    Bathala_E = function(c) -- Divine Halt: a clock rune spreads over the radius as time stops
        local radius = c.skill.radius or 18
        task.delay(0.33, function()
            groundDecal(c.ground, radius, c.color, TEX.Rune, 1.1, 40)
            groundDecal(c.ground, radius * 0.55, WHITE, TEX.Rune, 0.9, -70)
            groundDecal(c.ground, radius, WHITE, TEX.Ring, 0.5)
            pillar(c.ground, c.color, 22, 0.8)
            featherBurst(c.position + Vector3.new(0, 4, 0), c.color, 24)
            flashLight(c.position + Vector3.new(0, 3, 0), c.color, 30, 0.8)
        end)
    end,
}

local function groundBelow(position: Vector3): Vector3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local characters = {}
    for _, other in Players:GetPlayers() do
        if other.Character then
            table.insert(characters, other.Character)
        end
    end
    params.FilterDescendantsInstances = characters
    local hit = Workspace:Raycast(position, Vector3.new(0, -12, 0), params)
    return if hit then hit.Position else position - Vector3.new(0, 2.9, 0)
end

-- Plays the cast effect for a style's skill; returns false if that style/slot has none.
function SkillEffects.Play(styleId: string, slot: Types.SkillSlot, skill: Types.SkillDef, caster: Model?, position: Vector3): boolean
    local effect = FX[`{styleId}_{slot}`]
    if not effect then return false end
    local root = if caster then caster:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    effect({
        character = caster,
        root = root,
        position = position,
        ground = groundBelow(position),
        color = THEME[styleId] or WHITE,
        skill = skill,
    })
    return true
end

return SkillEffects
