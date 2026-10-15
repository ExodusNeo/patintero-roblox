--!strict
--[[
    TutorialController.luau
    First-time tutorial on the client (match place), fed by TutorialStep (TutorialService); idle in normal matches.
    - Step card, left of center in the "Kanto Night" look: STEP n OF m, the title, what to do, chalk key caps and
      a tick per step. A finished step snaps its tick amber with a chime; a tag shakes the card.
    - Beacon at the step's target: a sodium light pillar, a pulsing chalk ring and the target's name.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UIKit = require(script.Parent.UIKit)
local SoundController = require(script.Parent.SoundController)
local SkillEffects = require(script.Parent.SkillEffects)

local C, F, A = UIKit.Color, UIKit.Font, UIKit.Art
local make, text, art = UIKit.make, UIKit.text, UIKit.art

local TutorialController = {}

local player = Players.LocalPlayer
local KEY_HEIGHT = 34
local CARD_WIDTH = 440
local PILLAR_HEIGHT = 26
local RING_SIZE = 9

local card: Frame? = nil
local stepLabel: TextLabel
local titleLabel: TextLabel
local hintLabel: TextLabel
local keyRow: Frame
local ticks: { ImageLabel } = {}
local lastStep = 0

local beacon: Model? = nil
local beaconBase: BasePart
local beaconRing: BasePart
local beaconName: TextLabel

local function buildCard(total: number)
    local gui = make("ScreenGui", {
        Name = "PatinteroTutorial",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
    }, player:WaitForChild("PlayerGui"))
    local root: Frame = make("Frame", {
        Name = "Card",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 28, 0.45, 0),
        Size = UDim2.fromOffset(CARD_WIDTH, 200),
        BackgroundTransparency = 1,
    }, gui)
    UIKit.fitScreen(root)
    art(A.Patch, { ImageColor3 = C.Patch, ImageTransparency = 0.08 }, root)
    stepLabel = text({ FontFace = F.Number, TextSize = 15, TextColor3 = C.Sodium, Position = UDim2.fromOffset(30, 20), Size = UDim2.fromOffset(250, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, root)
    titleLabel = text({ FontFace = F.Display, TextSize = 34, Position = UDim2.fromOffset(30, 42), Size = UDim2.fromOffset(CARD_WIDTH - 60, 48), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }, root)
    hintLabel = text({ FontFace = F.Body, TextSize = 17, TextWrapped = true, Position = UDim2.fromOffset(30, 92), Size = UDim2.fromOffset(CARD_WIDTH - 60, 50), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 2 }, root)
    keyRow = make("Frame", { Position = UDim2.fromOffset(30, 148), Size = UDim2.fromOffset(CARD_WIDTH - 60, KEY_HEIGHT), BackgroundTransparency = 1 }, root)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, keyRow)
    for i = 1, total do
        ticks[i] = art(A.Tick, { Position = UDim2.fromOffset(CARD_WIDTH - 30 - (total - i + 1) * 22, 25), Size = UDim2.fromOffset(18, 9), ImageColor3 = C.Dim, ZIndex = 2 }, root)
    end
    card = root
end

local function setKeys(keys: { string })
    for _, child in keyRow:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    for i, key in keys do
        local box = art(A.KeyBox, { LayoutOrder = i, Size = UDim2.fromOffset(math.max(KEY_HEIGHT, #key * 13 + 20), KEY_HEIGHT), ImageColor3 = C.Chalk }, keyRow)
        text({ Text = key, FontFace = F.Number, TextSize = 15, TextColor3 = C.Sodium, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, box)
    end
end

local function buildBeacon()
    local model = Instance.new("Model")
    model.Name = "TutorialBeacon"
    local function part(size: Vector3): Part
        local p = Instance.new("Part")
        p.Size = size
        p.Anchored = true
        p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
        p.Transparency = 1
        p.Parent = model
        return p
    end
    beaconBase = part(Vector3.one)
    beaconRing = part(Vector3.new(RING_SIZE, 0.05, RING_SIZE))
    local decal = Instance.new("Decal")
    decal.Face = Enum.NormalId.Top
    decal.Texture = SkillEffects.TEX.Ring
    decal.Color3 = C.Sodium
    decal.Parent = beaconRing

    local bottom = Instance.new("Attachment")
    bottom.Parent = beaconBase
    local top = Instance.new("Attachment")
    top.Position = Vector3.new(0, PILLAR_HEIGHT, 0)
    top.Parent = beaconBase
    local pillar = Instance.new("Beam")
    pillar.Attachment0, pillar.Attachment1 = bottom, top
    pillar.Color = ColorSequence.new(C.Sodium)
    pillar.LightEmission = 1
    pillar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
    pillar.Width0, pillar.Width1 = 2.4, 0.8
    pillar.FaceCamera = true
    pillar.Parent = beaconBase
    local light = Instance.new("PointLight")
    light.Color = C.Sodium
    light.Range = 14
    light.Brightness = 1.6
    light.Parent = beaconBase

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(220, 40)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Parent = beaconBase
    beaconName = text({ FontFace = F.Display, TextSize = 20, TextColor3 = C.Sodium, Size = UDim2.fromScale(1, 1) }, billboard)
    UIKit.stroke(beaconName, C.Ink, 1.5, 0.2)

    model.Parent = Workspace.CurrentCamera -- local only
    beacon = model
end

local function setBeacon(target: Vector3?, label: string?)
    if not beacon then
        buildBeacon()
    end
    local model = beacon :: Model
    if not target then
        model.Parent = nil
        return
    end
    beaconBase.Position = target + Vector3.new(0, 0.5, 0)
    beaconRing.Position = target + Vector3.new(0, 0.06, 0)
    beaconName.Text = label or ""
    model.Parent = Workspace.CurrentCamera
end

local function render(info: Types.TutorialStepInfo)
    if not card then
        buildCard(info.total)
    end
    local root = card :: Frame
    for i, tick in ticks do
        tick.ImageColor3 = if info.kind == "done" or i < info.step then C.Sodium elseif i == info.step then C.Chalk else C.Dim
    end

    if info.kind == "tagged" then
        titleLabel.Text = "Tagged!"
        titleLabel.TextColor3 = C.Signal
        hintLabel.Text = "A guard got you, so it's back home. Keep going."
        UIKit.shake(root, 6)
        task.delay(1.6, function()
            if titleLabel.Text == "Tagged!" then
                titleLabel.Text = info.title
                titleLabel.TextColor3 = C.Chalk
                hintLabel.Text = info.hint
            end
        end)
        return
    end

    stepLabel.Text = if info.kind == "done" then "ALL DONE" else `STEP {info.step} OF {info.total}`
    titleLabel.Text = info.title
    titleLabel.TextColor3 = if info.kind == "done" then C.Sodium else C.Chalk
    hintLabel.Text = info.hint
    setKeys(info.keys)
    setBeacon(if info.kind == "done" then nil else info.target, info.targetLabel)

    if info.kind == "done" or info.step > lastStep and lastStep > 0 then
        SoundController.PlaySFX("CheckpointChime", Vector2.new(1.05, 1.15))
        local finished = ticks[if info.kind == "done" then info.total else info.step - 1]
        if finished then
            UIKit.pop(finished, 1.8)
        end
    end
    UIKit.pop(titleLabel, 1.15)
    lastStep = info.step
end

function TutorialController.Init()
    Remotes.GetEvent("TutorialStep").OnClientEvent:Connect(render)
    -- Pulse the beacon ring
    RunService.RenderStepped:Connect(function()
        if beacon and beacon.Parent then
            local s = RING_SIZE + math.sin(os.clock() * 3) * 1.2
            beaconRing.Size = Vector3.new(s, 0.05, s)
        end
    end)
end

return TutorialController
