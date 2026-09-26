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
function FilipinoStreetEnvironment.BuildUtilityPolesAndWires(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local polesFolder = Instance.new("Folder")
    polesFolder.Name = "UtilityPoles"
    polesFolder.Parent = parent

    local halfW = courtWidth / 2 + 7
    local poleZPositions = { -courtLength / 2, 0, courtLength / 2 }
    local poleHeight = 28

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

    local halfW = courtWidth / 2 + 5
    local zIntervals = { -courtLength * 0.35, -courtLength * 0.15, courtLength * 0.15, courtLength * 0.35 }

    for rowIndex, z in ipairs(zIntervals) do
        local rowModel = Instance.new("Model")
        rowModel.Name = string.format("BanderitasRow_%d", rowIndex)
        rowModel.Parent = banderitasFolder

        local pLeft = Vector3.new(-halfW, centerY + 20, z)
        local pRight = Vector3.new(halfW, centerY + 20, z)
        local totalSpan = (pRight - pLeft).Magnitude
        local steps = math.floor(totalSpan / 2.2)

        for step = 0, steps do
            local alpha = step / steps
            local pos = pLeft:Lerp(pRight, alpha)
            -- Catenary curve droop
            local droop = math.sin(alpha * math.pi) * 3.5
            pos = pos - Vector3.new(0, droop, 0)

            local flag = Instance.new("WedgePart")
            flag.Name = "Flag"
            flag.Size = Vector3.new(0.1, 1.4, 1.2)
            flag.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(180), math.rad(90), 0)
            flag.Material = Enum.Material.SmoothPlastic
            flag.Color = colors[(step % #colors) + 1]
            flag.Anchored = true
            flag.CanCollide = false
            flag.CastShadow = false
            flag.Parent = rowModel
        end
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

return FilipinoStreetEnvironment
