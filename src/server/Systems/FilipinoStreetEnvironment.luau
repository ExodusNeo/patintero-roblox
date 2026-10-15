--!strict
--[[
    FilipinoStreetEnvironment.luau
    Procedurally constructs an authentic Filipino barangay street environment ("Kalye"):
    - "Dapit-Hapon" (Golden Hour sunset lighting)
    - Corner Sari-Sari Store with corrugated metal roof, grills, crates, and snack racks (combined Model)
    - Electric utility poles with tangled overhead "spaghetti" wires and streetlamps (grouped Models)
    - Barangay fiesta "Banderitas" (grouped by row as Models)
    - Street curbs, cracked concrete sidewalks, and a makeshift wooden basketball hoop (combined Models)
    - Weathered cinder block (hollow blocks) perimeter walls with hand-painted signages (grouped Models)
]]

local Lighting = game:GetService("Lighting")

local FilipinoStreetEnvironment = {}

-- 1. Authentic "Dapit-Hapon" (Late Afternoon Sunset) Lighting
function FilipinoStreetEnvironment.SetupGoldenHourLighting()
    Lighting.ClockTime = 17.2 -- 5:12 PM golden hour
    Lighting.GeographicLatitude = 14.5995 -- Manila, Philippines coordinates
    Lighting.Brightness = 2.4
    Lighting.OutdoorAmbient = Color3.fromRGB(140, 115, 95)
    Lighting.Ambient = Color3.fromRGB(90, 80, 75)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 210, 150)
    Lighting.ColorShift_Bottom = Color3.fromRGB(180, 140, 100)
    Lighting.ShadowSoftness = 0.2
    Lighting.EnvironmentDiffuseScale = 0.45 -- less blue sky fill, so shade stays warm instead of navy
    Lighting.GlobalShadows = true

    -- Soft warm atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.3
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(255, 200, 140)
    atmosphere.Decay = Color3.fromRGB(220, 120, 80)
    atmosphere.Glare = 0.4
    atmosphere.Haze = 1.2

    -- Subtle bloom for sunset glow
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.6
    bloom.Size = 24
    bloom.Threshold = 1.2

    -- Warm, slightly punchy grade so the painted houses and banderitas pop against the sunset
    local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
    grade.Contrast = 0.08
    grade.Saturation = 0.12
    grade.TintColor = Color3.fromRGB(255, 244, 230)
    grade.Parent = Lighting

    local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
    sunRays.Intensity = 0.06
    sunRays.Spread = 0.55
    sunRays.Parent = Lighting
end

