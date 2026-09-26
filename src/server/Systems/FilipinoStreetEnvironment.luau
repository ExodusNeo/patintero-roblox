--!strict
--[[
    FilipinoStreetEnvironment.luau
    Procedurally constructs an authentic Filipino barangay street environment ("Kalye"):
    - "Dapit-Hapon" (Golden Hour sunset lighting)
    - Corner Sari-Sari Store with corrugated metal roof, grills, crates, and snack racks
    - Electric utility poles with tangled overhead "spaghetti" wires and streetlamps
    - Barangay fiesta "Banderitas" (colorful triangular bunting flags)
    - Street curbs, cracked concrete sidewalks, and a makeshift wooden basketball hoop
    - Weathered cinder block (hollow blocks) perimeter walls with hand-painted signages
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

-- 2. Sari-Sari Store ("Tindahan ni Aling Nena")
function FilipinoStreetEnvironment.BuildSariSariStore(parent: Instance, origin: Vector3)
    local storeFolder = Instance.new("Folder")
    storeFolder.Name = "SariSariStore"
    storeFolder.Parent = parent

    local baseCF = CFrame.new(origin)

    -- Concrete hollow block main building
    createPart("StoreWalls", Vector3.new(24, 14, 18), baseCF * CFrame.new(0, 7, 0), Enum.Material.Concrete, Color3.fromRGB(150, 150, 150), storeFolder)

    -- Corrugated metal slanted roof (Yero)
    local roofCF = baseCF * CFrame.new(0, 15.5, 2) * CFrame.Angles(math.rad(15), 0, 0)
    createPart("MetalRoof", Vector3.new(26, 0.6, 22), roofCF, Enum.Material.CorrodedMetal, Color3.fromRGB(140, 110, 95), storeFolder)

    -- Front Service Counter (Tindahan counter)
    createPart("CounterLedge", Vector3.new(14, 1.2, 4), baseCF * CFrame.new(0, 4, 9.5), Enum.Material.WoodPlanks, Color3.fromRGB(130, 85, 55), storeFolder)

    -- Metal Grills (Rehas)
    local windowFrame = createPart("WindowOpening", Vector3.new(12, 6, 0.4), baseCF * CFrame.new(0, 7.5, 9), Enum.Material.Metal, Color3.fromRGB(40, 40, 40), storeFolder, false)
    for i = -5, 5, 2 do
        createPart("GrillBar", Vector3.new(0.3, 6, 0.3), baseCF * CFrame.new(i, 7.5, 9), Enum.Material.Metal, Color3.fromRGB(30, 30, 30), storeFolder, false)
    end

    -- Hand-painted Store Signage
    local signPart = createPart("StoreSign", Vector3.new(16, 3.5, 0.6), baseCF * CFrame.new(0, 12, 9.4), Enum.Material.WoodPlanks, Color3.fromRGB(230, 220, 190), storeFolder)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Front
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

    -- Hanging snack packs (Chichirya strings)
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
            createPart("SnackPack", Vector3.new(0.9, 1.2, 0.2), baseCF * CFrame.new(col, 9.2 - (row * 1.3), 8.8), Enum.Material.Plastic, color, storeFolder, false)
        end
    end

    -- Stacked Soda Crates (Coke & Royal crates)
    local crateColors = { Color3.fromRGB(190, 25, 25), Color3.fromRGB(230, 160, 20) }
    for i = 0, 2 do
        local crateCF = baseCF * CFrame.new(9, 1.2 + (i * 2.1), 10.5)
        createPart("SodaCrate", Vector3.new(3.5, 2, 2.5), crateCF, Enum.Material.Plastic, crateColors[(i % 2) + 1], storeFolder)
    end

    -- Classic Blue Monobloc Plastic Chair outside
    local chairBase = baseCF * CFrame.new(-9, 0, 10.5)
    createPart("ChairSeat", Vector3.new(2.4, 0.4, 2.4), chairBase * CFrame.new(0, 2.2, 0), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)
    createPart("ChairBack", Vector3.new(2.4, 2.6, 0.3), chairBase * CFrame.new(0, 3.6, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)
    createPart("ChairLeg1", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(-1, 1.1, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)
    createPart("ChairLeg2", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(1, 1.1, -1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)
    createPart("ChairLeg3", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(-1, 1.1, 1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)
    createPart("ChairLeg4", Vector3.new(0.3, 2.2, 0.3), chairBase * CFrame.new(1, 1.1, 1), Enum.Material.Plastic, Color3.fromRGB(40, 100, 200), storeFolder)

    -- Warm incandescent bulb under store roof
    local bulb = createPart("StoreBulb", Vector3.new(0.6, 0.6, 0.6), baseCF * CFrame.new(0, 11, 8.5), Enum.Material.Neon, Color3.fromRGB(255, 230, 180), storeFolder, false)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 210, 140)
    light.Brightness = 2.5
    light.Range = 22
    light.Shadows = true
    light.Parent = bulb
end

-- 3. Utility Poles with Tangled Overhead "Spaghetti" Wires & Streetlamps
function FilipinoStreetEnvironment.BuildUtilityPolesAndWires(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local polesFolder = Instance.new("Folder")
    polesFolder.Name = "UtilityPoles"
    polesFolder.Parent = parent

    local halfW = courtWidth / 2 + 7
    local poleZPositions = { -courtLength / 2, 0, courtLength / 2 }
    local poleHeight = 28

    local leftPoles: { Vector3 } = {}
    local rightPoles: { Vector3 } = {}

    for _, z in ipairs(poleZPositions) do
        -- Left Pole
        local leftPos = Vector3.new(-halfW, centerY, z)
        local leftPole = createPart("ElectricPole", Vector3.new(1.8, poleHeight, 1.8), CFrame.new(leftPos + Vector3.new(0, poleHeight / 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), polesFolder)
        createPart("CrossArm", Vector3.new(7, 0.8, 0.8), CFrame.new(leftPos + Vector3.new(0, poleHeight - 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), polesFolder)
        table.insert(leftPoles, leftPos + Vector3.new(0, poleHeight - 2, 0))

        -- Right Pole
        local rightPos = Vector3.new(halfW, centerY, z)
        local rightPole = createPart("ElectricPole", Vector3.new(1.8, poleHeight, 1.8), CFrame.new(rightPos + Vector3.new(0, poleHeight / 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), polesFolder)
        createPart("CrossArm", Vector3.new(7, 0.8, 0.8), CFrame.new(rightPos + Vector3.new(0, poleHeight - 2, 0)), Enum.Material.Wood, Color3.fromRGB(60, 45, 35), polesFolder)
        table.insert(rightPoles, rightPos + Vector3.new(0, poleHeight - 2, 0))

        -- Streetlamp on mid poles
        if z == 0 then
            local lampArm = createPart("LampArm", Vector3.new(6, 0.4, 0.4), CFrame.new(leftPos + Vector3.new(3, poleHeight - 4, 0)), Enum.Material.Metal, Color3.fromRGB(50, 50, 50), polesFolder, false)
            local lampShade = createPart("LampShade", Vector3.new(2.5, 0.5, 2.5), CFrame.new(leftPos + Vector3.new(5.5, poleHeight - 4.3, 0)), Enum.Material.Metal, Color3.fromRGB(40, 60, 40), polesFolder, false)
            local bulb = createPart("StreetBulb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(leftPos + Vector3.new(5.5, poleHeight - 4.8, 0)), Enum.Material.Neon, Color3.fromRGB(255, 235, 170), polesFolder, false)

            local pLight = Instance.new("PointLight")
            pLight.Color = Color3.fromRGB(255, 220, 160)
            pLight.Brightness = 3
            pLight.Range = 38
            pLight.Shadows = true
            pLight.Parent = bulb
        end
    end

    -- Tangled Overhead Wire Clusters (Spaghetti wires)
    local function createWire(p1: Vector3, p2: Vector3, droop: number)
        local midpoint = (p1 + p2) / 2 - Vector3.new(0, droop, 0)
        local wire1 = createPart("PowerWire", Vector3.new(0.18, 0.18, (midpoint - p1).Magnitude), CFrame.lookAt((p1 + midpoint) / 2, midpoint), Enum.Material.Rubber, Color3.fromRGB(20, 20, 20), polesFolder, false)
        local wire2 = createPart("PowerWire", Vector3.new(0.18, 0.18, (p2 - midpoint).Magnitude), CFrame.lookAt((midpoint + p2) / 2, p2), Enum.Material.Rubber, Color3.fromRGB(20, 20, 20), polesFolder, false)
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

-- 4. Barangay Fiesta "Banderitas" (Colorful Triangular Buntings)
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

    for _, z in ipairs(zIntervals) do
        local pLeft = Vector3.new(-halfW, centerY + 20, z)
        local pRight = Vector3.new(halfW, centerY + 20, z)
        local totalSpan = (pRight - pLeft).Magnitude
        local steps = math.floor(totalSpan / 2.2)

        for step = 0, steps do
            local alpha = step / steps
            local pos = pLeft:Lerp(pRight, alpha)
            -- Catary curve droop
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
            flag.Parent = banderitasFolder
        end
    end
end

-- 5. Makeshift Street Basketball Hoop (Mounted to Utility Pole)
function FilipinoStreetEnvironment.BuildMakeshiftBasketballHoop(parent: Instance, position: Vector3)
    local hoopFolder = Instance.new("Folder")
    hoopFolder.Name = "BarangayBasketballHoop"
    hoopFolder.Parent = parent

    local baseCF = CFrame.new(position)

    -- Weathered plywood backboard with painted red inner square
    local backboard = createPart("Backboard", Vector3.new(6, 4, 0.4), baseCF * CFrame.new(0, 14, 0), Enum.Material.Wood, Color3.fromRGB(220, 215, 205), hoopFolder)

    local targetSquare = createPart("TargetSquare", Vector3.new(2.2, 1.8, 0.05), baseCF * CFrame.new(0, 13.5, 0.22), Enum.Material.SmoothPlastic, Color3.fromRGB(180, 40, 40), hoopFolder, false)

    -- Metal rim
    local rim = createPart("Rim", Vector3.new(2, 0.3, 2), baseCF * CFrame.new(0, 12.5, 1.2), Enum.Material.Metal, Color3.fromRGB(220, 80, 30), hoopFolder, false)

    -- Supporting angle brackets
    createPart("Bracket", Vector3.new(0.4, 2, 0.4), baseCF * CFrame.new(0, 12, -0.6) * CFrame.Angles(math.rad(25), 0, 0), Enum.Material.Metal, Color3.fromRGB(60, 60, 60), hoopFolder, false)
end

-- 6. Perimeter Concrete Hollow Block (CHB) Walls with Barangay Signages
function FilipinoStreetEnvironment.BuildPerimeterWalls(parent: Instance, courtWidth: number, courtLength: number, centerY: number)
    local wallsFolder = Instance.new("Folder")
    wallsFolder.Name = "PerimeterWalls"
    wallsFolder.Parent = parent

    local halfW = courtWidth / 2 + 10
    local halfL = courtLength / 2 + 30
    local wallHeight = 8

    -- Left Wall (CHB with concrete post columns)
    createPart("LeftCHBWall", Vector3.new(1.5, wallHeight, halfL * 2), CFrame.new(-halfW, centerY + wallHeight / 2, 0), Enum.Material.Concrete, Color3.fromRGB(140, 140, 145), wallsFolder)

    -- Right Wall (behind Sari-Sari store)
    createPart("RightCHBWall", Vector3.new(1.5, wallHeight, halfL * 2), CFrame.new(halfW, centerY + wallHeight / 2, 0), Enum.Material.Concrete, Color3.fromRGB(140, 140, 145), wallsFolder)

    -- Hand-painted Barangay Wall Signage ("BAWAL MAGTAPON NG BASURA")
    local signWallPart = createPart("BawalSignPart", Vector3.new(0.2, 3, 10), CFrame.new(-halfW + 0.8, centerY + 4.5, -10), Enum.Material.SmoothPlastic, Color3.fromRGB(240, 240, 240), wallsFolder)
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
