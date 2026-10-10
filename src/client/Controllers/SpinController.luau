--!strict
--[[
    SpinController.luau
    Hub-only Styles menu (G or the STYLES button):
    - a 3D preview of your own avatar doing the selected style's pose (emotes from your Animate script)
    - your collection of rolled styles; tap one to preview it (the equipped one is starred)
    - SPIN, which shuffles through the roster and reveals the result with its pose
    The SPIN button is Modal so the mouse is free even if the camera is mouse-locked.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local SoundController = require(script.Parent.SoundController)

local SpinController = {}

local player = Players.LocalPlayer

local panel: Frame
local hintButton: TextButton
local viewport: ViewportFrame
local viewportScale: UIScale
local worldModel: WorldModel
local nameLabel: TextLabel
local rarityLabel: TextLabel
local descLabel: TextLabel
local skillsLabel: TextLabel
local collectionLabel: TextLabel
local spinButton: TextButton
local chips: { [string]: TextButton } = {}

local spinning = false
local previewId: string? = nil -- style shown in the preview; nil = the equipped one
local avatar: Model? = nil
local avatarSource: Model? = nil -- the character the preview was copied from
local poseTracks: { [string]: AnimationTrack } = {}
local currentTrack: AnimationTrack? = nil
local PODIUM_TOP = -3

local function getSpins(): number
    return (player:GetAttribute("Spins") :: number?) or 0
end

local function getOwned(): { [string]: boolean }
    local owned = {}
    for _, id in string.split((player:GetAttribute("Collection") :: string?) or "", ",") do
        owned[id] = true
    end
    return owned
end

local function equippedId(): string
    return Styles.Get(player:GetAttribute("Style") :: string?).id
end

-- Copy of your current character for the preview: scripts and sounds stripped (scripts would run
-- inside PlayerGui), root anchored, name tag hidden. Rebuilt after you respawn.
local function ensureAvatar()
    local character = player.Character
    if not character or character == avatarSource then return end
    if avatar then
        avatar:Destroy()
    end
    avatar, avatarSource, currentTrack = nil, nil, nil
    table.clear(poseTracks)

    local wasArchivable = character.Archivable
    character.Archivable = true
    local clone = character:Clone()
    character.Archivable = wasArchivable
    if not clone then return end

    for _, item in clone:GetDescendants() do
        if item:IsA("LuaSourceContainer") or item:IsA("Sound") then
            item:Destroy()
        end
    end
    local humanoid = clone:FindFirstChildOfClass("Humanoid")
    local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or not root then
        clone:Destroy()
        return
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    root.Anchored = true
    clone:PivotTo(CFrame.new()) -- faces -Z, toward the preview camera
    local box, size = clone:GetBoundingBox()
    clone:PivotTo(CFrame.new(0, PODIUM_TOP - (box.Position.Y - size.Y / 2), 0)) -- stand on the podium, any avatar height
    clone.Parent = worldModel
    avatar, avatarSource = clone, character
end

-- Loops the style's emote on the preview avatar. Tracks are loaded once per pose (Animator track limit).
local function playPose(style: Types.StyleDef)
    ensureAvatar()
    if not avatar then return end
    local humanoid = avatar:FindFirstChildOfClass("Humanoid")
    local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
    if not animator then return end

    local track = poseTracks[style.pose]
    if not track then
        local animate = player.Character and player.Character:FindFirstChild("Animate")
        local holder = animate and animate:FindFirstChild(style.pose)
        local animation = holder and holder:FindFirstChildOfClass("Animation")
        if not animation then return end
        local loaded = animator:LoadAnimation(animation)
        loaded.Looped = true
        poseTracks[style.pose] = loaded
        track = loaded
    end
    if currentTrack and currentTrack ~= track then
        currentTrack:Stop(0.25)
    end
    if not track.IsPlaying then
        track:Play(0.25)
    end
    currentTrack = track
end

local function showStyle(style: Types.StyleDef, withPose: boolean)
    local color = Styles.RarityColors[style.rarity]
    nameLabel.Text = string.upper(style.name)
    nameLabel.TextColor3 = color
    rarityLabel.Text = if style.id == equippedId() and not spinning then `{string.upper(style.rarity)}  ·  EQUIPPED` else string.upper(style.rarity)
    rarityLabel.TextColor3 = color
    descLabel.Text = style.description
    local q, e = style.skills.Q, style.skills.E
    skillsLabel.Text = `[Q] {q.name} ({q.cooldown}s)    [E] {e.name} ({e.cooldown}s)\n`
        .. `Speed x{style.speedMult}  ·  Stamina x{style.staminaMult}  ·  Reach +{style.reachBonus}`
    viewport.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.72)
    for id, chip in chips do
        local stroke = chip:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Enabled = id == style.id
        end
    end
    if withPose then
        playPose(style)
    end
end

local function refresh()
    local spins = getSpins()
    local owned = getOwned()
    local equipped = equippedId()
    hintButton.Text = `STYLES  ·  SPINS: {spins}`

    -- The server sets Style/Collection the moment it rolls; keep the result hidden until the reveal.
    if spinning then
        spinButton.Text = "ROLLING..."
        spinButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
        return
    end

    local count = 0
    for _, style in Styles.List do
        local chip = chips[style.id]
        if owned[style.id] then
            count += 1
            chip.Text = if style.id == equipped then `★ {style.name}` else style.name
            chip.TextColor3 = Color3.new(1, 1, 1)
            chip.BackgroundColor3 = Styles.RarityColors[style.rarity]:Lerp(Color3.new(0, 0, 0), 0.45)
        else
            chip.Text = "???"
            chip.TextColor3 = Color3.fromRGB(120, 120, 130)
            chip.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        end
    end
    collectionLabel.Text = `COLLECTION  {count}/{#Styles.List}  ·  tap a style to preview`

    showStyle(Styles.Get(previewId or equipped), panel.Visible)
    spinButton.Text = if spins < 1 then "NO SPINS LEFT" else `SPIN  ({spins} left)`
    spinButton.BackgroundColor3 = if spins < 1 then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(230, 60, 60)
end

local function setOpen(open: boolean)
    panel.Visible = open
    -- The skill bar peeks out under the menu and would spoil a roll's new skill names
    local skillBar = player.PlayerGui:FindFirstChild("SkillBar")
    if skillBar and skillBar:IsA("ScreenGui") then
        skillBar.Enabled = not open
    end
    if open then
        previewId = nil
        refresh()
    elseif currentTrack then
        currentTrack:Stop(0)
        currentTrack = nil
    end
end

local function spin()
    if spinning or getSpins() < 1 then return end
    spinning = true
    previewId = nil
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

    -- Shuffle through the roster (text only; poses would hit the track limit), slowing as it settles
    local started = os.clock()
    local i = 0
    while os.clock() - started < 1.4 or not done do
        i += 1
        showStyle(Styles.List[i % #Styles.List + 1], false)
        task.wait(0.06 + (os.clock() - started) * 0.06)
    end

    spinning = false
    refresh()
    if result then
        local style = Styles.Get(result)
        showStyle(style, true)
        viewportScale.Scale = 1.12
        TweenService:Create(viewportScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        local big = style.rarity == "Epic" or style.rarity == "Legendary"
        SoundController.PlaySFX(if big then "TubigFanfare" else "CheckpointChime")
    end
end

local function makeLabel(parent: Instance, order: number, heightScale: number, font: Enum.Font, maxTextSize: number): TextLabel
    local label = Instance.new("TextLabel")
    label.LayoutOrder = order
    label.Size = UDim2.fromScale(1, heightScale)
    label.BackgroundTransparency = 1
    label.Font = font
    label.TextScaled = true
    label.TextWrapped = true
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = maxTextSize
    limit.Parent = label
    label.Parent = parent
    return label
end

local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpinMenu"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    hintButton = Instance.new("TextButton")
    hintButton.Position = UDim2.fromOffset(16, 16) -- top-left; bottom-left is the touch thumbstick
    hintButton.Size = UDim2.fromOffset(220, 44) -- 44px: comfortable touch target
    hintButton.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hintButton.BackgroundTransparency = 0.3
    hintButton.Font = Enum.Font.GothamBold
    hintButton.TextSize = 14
    hintButton.TextColor3 = Color3.fromRGB(255, 215, 0)
    hintButton.Parent = gui
    Instance.new("UICorner").Parent = hintButton
    hintButton.Activated:Connect(function()
        setOpen(not panel.Visible)
    end)

    panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromScale(0.9, 0.82)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    panel.BackgroundTransparency = 0.05
    panel.Visible = false
    panel.Parent = gui
    Instance.new("UICorner").Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 85)
    stroke.Thickness = 1.5
    stroke.Parent = panel
    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MaxSize = Vector2.new(780, 440)
    sizeLimit.Parent = panel

    -- Left: avatar showcase
    viewport = Instance.new("ViewportFrame")
    viewport.Position = UDim2.fromOffset(12, 12)
    viewport.Size = UDim2.new(0.42, -18, 1, -24)
    viewport.Ambient = Color3.fromRGB(170, 170, 170)
    viewport.LightColor = Color3.new(1, 1, 1)
    viewport.LightDirection = Vector3.new(-0.5, -1, 0.6)
    viewport.Parent = panel
    Instance.new("UICorner").Parent = viewport
    viewportScale = Instance.new("UIScale")
    viewportScale.Parent = viewport
    worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewport
    local camera = Instance.new("Camera")
    camera.FieldOfView = 30
    camera.CFrame = CFrame.lookAt(Vector3.new(3.8, 1.2, -18.5), Vector3.new(0, 0.3, 0)) -- 3/4 view, whole body
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local podium = Instance.new("Part")
    podium.Shape = Enum.PartType.Cylinder
    podium.Size = Vector3.new(0.4, 6, 6)
    podium.CFrame = CFrame.new(0, PODIUM_TOP - 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
    podium.Anchored = true
    podium.Material = Enum.Material.SmoothPlastic
    podium.Color = Color3.fromRGB(60, 60, 70)
    podium.Parent = worldModel

    -- Right: details, collection, spin
    local info = Instance.new("Frame")
    info.Name = "Info"
    info.Position = UDim2.new(0.42, 6, 0, 12)
    info.Size = UDim2.new(0.58, -18, 1, -24)
    info.BackgroundTransparency = 1
    info.Parent = panel
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0.015, 0)
    list.Parent = info

    local title = makeLabel(info, 1, 0.06, Enum.Font.GothamBold, 14)
    title.Text = "YOUR STYLE"
    title.TextColor3 = Color3.fromRGB(170, 170, 185)
    nameLabel = makeLabel(info, 2, 0.13, Enum.Font.GothamBlack, 40)
    rarityLabel = makeLabel(info, 3, 0.06, Enum.Font.GothamBold, 16)
    descLabel = makeLabel(info, 4, 0.09, Enum.Font.Gotham, 15)
    skillsLabel = makeLabel(info, 5, 0.12, Enum.Font.GothamMedium, 14)
    collectionLabel = makeLabel(info, 6, 0.05, Enum.Font.GothamBold, 13)
    collectionLabel.TextColor3 = Color3.fromRGB(170, 170, 185)

    local grid = Instance.new("Frame")
    grid.LayoutOrder = 7
    grid.Size = UDim2.fromScale(1, 0.22)
    grid.BackgroundTransparency = 1
    grid.Parent = info
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.25, -6, 0.5, -6)
    gridLayout.CellPadding = UDim2.fromOffset(6, 6)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = grid
    for i, style in Styles.List do
        local chip = Instance.new("TextButton")
        chip.LayoutOrder = i
        chip.Font = Enum.Font.GothamBold
        chip.TextScaled = true
        chip.Parent = grid
        local chipLimit = Instance.new("UITextSizeConstraint")
        chipLimit.MaxTextSize = 14
        chipLimit.Parent = chip
        Instance.new("UICorner").Parent = chip
        local selected = Instance.new("UIStroke")
        selected.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        selected.Color = Color3.new(1, 1, 1)
        selected.Thickness = 2
        selected.Enabled = false
        selected.Parent = chip
        chip.Activated:Connect(function()
            if not spinning and getOwned()[style.id] then
                previewId = style.id
                showStyle(style, true)
            end
        end)
        chips[style.id] = chip
    end

    spinButton = Instance.new("TextButton")
    spinButton.Name = "SpinButton"
    spinButton.LayoutOrder = 8
    spinButton.Size = UDim2.fromScale(1, 0.15)
    spinButton.Font = Enum.Font.GothamBlack
    spinButton.TextScaled = true
    spinButton.TextColor3 = Color3.new(1, 1, 1)
    spinButton.Modal = true
    spinButton.Parent = info
    Instance.new("UICorner").Parent = spinButton
    local spinLimit = Instance.new("UITextSizeConstraint")
    spinLimit.MaxTextSize = 22
    spinLimit.Parent = spinButton
    spinButton.Activated:Connect(spin)

    local close = Instance.new("TextButton")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -6, 0, 6)
    close.Size = UDim2.fromOffset(36, 36)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.TextSize = 20
    close.TextColor3 = Color3.fromRGB(200, 200, 210)
    close.Text = "X"
    close.Parent = panel
    close.Activated:Connect(function()
        setOpen(false)
    end)
end

function SpinController.Init()
    buildUI()
    refresh()
    player:GetAttributeChangedSignal("Spins"):Connect(refresh)
    player:GetAttributeChangedSignal("Style"):Connect(refresh)
    player:GetAttributeChangedSignal("Collection"):Connect(refresh)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.G then
            setOpen(not panel.Visible)
        end
    end)
end

return SpinController