-- Decoration never needs touch events; non-solid decor also skips raycasts (so flags and wires never block
-- a tag's line of sight) and tiny parts skip shadows. Run on a finished map.
function FilipinoStreetEnvironment.OptimizeDecor(root: Instance)
    for _, part in root:GetDescendants() do
        if part:IsA("BasePart") and not part:IsA("SpawnLocation") then
            part.CanTouch = false
            if not part.CanCollide then
                part.CanQuery = false
            end
            if math.max(part.Size.X, part.Size.Y, part.Size.Z) < 1.5 then
                part.CastShadow = false
            end
        end
    end
end

local function createPart(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance, canCollide: boolean?): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Material = material
    part.Color = color
    part.Anchored = true
    part.CanCollide = if canCollide ~= nil then canCollide else true
    part.CastShadow = true
    part.Parent = parent
    return part
end

-- 2. Sari-Sari Store ("Tindahan ni Aling Nena") - Combined Model with component sub-models
function FilipinoStreetEnvironment.BuildSariSariStore(parent: Instance, origin: Vector3)
    local storeModel = Instance.new("Model")
    storeModel.Name = "SariSariStore"
    storeModel.Parent = parent

    local baseCF = CFrame.new(origin) * CFrame.Angles(0, math.rad(-90), 0)

    -- Concrete hollow block main building (PrimaryPart)
    local storeWalls = createPart("StoreWalls", Vector3.new(24, 14, 18), baseCF * CFrame.new(0, 7, 0), Enum.Material.Concrete, Color3.fromRGB(150, 150, 150), storeModel)
    storeModel.PrimaryPart = storeWalls

    -- Corrugated metal slanted roof (Yero)
    local roofCF = baseCF * CFrame.new(0, 15.5, 2) * CFrame.Angles(math.rad(15), 0, 0)
    createPart("MetalRoof", Vector3.new(26, 0.6, 22), roofCF, Enum.Material.CorrodedMetal, Color3.fromRGB(140, 110, 95), storeModel)

    -- Front Service Counter (Tindahan counter)
    createPart("CounterLedge", Vector3.new(14, 1.2, 4), baseCF * CFrame.new(0, 4, 9.5), Enum.Material.WoodPlanks, Color3.fromRGB(130, 85, 55), storeModel)

    -- Metal Grills Sub-Model (Rehas)
    local grillsModel = Instance.new("Model")
    grillsModel.Name = "WindowGrills"
    grillsModel.Parent = storeModel
    createPart("WindowOpening", Vector3.new(12, 6, 0.4), baseCF * CFrame.new(0, 7.5, 9), Enum.Material.Metal, Color3.fromRGB(40, 40, 40), grillsModel, false)
    for i = -5, 5, 2 do
        createPart("GrillBar", Vector3.new(0.3, 6, 0.3), baseCF * CFrame.new(i, 7.5, 9), Enum.Material.Metal, Color3.fromRGB(30, 30, 30), grillsModel, false)
    end

    -- Hand-painted Store Signage Sub-Model
    local signModel = Instance.new("Model")
    signModel.Name = "StoreSignage"
    signModel.Parent = storeModel
    local signPart = createPart("StoreSign", Vector3.new(16, 3.5, 0.6), baseCF * CFrame.new(0, 12, 9.4), Enum.Material.WoodPlanks, Color3.fromRGB(230, 220, 190), signModel)
    signModel.PrimaryPart = signPart

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Back
    surfaceGui.CanvasSize = Vector2.new(800, 200)
    surfaceGui.Parent = signPart

    local signText = Instance.new("TextLabel")
    signText.Size = UDim2.new(1, 0, 0.65, 0)
    signText.Position = UDim2.new(0, 0, 0.05, 0)
    signText.BackgroundTransparency = 1
    signText.Font = Enum.Font.FredokaOne
    signText.Text = "ALING NENA'S STORE"
    signText.TextColor3 = Color3.fromRGB(180, 30, 30)
    signText.TextScaled = true
    signText.Parent = surfaceGui

    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0.3, 0)
    subText.Position = UDim2.new(0, 0, 0.65, 0)
    subText.BackgroundTransparency = 1
    subText.Font = Enum.Font.GothamBold
    subText.Text = "ICE TUBIG • CHICHIRYA • SOFTDRINKS"
    subText.TextColor3 = Color3.fromRGB(30, 60, 140)
    subText.TextScaled = true
    subText.Parent = surfaceGui

    -- Hanging snack packs Sub-Model (Chichirya strings)
    local snackRacksModel = Instance.new("Model")
    snackRacksModel.Name = "SnackRacks"
    snackRacksModel.Parent = storeModel

    local snackColors = {
        Color3.fromRGB(220, 50, 40),  -- Red
        Color3.fromRGB(240, 200, 30), -- Yellow
        Color3.fromRGB(40, 160, 60),  -- Green
        Color3.fromRGB(220, 120, 30), -- Orange
    }
    local colIndex = 0
    for col = -4, 4, 2 do
        colIndex += 1
        for row = 0, 2 do
            local color = snackColors[((colIndex + row) % #snackColors) + 1]
            createPart("SnackPack", Vector3.new(0.9, 1.2, 0.2), baseCF * CFrame.new(col, 9.2 - (row * 1.3), 8.8), Enum.Material.Plastic, color, snackRacksModel, false)
        end
    end

    -- Stacked Soda Crates Sub-Model (Coke & Royal crates)
    local cratesModel = Instance.new("Model")
    cratesModel.Name = "SodaCrates"
    cratesModel.Parent = storeModel
    local crateColors = { Color3.fromRGB(190, 25, 25), Color3.fromRGB(230, 160, 20) }
    for i = 0, 2 do
        local crateCF = baseCF * CFrame.new(9, 1.2 + (i * 2.1), 10.5)
        createPart("SodaCrate", Vector3.new(3.5, 2, 2.5), crateCF, Enum.Material.Plastic, crateColors[(i % 2) + 1], cratesModel)
    end

    -- Classic Blue Monobloc Plastic Chair Sub-Model
    local chairModel = Instance.new("Model")
    chairModel.Name = "MonoblocChair"
    chairModel.Parent = storeModel
    local chairBase = baseCF * CFrame.new(-9, 0, 10.5)
    local chairSeat = createPart("ChairSeat", Vector3.new(2.4, 0.4, 2.4), chairBase * CFrame.new(0, 2.2, 0), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)
    chairModel.PrimaryPart = chairSeat
    createPart("ChairBack", Vector3.new(2.4, 2.6, 0.3), chairBase * CFrame.new(0, 3.6, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)
    createPart("ChairLeg1", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(-1, 1.1, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)
    createPart("ChairLeg2", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(1, 1.1, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)
    createPart("ChairLeg3", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(-1, 1.1, 1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)
    createPart("ChairLeg4", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(1, 1.1, 1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), chairModel)

    -- Warm incandescent bulb under store roof
    local bulb = createPart("StoreBulb", Vector3.new(0.6, 0.6, 0.6), baseCF * CFrame.new(0, 11, 8.5), Enum.Material.Neon, Color3.fromRGB(255, 230, 180), storeModel, false)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 210, 140)
    light.Brightness = 2.5
    light.Range = 22
    light.Shadows = true
    light.Parent = bulb
end

-- 3. Utility Poles with Tangled Overhead "Spaghetti" Wires & Streetlamps (Grouped Models)
-- Shared by poles and banderitas so the flags are always strung between real poles.
local POLE_HEIGHT = 28
local function poleLayout(courtWidth: number, courtLength: number): (number, { number })
    return courtWidth / 2 + 7, { -courtLength / 2, 0, courtLength / 2 }
end

function FilipinoStreetEnvironment.BuildUtilityPolesAndWires(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local polesFolder = Instance.new("Folder")
    polesFolder.Name = "UtilityPoles"
    polesFolder.Parent = parent

    local halfW, poleZPositions = poleLayout(courtWidth, courtLength)
    local poleHeight = POLE_HEIGHT

    local leftPoles: { Vector3 } = {}
    local rightPoles: { Vector3 } = {}

    for poleIndex, z in ipairs(poleZPositions) do
        -- Left Pole Model
        local leftPoleModel = Instance.new("Model")
        leftPoleModel.Name = string.format("LeftPole_%d", poleIndex)
        leftPoleModel.Parent = polesFolder

        local leftPos = Vector3.new(-halfW, centerY, z)
        local leftPole = createPart("ElectricPole", Vector3.new(1.8, poleHeight, 1.8), CFrame.new(leftPos + Vector3.new(0, poleHeight / 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), leftPoleModel)
        leftPoleModel.PrimaryPart = leftPole
        createPart("CrossArm", Vector3.new(7, 0.8, 0.8), CFrame.new(leftPos + Vector3.new(0, poleHeight - 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), leftPoleModel)
        table.insert(leftPoles, leftPos + Vector3.new(0, poleHeight - 2, 0))

        -- Streetlamp Model on middle left pole
        if z == 0 then
            local lampModel = Instance.new("Model")
            lampModel.Name = "StreetLamp"
            lampModel.Parent = leftPoleModel

            createPart("LampArm", Vector3.new(6, 0.4, 0.4), CFrame.new(leftPos + Vector3.new(3, poleHeight - 4, 0)), Enum.Material.Metal, Color3.fromRGB(50, 50, 50), lampModel, false)
            createPart("LampShade", Vector3.new(2.5, 0.5, 2.5), CFrame.new(leftPos + Vector3.new(5.5, poleHeight - 4.3, 0)), Enum.Material.Metal, Color3.fromRGB(40, 60, 40), lampModel, false)
            local bulb = createPart("StreetBulb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(leftPos + Vector3.new(5.5, poleHeight - 4.8, 0)), Enum.Material.Neon, Color3.fromRGB(255, 235, 170), lampModel, false)

            local pLight = Instance.new("PointLight")
            pLight.Color = Color3.fromRGB(255, 220, 160)
            pLight.Brightness = 3
            pLight.Range = 38
            pLight.Shadows = true
            pLight.Parent = bulb
        end

        -- Right Pole Model
        local rightPoleModel = Instance.new("Model")
        rightPoleModel.Name = string.format("RightPole_%d", poleIndex)
        rightPoleModel.Parent = polesFolder

        local rightPos = Vector3.new(halfW, centerY, z)
        local rightPole = createPart("ElectricPole", Vector3.new(1.8, poleHeight, 1.8), CFrame.new(rightPos + Vector3.new(0, poleHeight / 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), rightPoleModel)
        rightPoleModel.PrimaryPart = rightPole
        createPart("CrossArm", Vector3.new(7, 0.8, 0.8), CFrame.new(rightPos + Vector3.new(0, poleHeight - 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), rightPoleModel)
        table.insert(rightPoles, rightPos + Vector3.new(0, poleHeight - 2, 0))
    end

    -- Tangled Overhead Wire Clusters Sub-Model (Spaghetti wires)
    local wiresModel = Instance.new("Model")
    wiresModel.Name = "SpaghettiWires"
    wiresModel.Parent = polesFolder

    local function createWire(p1: Vector3, p2: Vector3, droop: number)
        local midpoint = (p1 + p2) / 2 - Vector3.new(0, droop, 0)
        createPart("PowerWire", Vector3.new(0.18, 0.18, (midpoint - p1).Magnitude), CFrame.lookAt((p1 + midpoint) / 2, midpoint), Enum.Material.Rubber, Color3.fromRGB(20, 20, 20), wiresModel, false)
        createPart("PowerWire", Vector3.new(0.18, 0.18, (p2 - midpoint).Magnitude), CFrame.lookAt((midpoint + p2) / 2, p2), Enum.Material.Rubber, Color3.fromRGB(20, 20, 20), wiresModel, false)
    end

    -- Cross-street wires
    for i = 1, #leftPoles do
        createWire(leftPoles[i] + Vector3.new(0, 0, 1), rightPoles[i] + Vector3.new(0, 0, 1), 2.2)
        createWire(leftPoles[i] + Vector3.new(0, 0, -1), rightPoles[i] + Vector3.new(0, 0, -1), 3.0)
    end

    -- Longitudinal street wires
    for i = 1, #leftPoles - 1 do
        createWire(leftPoles[i], leftPoles[i + 1], 1.5)
        createWire(rightPoles[i], rightPoles[i + 1], 1.5)
    end
end

-- 4. Barangay Fiesta "Banderitas" (Grouped by Row Models)
function FilipinoStreetEnvironment.BuildBanderitas(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local banderitasFolder = Instance.new("Folder")
    banderitasFolder.Name = "Banderitas"
    banderitasFolder.Parent = parent

    local colors = {
        Color3.fromRGB(235, 45, 45),   -- Red
        Color3.fromRGB(245, 215, 30),  -- Yellow
        Color3.fromRGB(35, 130, 240),  -- Blue
        Color3.fromRGB(40, 200, 70),   -- Green
        Color3.fromRGB(250, 250, 250), -- White
    }

    -- Rows zig-zag between the poles (left pole i -> right pole i+1 and back), tied just under the cross-arms.
    local halfW, poleZ = poleLayout(courtWidth, courtLength)
    local tieY = centerY + POLE_HEIGHT - 5
    local rows: { { Vector3 } } = {}
    for i = 1, #poleZ - 1 do
        table.insert(rows, { Vector3.new(-halfW, tieY, poleZ[i]), Vector3.new(halfW, tieY, poleZ[i + 1]) })
        table.insert(rows, { Vector3.new(halfW, tieY, poleZ[i]), Vector3.new(-halfW, tieY, poleZ[i + 1]) })
    end

    for rowIndex, ends in rows do
        local rowModel = Instance.new("Model")
        rowModel.Name = string.format("BanderitasRow_%d", rowIndex)

        local pStart, pEnd = ends[1], ends[2]
        local direction = (pEnd - pStart).Unit
        local steps = math.floor((pEnd - pStart).Magnitude / 2.2)
        local previous = pStart
        for step = 1, steps do
            local alpha = step / steps
            local pos = pStart:Lerp(pEnd, alpha) - Vector3.new(0, math.sin(alpha * math.pi) * 4, 0) -- catenary droop

            -- String segment from the previous point; flags hang just below it
            local cord = createPart("String", Vector3.new(0.08, 0.08, (pos - previous).Magnitude),
                CFrame.lookAt((previous + pos) / 2, pos), Enum.Material.Fabric, Color3.fromRGB(235, 230, 215), rowModel, false)
            cord.CastShadow = false
            previous = pos

            if step < steps then
                local flag = Instance.new("WedgePart")
                flag.Name = "Flag"
                flag.Size = Vector3.new(0.1, 1.4, 1.2)
                flag.CFrame = CFrame.lookAt(pos - Vector3.new(0, 0.75, 0), pos - Vector3.new(0, 0.75, 0) + direction) * CFrame.Angles(math.pi, 0, 0)
                flag.Material = Enum.Material.SmoothPlastic
                flag.Color = colors[(step % #colors) + 1]
                flag.Anchored = true
                flag.CanCollide = false
                flag.CastShadow = false
                flag.Parent = rowModel
            end
        end
        rowModel.Parent = banderitasFolder
    end
end

-- 5. Makeshift Street Basketball Hoop (Combined Model)
function FilipinoStreetEnvironment.BuildMakeshiftBasketballHoop(parent: Instance, position: Vector3)
    local hoopModel = Instance.new("Model")
    hoopModel.Name = "BarangayBasketballHoop"
    hoopModel.Parent = parent

    local baseCF = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)

    -- Weathered plywood backboard with painted red inner square
    local backboard = createPart("Backboard", Vector3.new(6, 4, 0.4), baseCF * CFrame.new(0, 14, 0), Enum.Material.Wood, Color3.fromRGB(220, 215, 205), hoopModel)
    hoopModel.PrimaryPart = backboard

    createPart("TargetSquare", Vector3.new(2.2, 1.8, 0.05), baseCF * CFrame.new(0, 13.5, 0.22), Enum.Material.SmoothPlastic, Color3.fromRGB(180, 40, 40), hoopModel, false)

    -- Metal rim
    createPart("Rim", Vector3.new(2, 0.3, 2), baseCF * CFrame.new(0, 12.5, 1.2), Enum.Material.Metal, Color3.fromRGB(220, 80, 30), hoopModel, false)

    -- Supporting angle brackets
    createPart("Bracket", Vector3.new(0.4, 2, 0.4), baseCF * CFrame.new(0, 12, -0.6) * CFrame.Angles(math.rad(25), 0, 0), Enum.Material.Metal, Color3.fromRGB(60, 60, 60), hoopModel, false)
end

-- 6. Perimeter Concrete Hollow Block (CHB) Walls with Barangay Signages (Combined Models)
function FilipinoStreetEnvironment.BuildPerimeterWalls(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local wallsModel = Instance.new("Model")
    wallsModel.Name = "PerimeterWalls"
    wallsModel.Parent = parent

    local halfW = courtWidth / 2
    local leftWallX = -halfW - 9 -- Behind left sidewalk
    local rightWallX = halfW + 27 -- Behind Sari-Sari store
    local halfL = courtLength / 2 + 30
    local wallHeight = 8

    -- Left Wall (CHB with concrete post columns)
    createPart("LeftCHBWall", Vector3.new(1.5, wallHeight, halfL * 2), CFrame.new(leftWallX, centerY + wallHeight / 2, 0), Enum.Material.Concrete, Color3.fromRGB(140, 140, 145), wallsModel)

    -- Right Wall (behind Sari-Sari store)
    createPart("RightCHBWall", Vector3.new(1.5, wallHeight, halfL * 2), CFrame.new(rightWallX, centerY + wallHeight / 2, 0), Enum.Material.Concrete, Color3.fromRGB(140, 140, 145), wallsModel)

    -- Hand-painted Barangay Wall Signage Sub-Model ("BAWAL MAGTAPON NG BASURA")
    local signModel = Instance.new("Model")
    signModel.Name = "BawalSign"
    signModel.Parent = wallsModel

    local signWallPart = createPart("BawalSignPart", Vector3.new(0.2, 3, 10), CFrame.new(leftWallX + 0.8, centerY + 4.5, -10), Enum.Material.SmoothPlastic, Color3.fromRGB(240, 240, 240), signModel)
    signModel.PrimaryPart = signWallPart

    local sGui = Instance.new("SurfaceGui")
    sGui.Face = Enum.NormalId.Right
    sGui.CanvasSize = Vector2.new(600, 180)
    sGui.Parent = signWallPart

    local bawalText = Instance.new("TextLabel")
    bawalText.Size = UDim2.new(1, 0, 0.6, 0)
    bawalText.Position = UDim2.new(0, 0, 0.05, 0)
    bawalText.BackgroundTransparency = 1
    bawalText.Font = Enum.Font.GothamBlack
    bawalText.Text = "BAWAL MAGTAPON NG BASURA"
    bawalText.TextColor3 = Color3.fromRGB(200, 30, 30)
    bawalText.TextScaled = true
    bawalText.Parent = sGui

    local multaText = Instance.new("TextLabel")
    multaText.Size = UDim2.new(1, 0, 0.35, 0)
    multaText.Position = UDim2.new(0, 0, 0.6, 0)
    multaText.BackgroundTransparency = 1
    multaText.Font = Enum.Font.GothamMedium
    multaText.Text = "MULTA: P1,000 O KULONG - BRGY. ORDINANCE"
    multaText.TextColor3 = Color3.fromRGB(40, 40, 40)
    multaText.TextScaled = true
    multaText.Parent = sGui
end

-- Asphalt street with raised sidewalks and painted curbs, centered on the origin along Z.
function FilipinoStreetEnvironment.BuildStreet(parent: Instance, width: number, length: number, centerY: number)
    createPart("StreetAsphalt", Vector3.new(width + 4, 2, length), CFrame.new(0, centerY - 1, 0),
        Enum.Material.Asphalt, Color3.fromRGB(104, 96, 90), parent)

    local sidewalkWidth, sidewalkHeight = 8, 0.8
    for _, side in { -1, 1 } do
        local model = Instance.new("Model")
        model.Name = if side < 0 then "SidewalkLeft" else "SidewalkRight"
        local posX = side * (width / 2 + sidewalkWidth / 2 + 2)
        local walkway = createPart("Walkway", Vector3.new(sidewalkWidth, sidewalkHeight + 2, length),
            CFrame.new(posX, centerY + sidewalkHeight / 2 - 1, 0), Enum.Material.Concrete, Color3.fromRGB(155, 155, 160), model)
        model.PrimaryPart = walkway
        createPart("Curb", Vector3.new(0.6, sidewalkHeight + 0.2, length),
            CFrame.new(posX - side * sidewalkWidth / 2, centerY + sidewalkHeight / 2, 0),
            Enum.Material.Concrete, Color3.fromRGB(220, 180, 40), model) -- weathered yellow curb
        model.Parent = parent
    end
end

local HOUSE_WALLS = {
    Color3.fromRGB(236, 196, 120), Color3.fromRGB(150, 200, 170), Color3.fromRGB(240, 170, 150),
    Color3.fromRGB(170, 190, 230), Color3.fromRGB(245, 235, 200), Color3.fromRGB(215, 160, 200),
}
local HOUSE_UPPER = {
    Color3.fromRGB(120, 85, 60), Color3.fromRGB(230, 230, 220), Color3.fromRGB(90, 140, 120),
    Color3.fromRGB(200, 110, 70), Color3.fromRGB(110, 120, 160),
}
local ROOF_COLORS = {
    Color3.fromRGB(150, 70, 45), Color3.fromRGB(110, 120, 125), Color3.fromRGB(60, 110, 150), Color3.fromRGB(70, 120, 80),
}

local function decor(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance): Part
    local part = createPart(name, size, cf, material, color, parent, false)
    part.CastShadow = false
    part.CanQuery = false
    part.CanTouch = false
    return part
end

-- Grilled window: dark glass with vertical security bars (rehas).
local function window(parent: Instance, cf: CFrame, w: number, h: number)
    decor("Window", Vector3.new(w, h, 0.3), cf, Enum.Material.Glass, Color3.fromRGB(40, 50, 60), parent)
    for i = 1, 3 do
        local x = -w / 2 + i * w / 4
        decor("Grill", Vector3.new(0.15, h, 0.15), cf * CFrame.new(x, 0, -0.25), Enum.Material.Metal, Color3.fromRGB(30, 30, 30), parent)
    end
end

-- One "bahay": hollow-block ground floor, painted upper floor (most houses), grilled windows and a yero roof.
-- `cf` sits at the bottom-center of the front wall; LookVector points at the street.
local function buildHouse(parent: Instance, cf: CFrame, width: number, rng: Random)
    local house = Instance.new("Model")
    house.Name = "Bahay"
    local depth = 14
    local groundH = 9
    local upperH = if rng:NextNumber() < 0.75 then 8 else 0
    local wall = HOUSE_WALLS[rng:NextInteger(1, #HOUSE_WALLS)]

    local body = createPart("GroundFloor", Vector3.new(width, groundH, depth), cf * CFrame.new(0, groundH / 2, depth / 2),
        Enum.Material.Concrete, wall, house)
    house.PrimaryPart = body
    decor("Door", Vector3.new(3.5, 7, 0.3), cf * CFrame.new(-width / 4, 3.5, -0.1), Enum.Material.Wood, Color3.fromRGB(90, 60, 40), house)
    window(house, cf * CFrame.new(width / 4, 5, -0.1), 4, 3.5)

    local top = groundH
    if upperH > 0 then
        createPart("UpperFloor", Vector3.new(width, upperH, depth), cf * CFrame.new(0, groundH + upperH / 2, depth / 2 - 1),
            Enum.Material.WoodPlanks, HOUSE_UPPER[rng:NextInteger(1, #HOUSE_UPPER)], house)
        window(house, cf * CFrame.new(-width / 4, groundH + upperH / 2, -1.1), 4, 3.5)
        window(house, cf * CFrame.new(width / 4, groundH + upperH / 2, -1.1), 4, 3.5)
        top += upperH
    else
        -- Single-storey houses get a small yero awning over the door
        decor("Awning", Vector3.new(width * 0.6, 0.3, 3), cf * CFrame.new(-width / 6, 7.8, -1.4) * CFrame.Angles(math.rad(-15), 0, 0),
            Enum.Material.CorrodedMetal, ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)], house)
    end

    createPart("YeroRoof", Vector3.new(width + 1, 0.5, depth + 3), cf * CFrame.new(0, top + 1.6, depth / 2) * CFrame.Angles(math.rad(-12), 0, 0),
        Enum.Material.CorrodedMetal, ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)], house)

    house.Parent = parent
end

-- Row of houses side by side from `fromPos` to `toPos`, fronts facing `facing` (a flat direction).
function FilipinoStreetEnvironment.BuildHouseRow(parent: Instance, fromPos: Vector3, toPos: Vector3, facing: Vector3, seed: number): Model
    local row = Instance.new("Model")
    row.Name = "HouseRow"
    local rng = Random.new(seed)
    local direction = (toPos - fromPos).Unit
    local total = (toPos - fromPos).Magnitude
    local along = 0
    while total - along >= 8 do
        local width = math.min(rng:NextInteger(12, 18), total - along)
        local center = fromPos + direction * (along + width / 2)
        buildHouse(row, CFrame.lookAt(center, center + facing), width - 0.4, rng)
        along += width
    end
    row.Parent = parent
    return row
end

-- Barangay welcome arch spanning a street. `cf` = ground center, LookVector = side the text faces.
function FilipinoStreetEnvironment.BuildBarangayArch(parent: Instance, cf: CFrame, span: number, text: string): Model
    local arch = Instance.new("Model")
    arch.Name = "BarangayArch"
    local height = 18
    for _, side in { -1, 1 } do
        createPart("Pillar", Vector3.new(3, height, 3), cf * CFrame.new(side * span / 2, height / 2, 0), Enum.Material.Concrete, Color3.fromRGB(240, 235, 220), arch)
    end
    local beam = createPart("Beam", Vector3.new(span + 3, 4, 2), cf * CFrame.new(0, height + 2, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(30, 80, 160), arch)
    arch.PrimaryPart = beam

    for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
        local gui = Instance.new("SurfaceGui")
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 25
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(255, 215, 0)
        label.Text = text
        label.Parent = gui
        gui.Parent = beam
    end

    arch.Parent = parent
    return arch
end

-- Barangay covered court (hub). `cf` = the court's center on the ground; local +Z points at the entrance end
-- (the tarpaulin side). Painted floor: two half-court decals from tools/blender/court_texture.py (`texture`; a
-- Top-face decal's image top points at the part's +Z, so each half is turned to put the center line at the middle), a hoop at each end, steel columns with arched trusses under a GI-sheet roof,
-- hanging floodlights, and a tarpaulin over the entrance.
local COURT_W, COURT_HALF, COURT_BORDER = 47, 44, 3
local ROOF_HALF_SPAN, ROOF_EAVE, ROOF_CROWN = 36, 24, 34
local STEEL = Color3.fromRGB(35, 75, 150)
local CHALK = Color3.fromRGB(240, 239, 233)

-- Thin part from a to b (world points): truss members, rims, nets.
local function beam(name: string, a: Vector3, b: Vector3, thick: number, material: Enum.Material, color: Color3, parent: Instance): Part
    local length = (b - a).Magnitude
    return createPart(name, Vector3.new(thick, thick, length), CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2), material, color, parent, false)
end

local function surfaceText(part: BasePart, face: Enum.NormalId, pps: number): SurfaceGui
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = pps
    gui.LightInfluence = 1
    gui.Parent = part
    return gui
end

local function label(gui: Instance, text: string, font: Font, color: Color3, y: number, h: number): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.fromScale(0.04, y)
    l.Size = UDim2.fromScale(0.92, h)
    l.FontFace = font
    l.TextScaled = true
    l.TextColor3 = color
    l.Text = text
    l.Parent = gui
    return l
end

local SARPANCH = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy)
local TITILLIUM = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)

local function buildHoop(court: Model, endCf: CFrame) -- endCf: on the baseline, local +Z pointing out of the court
    local white = Color3.fromRGB(245, 245, 240)
    createPart("HoopPost", Vector3.new(1, 13, 1), endCf * CFrame.new(0, 6.5, 3.5), Enum.Material.Metal, STEEL, court)
    createPart("PostPad", Vector3.new(1.6, 5, 1.6), endCf * CFrame.new(0, 2.5, 3.5), Enum.Material.Fabric, Color3.fromRGB(200, 50, 50), court, false)
    createPart("HoopArm", Vector3.new(0.6, 0.6, 7.6), endCf * CFrame.new(0, 12.4, -0.3), Enum.Material.Metal, STEEL, court, false)
    beam("HoopBrace", endCf:PointToWorldSpace(Vector3.new(0, 8.5, 3.5)), endCf:PointToWorldSpace(Vector3.new(0, 12.4, -0.5)), 0.4, Enum.Material.Metal, STEEL, court)

    local board = createPart("Backboard", Vector3.new(5.6, 3.3, 0.25), endCf * CFrame.new(0, 10.65, -3.75), Enum.Material.SmoothPlastic, white, court)
    local red = Color3.fromRGB(200, 40, 40)
    for _, p in { { 0, 11.37, 1.9, 0.15 }, { 0, 9.97, 1.9, 0.15 }, { -0.95, 10.67, 0.15, 1.4 }, { 0.95, 10.67, 0.15, 1.4 } } do
        decor("BoardMark", Vector3.new(p[3], p[4], 0.05), endCf * CFrame.new(p[1], p[2], -3.9), Enum.Material.SmoothPlastic, red, court)
    end
    local gui = surfaceText(board, Enum.NormalId.Front, 40)
    label(gui, "BRGY. PATINTERO", SARPANCH, red, 0.04, 0.2)

    local rim = endCf * CFrame.new(0, 9.5, -4.6)
    local orange = Color3.fromRGB(235, 100, 30)
    decor("RimBracket", Vector3.new(0.3, 0.12, 0.6), endCf * CFrame.new(0, 9.5, -4.05), Enum.Material.Metal, orange, court)
    local function ringPoint(i: number, r: number, y: number): Vector3
        local a = i / 12 * math.pi * 2
        return rim:PointToWorldSpace(Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
    end
    for i = 0, 11 do
        beam("Rim", ringPoint(i, 0.75, 0), ringPoint(i + 1, 0.75, 0), 0.12, Enum.Material.Metal, orange, court)
        if i % 2 == 0 then
            beam("Net", ringPoint(i, 0.75, 0), ringPoint(i + 1, 0.45, -1.3), 0.06, Enum.Material.Fabric, white, court)
            beam("Net", ringPoint(i + 1, 0.75, 0), ringPoint(i, 0.45, -1.3), 0.06, Enum.Material.Fabric, white, court)
        end
    end
end

function FilipinoStreetEnvironment.BuildCoveredCourt(parent: Instance, cf: CFrame, texture: string): Model
    local court = Instance.new("Model")
    court.Name = "CoveredCourt"
    local halfW, halfL = COURT_W / 2 + COURT_BORDER, COURT_HALF + COURT_BORDER

    for _, dir in { -1, 1 } do
        local half = createPart("Floor", Vector3.new(halfW * 2, 0.4, halfL), cf * CFrame.new(0, 0.2, dir * halfL / 2)
            * CFrame.Angles(0, if dir == 1 then math.pi else 0, 0), Enum.Material.Concrete, Color3.fromRGB(150, 40, 44), court)
        local decal = Instance.new("Decal")
        decal.Face = Enum.NormalId.Top
        decal.Texture = texture
        decal.Parent = half
        buildHoop(court, cf * CFrame.new(0, 0, dir * COURT_HALF) * CFrame.Angles(0, if dir == 1 then 0 else math.pi, 0))
    end
    -- A Top-face SurfaceGui runs along the part's Z: the name lies along the court, read from a sideline
    local seal = createPart("CenterName", Vector3.new(3.6, 0.05, 16), cf * CFrame.new(0, 0.43, 0), Enum.Material.SmoothPlastic, CHALK, court, false)
    seal.Transparency = 1
    label(surfaceText(seal, Enum.NormalId.Top, 40), "BRGY. PATINTERO", SARPANCH, CHALK, 0, 1)

    -- Roof: GI sheets on a shallow arch from eave to eave, carried by trusses on steel columns every 16 studs
    local sag = ROOF_CROWN - ROOF_EAVE
    local radius = (ROOF_HALF_SPAN ^ 2 + sag ^ 2) / (2 * sag)
    local centerY = ROOF_CROWN - radius
    local maxAngle = math.asin(ROOF_HALF_SPAN / radius)
    local function arc(t: number, drop: number): Vector3 -- t: -1..1 across the span
        local a = t * maxAngle
        return Vector3.new(math.sin(a) * (radius - drop), centerY + math.cos(a) * (radius - drop), 0)
    end
    local roofLen, panels = halfL * 2 + 10, 12
    for i = 0, panels - 1 do
        local a, b = arc(-1 + 2 * i / panels, 0), arc(-1 + 2 * (i + 1) / panels, 0)
        local d = b - a
        createPart("RoofSheet", Vector3.new(d.Magnitude + 0.1, 0.25, roofLen), cf * CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)),
            Enum.Material.CorrodedMetal, Color3.fromRGB(86, 124, 160), court, false)
    end
    for k = -3, 3 do
        local line = cf * CFrame.new(0, 0, k * 16)
        for _, x in { -ROOF_HALF_SPAN, ROOF_HALF_SPAN } do
            createPart("Column", Vector3.new(1.2, ROOF_EAVE, 1.2), line * CFrame.new(x, ROOF_EAVE / 2, 0), Enum.Material.Metal, STEEL, court)
        end
        beam("TieBeam", line:PointToWorldSpace(Vector3.new(-ROOF_HALF_SPAN, ROOF_EAVE, 0)), line:PointToWorldSpace(Vector3.new(ROOF_HALF_SPAN, ROOF_EAVE, 0)),
            0.6, Enum.Material.Metal, STEEL, court)
        for i = 0, panels - 1 do
            beam("Chord", line:PointToWorldSpace(arc(-1 + 2 * i / panels, 0.5)), line:PointToWorldSpace(arc(-1 + 2 * (i + 1) / panels, 0.5)),
                0.5, Enum.Material.Metal, STEEL, court)
        end
        for i = 1, panels - 1, 2 do
            local top = arc(-1 + 2 * i / panels, 0.5)
            beam("Strut", line:PointToWorldSpace(Vector3.new(top.X, ROOF_EAVE, 0)), line:PointToWorldSpace(top), 0.3, Enum.Material.Metal, STEEL, court)
        end
        if k % 3 == 0 then -- floodlights hang from every third truss, over each half of the court
            for _, x in { -12, 12 } do
                decor("LampCord", Vector3.new(0.1, 1.2, 0.1), line * CFrame.new(x, ROOF_EAVE - 0.6, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(20, 20, 20), court)
                local lamp = decor("Floodlight", Vector3.new(2.2, 0.5, 1.2), line * CFrame.new(x, ROOF_EAVE - 1.4, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(225, 222, 210), court)
                local light = Instance.new("SpotLight")
                light.Face = Enum.NormalId.Bottom
                light.Angle = 110
                light.Range = 40
                light.Brightness = 2.2
                light.Color = Color3.fromRGB(255, 236, 205)
                light.Parent = lamp
            end
        end
    end

    -- Tarpaulin over the entrance (Back face = local +Z, the street side)
    local tarp = createPart("Tarpaulin", Vector3.new(34, 6, 0.1), cf * CFrame.new(0, ROOF_EAVE + 3.4, 3 * 16 + 0.4), Enum.Material.Fabric, Color3.fromRGB(248, 246, 238), court, false)
    local gui = surfaceText(tarp, Enum.NormalId.Back, 24)
    for _, stripe in { { 0, Color3.fromRGB(200, 40, 40) }, { 0.88, Color3.fromRGB(35, 75, 170) } } do
        local band = Instance.new("Frame")
        band.BorderSizePixel = 0
        band.Position = UDim2.fromScale(0, stripe[1])
        band.Size = UDim2.fromScale(1, 0.12)
        band.BackgroundColor3 = stripe[2]
        band.Parent = gui
    end
    label(gui, "BARANGAY PATINTERO", SARPANCH, Color3.fromRGB(200, 40, 40), 0.16, 0.38)
    label(gui, "COVERED COURT", SARPANCH, Color3.fromRGB(35, 75, 170), 0.52, 0.2)
    label(gui, "Proyekto ng Sangguniang Barangay", TITILLIUM, Color3.fromRGB(40, 40, 45), 0.73, 0.13)

    FilipinoStreetEnvironment.OptimizeDecor(court)
    court.Parent = parent
    return court
end

-- Concrete court bleachers. `cf` = the middle of the front edge on the ground, LookVector toward the court;
-- `tiers` steps (2.4 deep, 1.9 rise, first seat at 1.7), every riser painted `paint`. Seats are added by HubService.
function FilipinoStreetEnvironment.BuildCourtBleachers(parent: Instance, cf: CFrame, length: number, tiers: number, paint: Color3): Model
    local m = Instance.new("Model")
    m.Name = "Bleachers"
    local depth = tiers * 2.4
    for i = 1, tiers do
        local top = 1.7 + (i - 1) * 1.9
        local front = (i - 1) * 2.4
        createPart(`Tier{i}`, Vector3.new(length, top, depth - front), cf * CFrame.new(0, top / 2, (front + depth) / 2), Enum.Material.Concrete, Color3.fromRGB(150, 145, 138), m)
        decor("Riser", Vector3.new(length, 0.6, 0.05), cf * CFrame.new(0, top - 0.4, front - 0.03), Enum.Material.SmoothPlastic, paint, m)
    end
    local railY = 1.7 + (tiers - 1) * 1.9 + 1.1
    createPart("Rail", Vector3.new(length, 0.25, 0.25), cf * CFrame.new(0, railY, depth - 0.2), Enum.Material.Metal, paint, m, false)
    local posts = math.max(1, math.round(length / 8))
    for j = 0, posts do
        createPart("RailPost", Vector3.new(0.25, 1.1, 0.25), cf * CFrame.new(-length / 2 + j * length / posts, railY - 0.55, depth - 0.2),
            Enum.Material.Metal, paint, m, false)
    end
    m.Parent = parent
    return m
end

return FilipinoStreetEnvironment
