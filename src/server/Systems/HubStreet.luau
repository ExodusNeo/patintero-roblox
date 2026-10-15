--!strict
--[[
    HubStreet.luau
    The hub's barangay street at dusk ("Kanto Night"), built in hub-local space around `origin`:
    - houses with a grime band, grilled windows (some lit from inside), wall lamps, balconies with laundry and
      the odd hand-painted sign; Aling Nena's sari-sari store in its own gap in the right-hand row
    - concrete poles with sodium streetlamps, spaghetti wires and banderitas, all past the welcome arch
    - asphalt with patches, manholes and a painted speed hump; painted curbs and gutters with grates
    - `SetupNightLighting` (hub only; the match keeps its golden hour)
    Houses, the store and the street carry `PropSpot` attachments (attribute `Kind`) where `Dress` places the
    Sketchfab props imported from assets/models/HubProps.fbx (templates in ServerStorage.HubProps).
]]

local Lighting = game:GetService("Lighting")

local HubStreet = {}

local function part(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance, collide: boolean?): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Material = material
    p.Color = color
    p.Anchored = true
    p.CanCollide = if collide == nil then true else collide
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- Non-solid detail: no collisions, raycasts or shadows.
local function deco(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance): Part
    local p = part(name, size, cf, material, color, parent, false)
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    return p
end

local function cylinder(name: string, length: number, diameter: number, cf: CFrame, material: Enum.Material, color: Color3, parent: Instance, collide: boolean?): Part
    local p = part(name, Vector3.new(length, diameter, diameter), cf, material, color, parent, collide)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function line(name: string, a: Vector3, b: Vector3, thick: number, material: Enum.Material, color: Color3, parent: Instance): Part
    local length = (b - a).Magnitude
    return deco(name, Vector3.new(thick, thick, length), CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2), material, color, parent)
end

-- Where Dress puts a prop: an Attachment on `host` at world `cf` (prop's bottom center, facing LookVector).
local function spot(host: BasePart, kind: string, cf: CFrame)
    local a = Instance.new("Attachment")
    a.Name = "PropSpot"
    a.CFrame = host.CFrame:ToObjectSpace(cf)
    a:SetAttribute("Kind", kind)
    a.Parent = host
end

local function light(className: string, parent: Instance, color: Color3, brightness: number, range: number, shadows: boolean): Light
    local l = Instance.new(className) :: Light
    l.Color = color
    l.Brightness = brightness;
    (l :: any).Range = range
    l.Shadows = shadows
    l.Parent = parent
    return l
end

local function paintedText(host: BasePart, face: Enum.NormalId, text: string, font: Enum.Font, color: Color3)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 1
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = font
    label.TextScaled = true
    label.TextColor3 = color
    label.Text = text
    label.Parent = gui
    gui.Parent = host
end

local WARM_GLASS = Color3.fromRGB(104, 70, 42) -- a lit room behind curtains (Neon, dim enough not to bloom)
local DARK_GLASS = Color3.fromRGB(34, 40, 50)
local SODIUM = Color3.fromRGB(255, 150, 70)
local BULB = Color3.fromRGB(255, 180, 110)
local WALLS = {
    Color3.fromRGB(214, 190, 150), Color3.fromRGB(158, 190, 168), Color3.fromRGB(222, 168, 146), Color3.fromRGB(166, 184, 214),
    Color3.fromRGB(232, 222, 196), Color3.fromRGB(196, 160, 186), Color3.fromRGB(208, 200, 120), Color3.fromRGB(190, 190, 186),
}
local ROOFS = { Color3.fromRGB(140, 72, 50), Color3.fromRGB(105, 112, 118), Color3.fromRGB(58, 98, 136), Color3.fromRGB(70, 110, 78) }
local DOORS = { Color3.fromRGB(92, 62, 42), Color3.fromRGB(60, 84, 74), Color3.fromRGB(124, 44, 40), Color3.fromRGB(70, 70, 80) }
local CLOTHES = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(240, 240, 235), Color3.fromRGB(60, 110, 200), Color3.fromRGB(240, 200, 60), Color3.fromRGB(90, 170, 110) }
local SIGNS = { "BAWAL UMIHI DITO!", "PA-LOAD DITO", "WATER REFILLING", "TAHIAN NI ALING BEBANG", "PA-PRINT • PA-XEROX", "BAWAL TUMAMBAY" }

local function grilledWindow(parent: Instance, cf: CFrame, w: number, h: number, lit: boolean)
    deco("Window", Vector3.new(w, h, 0.2), cf, if lit then Enum.Material.Neon else Enum.Material.Glass, if lit then WARM_GLASS else DARK_GLASS, parent)
    deco("Sill", Vector3.new(w + 0.6, 0.3, 0.6), cf * CFrame.new(0, -h / 2 - 0.15, -0.2), Enum.Material.Concrete, Color3.fromRGB(205, 200, 190), parent)
    local iron = Color3.fromRGB(26, 26, 28)
    for i = 1, 4 do
        deco("Grill", Vector3.new(0.12, h, 0.12), cf * CFrame.new(-w / 2 + i * w / 5, 0, -0.25), Enum.Material.Metal, iron, parent)
    end
    deco("Grill", Vector3.new(w, 0.12, 0.12), cf * CFrame.new(0, 0, -0.25), Enum.Material.Metal, iron, parent)
end

local function wallLamp(parent: Instance, cf: CFrame)
    deco("LampBracket", Vector3.new(0.2, 0.2, 0.8), cf * CFrame.new(0, 0, 0.4), Enum.Material.Metal, Color3.fromRGB(40, 40, 42), parent)
    local bulb = deco("WallLamp", Vector3.new(0.55, 0.55, 0.55), cf, Enum.Material.Neon, Color3.fromRGB(255, 205, 140), parent)
    bulb.Shape = Enum.PartType.Ball
    light("PointLight", bulb, BULB, 1.4, 14, false)
end

-- One "bahay". `cf` = bottom center of the front wall, LookVector toward the street.
local function buildHouse(parent: Instance, cf: CFrame, width: number, rng: Random, sign: string?)
    local house = Instance.new("Model")
    house.Name = "Bahay"
    local depth, h1 = 14, 9
    local wall = WALLS[rng:NextInteger(1, #WALLS)]
    local grime = wall:Lerp(Color3.fromRGB(40, 34, 28), 0.45)
    local body = part("GroundFloor", Vector3.new(width, h1, depth), cf * CFrame.new(0, h1 / 2, depth / 2), Enum.Material.Concrete, wall, house)
    house.PrimaryPart = body
    deco("Grime", Vector3.new(width + 0.05, 1.3, 0.1), cf * CFrame.new(0, 0.65, -0.04), Enum.Material.Concrete, grime, house)

    local side = if rng:NextNumber() < 0.5 then -1 else 1
    local doorX = side * width / 4
    deco("DoorFrame", Vector3.new(4, 7.6, 0.2), cf * CFrame.new(doorX, 3.8, -0.06), Enum.Material.Concrete, wall:Lerp(Color3.new(1, 1, 1), 0.35), house)
    deco("Door", Vector3.new(3.3, 7, 0.2), cf * CFrame.new(doorX, 3.5, -0.12), Enum.Material.Wood, DOORS[rng:NextInteger(1, #DOORS)], house)
    grilledWindow(house, cf * CFrame.new(-doorX, 5, -0.12), 4.2, 3.2, rng:NextNumber() < 0.45)
    if rng:NextNumber() < 0.45 then
        wallLamp(house, cf * CFrame.new(doorX, 8.1, -0.5))
    end
    spot(body, "Meter", cf * CFrame.new(doorX - side * 2.9, 5.2, -0.05))
    local roll = rng:NextNumber()
    if roll < 0.3 then
        spot(body, "Plant", cf * CFrame.new(doorX + side * 3, 0, -1.7))
    elseif roll < 0.5 then
        spot(body, "Drum", cf * CFrame.new(-doorX - side * 3.4, 0, -1.4))
    elseif roll < 0.62 then
        spot(body, "Bin", cf * CFrame.new(-doorX + side * 1.5, 0, -1.5))
    end
    if sign then
        local board = deco("PaintedSign", Vector3.new(math.min(width - 2, 11), 1.6, 0.1), cf * CFrame.new(-doorX, 7.6, -0.08), Enum.Material.SmoothPlastic, wall, house)
        paintedText(board, Enum.NormalId.Front, sign, Enum.Font.PermanentMarker, Color3.fromRGB(170, 30, 30))
    end

    local top = h1
    if rng:NextNumber() < 0.72 then
        local h2 = 8
        local upperColor = if rng:NextNumber() < 0.5 then wall:Lerp(Color3.new(1, 1, 1), 0.2) else WALLS[rng:NextInteger(1, #WALLS)]
        local upper = part("UpperFloor", Vector3.new(width, h2, depth - 1), cf * CFrame.new(0, h1 + h2 / 2, (depth - 1) / 2 + 1), Enum.Material.Concrete, upperColor, house)
        deco("FloorBand", Vector3.new(width + 0.2, 0.6, 1.2), cf * CFrame.new(0, h1 + 0.3, 0.5), Enum.Material.Concrete, Color3.fromRGB(205, 200, 190), house)
        local lit = rng:NextNumber() < 0.55
        if rng:NextNumber() < 0.5 then -- balcony with a grilled railing, sometimes laundry
            local bw = width * 0.6
            part("Balcony", Vector3.new(bw, 0.5, 3), cf * CFrame.new(0, h1 + 0.25, -0.5), Enum.Material.Concrete, Color3.fromRGB(200, 196, 188), house)
            deco("BalconyDoor", Vector3.new(3.2, 6, 0.2), cf * CFrame.new(0, h1 + 3.3, 0.88), if lit then Enum.Material.Neon else Enum.Material.Glass, if lit then WARM_GLASS else DARK_GLASS, house)
            local iron = Color3.fromRGB(30, 30, 32)
            deco("Rail", Vector3.new(bw, 0.2, 0.2), cf * CFrame.new(0, h1 + 3.4, -1.9), Enum.Material.Metal, iron, house)
            for x = -bw / 2, bw / 2 + 0.01, bw / 8 do
                deco("Baluster", Vector3.new(0.12, 2.9, 0.12), cf * CFrame.new(x, h1 + 1.95, -1.9), Enum.Material.Metal, iron, house)
            end
            if rng:NextNumber() < 0.6 then
                local y = h1 + 5.2
                local a, b = cf * Vector3.new(-bw / 2, y, -1.9), cf * Vector3.new(bw / 2, y, -1.9)
                deco("LaundryPostL", Vector3.new(0.15, 2, 0.15), cf * CFrame.new(-bw / 2, h1 + 4.3, -1.9), Enum.Material.Metal, iron, house)
                deco("LaundryPostR", Vector3.new(0.15, 2, 0.15), cf * CFrame.new(bw / 2, h1 + 4.3, -1.9), Enum.Material.Metal, iron, house)
                line("LaundryLine", a, b, 0.05, Enum.Material.Fabric, Color3.fromRGB(220, 220, 215), house)
                for i = 1, rng:NextInteger(3, 5) do
                    local t = i / 6
                    local w, h = rng:NextNumber(0.9, 1.6), rng:NextNumber(1.1, 2)
                    deco("Laundry", Vector3.new(w, h, 0.06), cf * CFrame.new(-bw / 2 + t * bw, y - h / 2, -1.9), Enum.Material.Fabric, CLOTHES[rng:NextInteger(1, #CLOTHES)], house)
                end
            end
        else
            grilledWindow(house, cf * CFrame.new(-width / 4, h1 + 4.2, 0.88), 4, 3.2, lit)
            grilledWindow(house, cf * CFrame.new(width / 4, h1 + 4.2, 0.88), 4, 3.2, rng:NextNumber() < 0.4)
        end
        spot(upper, "Aircon", cf * CFrame.new(side * (width / 2 - 1.6), h1 + 1.4, 0.35))
        top += h2
    else
        deco("Awning", Vector3.new(width * 0.55, 0.25, 3), cf * CFrame.new(doorX, 8.6, -1.3) * CFrame.Angles(math.rad(-14), 0, 0), Enum.Material.CorrodedMetal, ROOFS[rng:NextInteger(1, #ROOFS)], house)
        spot(body, "Aircon", cf * CFrame.new(-doorX, 1.2, -0.95))
    end

    local roof = ROOFS[rng:NextInteger(1, #ROOFS)]
    local roofCf = cf * CFrame.new(0, top + 1.6, depth / 2) * CFrame.Angles(math.rad(-12), 0, 0)
    part("YeroRoof", Vector3.new(width + 1.2, 0.4, depth + 3), roofCf, Enum.Material.CorrodedMetal, roof, house)
    deco("Fascia", Vector3.new(width + 1.2, 0.8, 0.15), roofCf * CFrame.new(0, -0.3, -(depth + 3) / 2), Enum.Material.WoodPlanks, roof:Lerp(Color3.new(1, 1, 1), 0.5), house)
    house.Parent = parent
end

-- Houses side by side from `fromPos` to `toPos` (hub-local, world space via `origin`), fronts facing `facing`.
-- `signs`: chance a house gets a hand-painted sign.
function HubStreet.BuildHouseRow(parent: Instance, fromPos: Vector3, toPos: Vector3, facing: Vector3, seed: number, signs: number?): Model
    local row = Instance.new("Model")
    row.Name = "HouseRow"
    local rng = Random.new(seed)
    local direction = (toPos - fromPos).Unit
    local total = (toPos - fromPos).Magnitude
    local along = 0
    while total - along >= 9 do
        local width = math.min(rng:NextInteger(13, 18), total - along)
        local center = fromPos + direction * (along + width / 2)
        local sign = if rng:NextNumber() < (signs or 0.15) then SIGNS[rng:NextInteger(1, #SIGNS)] else nil
        buildHouse(row, CFrame.lookAt(center, center + facing), width - 0.3, rng, sign)
        along += width
    end
    row.Parent = parent
    return row
end

-- Aling Nena's sari-sari store: a two-storey house whose ground floor is a grilled storefront with a counter,
-- lit shelves of goods, a yero awning hung with chichirya, and the painted sign. `cf` as for a house.
function HubStreet.BuildSariSariStore(parent: Instance, cf: CFrame): Model
    local store = Instance.new("Model")
    store.Name = "SariSariStore"
    local width, depth, h1, h2 = 22, 16, 9, 8
    local wall = Color3.fromRGB(158, 196, 170)
    local trim = Color3.fromRGB(236, 232, 220)
    local back = part("BackWall", Vector3.new(width, h1, depth - 6), cf * CFrame.new(0, h1 / 2, 6 + (depth - 6) / 2), Enum.Material.Concrete, wall, store)
    store.PrimaryPart = back
    part("PillarL", Vector3.new(3, h1, 6), cf * CFrame.new(-width / 2 + 1.5, h1 / 2, 3), Enum.Material.Concrete, wall, store)
    part("PillarR", Vector3.new(3, h1, 6), cf * CFrame.new(width / 2 - 1.5, h1 / 2, 3), Enum.Material.Concrete, wall, store)
    part("CounterWall", Vector3.new(width - 6, 3.2, 1), cf * CFrame.new(0, 1.6, 0.5), Enum.Material.Concrete, wall, store)
    deco("Grime", Vector3.new(width - 6, 1.2, 0.1), cf * CFrame.new(0, 0.6, -0.04), Enum.Material.Concrete, wall:Lerp(Color3.fromRGB(40, 34, 28), 0.45), store)
    part("Counter", Vector3.new(width - 5, 0.35, 1.8), cf * CFrame.new(0, 3.35, 0.1), Enum.Material.WoodPlanks, Color3.fromRGB(128, 86, 54), store)
    part("Lintel", Vector3.new(width, h1 - 7.4, 6), cf * CFrame.new(0, 7.4 + (h1 - 7.4) / 2, 3), Enum.Material.Concrete, trim, store)
    part("Floor", Vector3.new(width - 6, 0.3, 6), cf * CFrame.new(0, 0.15, 3), Enum.Material.Concrete, Color3.fromRGB(150, 140, 128), store)

    -- Inside: dark back wall with shelves of colorful goods, under one warm bulb
    deco("Inside", Vector3.new(width - 6, 7.4, 0.2), cf * CFrame.new(0, 3.7, 5.9), Enum.Material.SmoothPlastic, Color3.fromRGB(70, 56, 44), store)
    local goods = { Color3.fromRGB(220, 50, 40), Color3.fromRGB(240, 200, 30), Color3.fromRGB(40, 160, 60), Color3.fromRGB(230, 120, 30), Color3.fromRGB(60, 110, 210), Color3.fromRGB(240, 240, 235) }
    local rng = Random.new(77)
    for row = 0, 2 do
        local y = 3.8 + row * 1.25
        deco("Shelf", Vector3.new(width - 7, 0.15, 1.2), cf * CFrame.new(0, y, 5.2), Enum.Material.WoodPlanks, Color3.fromRGB(150, 110, 70), store)
        for x = -(width - 8) / 2, (width - 8) / 2, 0.9 do
            local h = rng:NextNumber(0.5, 0.95)
            deco("Goods", Vector3.new(0.7, h, 0.7), cf * CFrame.new(x, y + 0.08 + h / 2, 5.2), Enum.Material.SmoothPlastic, goods[rng:NextInteger(1, #goods)], store)
        end
    end
    local bulb = deco("StoreBulb", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 6.9, 3), Enum.Material.Neon, Color3.fromRGB(255, 215, 160), store)
    bulb.Shape = Enum.PartType.Ball
    light("PointLight", bulb, BULB, 2.2, 20, true)

    -- Wire-mesh grill across the storefront, with the "bintana" gap over the counter
    local iron = Color3.fromRGB(32, 32, 34)
    for x = -(width - 6) / 2, (width - 6) / 2 + 0.01, 0.8 do
        if math.abs(x) > 1.6 then
            deco("Mesh", Vector3.new(0.08, 4, 0.08), cf * CFrame.new(x, 5.4, -0.3), Enum.Material.Metal, iron, store)
        end
    end
    for _, y in { 3.5, 5.4, 7.3 } do
        deco("MeshBar", Vector3.new(width - 6, 0.12, 0.12), cf * CFrame.new(0, y, -0.3), Enum.Material.Metal, iron, store)
    end

    -- Awning with hanging snack strips
    deco("Awning", Vector3.new(width + 1, 0.25, 4), cf * CFrame.new(0, 7.9, -1.7) * CFrame.Angles(math.rad(-16), 0, 0), Enum.Material.CorrodedMetal, Color3.fromRGB(200, 70, 50), store)
    for _, x in { -width / 2 + 2, -width / 2 + 3, width / 2 - 3, width / 2 - 2 } do -- snack strips at the awning's ends
        for k = 0, 2 do
            deco("Chichirya", Vector3.new(0.8, 1, 0.08), cf * CFrame.new(x, 6.6 - k * 1.05, -3.2), Enum.Material.SmoothPlastic, goods[rng:NextInteger(1, #goods)], store)
        end
    end

    local board = deco("StoreSign", Vector3.new(16, 2.6, 0.3), cf * CFrame.new(0, 10.2, 0.75), Enum.Material.WoodPlanks, Color3.fromRGB(240, 232, 205), store)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 1
    gui.Parent = board
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.fromScale(1, 0.66)
    title.Font = Enum.Font.FredokaOne
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(180, 30, 30)
    title.Text = "ALING NENA'S STORE"
    title.Parent = gui
    local sub = title:Clone()
    sub.Position = UDim2.fromScale(0, 0.66)
    sub.Size = UDim2.fromScale(1, 0.3)
    sub.Font = Enum.Font.GothamBold
    sub.TextColor3 = Color3.fromRGB(30, 60, 140)
    sub.Text = "ICE TUBIG • CHICHIRYA • SOFTDRINKS • PA-LOAD"
    sub.Parent = gui

    local upper = part("UpperFloor", Vector3.new(width, h2, depth - 1), cf * CFrame.new(0, h1 + h2 / 2, (depth - 1) / 2 + 1), Enum.Material.Concrete, trim, store)
    grilledWindow(store, cf * CFrame.new(-width / 4, h1 + 4.2, 0.88), 4.4, 3.2, true)
    grilledWindow(store, cf * CFrame.new(width / 4, h1 + 4.2, 0.88), 4.4, 3.2, false)
    part("YeroRoof", Vector3.new(width + 1.2, 0.4, depth + 3), cf * CFrame.new(0, h1 + h2 + 1.6, depth / 2) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.CorrodedMetal, ROOFS[1], store)
    spot(upper, "Aircon", cf * CFrame.new(width / 2 - 1.8, h1 + 1.4, 0.35))
    spot(back, "Meter", cf * CFrame.new(-width / 2 + 1.5, 5.4, -0.05))
    spot(back, "TableSet", cf * CFrame.new(-1, 0, -3.4))
    spot(back, "LPG", cf * CFrame.new(width / 2 - 2, 0, -1.4))
    spot(back, "Drum", cf * CFrame.new(width / 2 - 4.2, 0, -1.4))
    spot(back, "Monobloc", cf * CFrame.new(-width / 2 + 2.5, 0, -2.2) * CFrame.Angles(0, math.rad(20), 0))
    spot(back, "Bin", cf * CFrame.new(-width / 2 + 5.5, 0, -1.4))
    store.Parent = parent
    return store
end

-- Street surface `length` long along Z, asphalt `width` wide, centered on `origin`: asphalt with patches and
-- manholes, a painted speed hump near the court end, then on each side a gutter with grates, a painted curb and
-- the sidewalk up to the house fronts at x = ±houseX. Also the parking spots for the jeepney and tricycles.
function HubStreet.BuildStreet(parent: Instance, origin: CFrame, width: number, length: number, houseX: number): Model
    local street = Instance.new("Model")
    street.Name = "Street"
    local function at(x: number, y: number, z: number): CFrame
        return origin * CFrame.new(x, y, z)
    end
    local road = part("StreetAsphalt", Vector3.new(width, 2, length), at(0, -1, 0), Enum.Material.Asphalt, Color3.fromRGB(62, 60, 62), street)
    local rng = Random.new(5)
    for _ = 1, 10 do
        local w, l = rng:NextNumber(5, 12), rng:NextNumber(4, 10)
        deco("Patch", Vector3.new(w, 0.04, l), at(rng:NextNumber(-width / 2 + 6, width / 2 - 6), 0.02, rng:NextNumber(-length / 2 + 8, length / 2 - 8))
            * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), Enum.Material.Asphalt, if rng:NextNumber() < 0.5 then Color3.fromRGB(74, 70, 68) else Color3.fromRGB(50, 50, 54), street)
    end
    for _, z in { -30, 12, 52 } do
        cylinder("Manhole", 0.06, 3, at(rng:NextNumber(-8, 8), 0.03, z) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Color3.fromRGB(64, 62, 60), street, false)
    end
    for i = 0, math.floor(width / 2.5) - 1 do -- speed hump, yellow and black
        part("Hump", Vector3.new(2.5, 0.35, 2.4), at(-width / 2 + 1.25 + i * 2.5, 0.17, length / 2 - 16), Enum.Material.SmoothPlastic,
            if i % 2 == 0 then Color3.fromRGB(230, 190, 40) else Color3.fromRGB(30, 30, 30), street)
    end
    -- parked on the right-hand side of their lane (traffic drives on the right), facing the way they'd drive
    spot(road, "Jeepney", at(width / 2 - 7, 0, 46))
    spot(road, "Tricycle", at(width / 2 - 6, 0, -6))
    spot(road, "Tricycle", at(-width / 2 + 6, 0, 50) * CFrame.Angles(0, math.pi, 0))

    for _, s in { -1, 1 } do
        local inner = width / 2 + 1.9
        part("Sidewalk", Vector3.new(houseX - inner, 2.8, length), at(s * (inner + houseX) / 2, -0.6, 0), Enum.Material.Concrete, Color3.fromRGB(150, 146, 140), street)
        part("Gutter", Vector3.new(1.2, 2, length), at(s * (width / 2 + 0.6), -1.25, 0), Enum.Material.Concrete, Color3.fromRGB(70, 68, 66), street)
        for z = -length / 2 + 6, length / 2 - 6, 14 do
            deco("Grate", Vector3.new(1.2, 0.08, 2.4), at(s * (width / 2 + 0.6), -0.2, z), Enum.Material.DiamondPlate, Color3.fromRGB(46, 46, 48), street)
        end
        for i = 0, length / 4 - 1 do
            part("Curb", Vector3.new(0.7, 1.2, 4), at(s * (width / 2 + 1.55), 0.2, -length / 2 + 2 + i * 4), Enum.Material.Concrete,
                if i % 2 == 0 then Color3.fromRGB(226, 188, 46) else Color3.fromRGB(232, 230, 222), street)
        end
    end
    street.Parent = parent
    return street
end

-- Concrete utility poles on both sidewalks at `zs` (x = ±halfX), each with a sodium streetlamp over the road;
-- spaghetti wires along and across the street with service drops to the houses; banderitas zig-zagging
-- between the poles. Keep `zs` clear of the welcome arch.
function HubStreet.BuildPoles(parent: Instance, origin: CFrame, halfX: number, zs: { number }): Model
    local poles = Instance.new("Model")
    poles.Name = "PolesAndWires"
    local function at(x: number, y: number, z: number): Vector3
        return origin:PointToWorldSpace(Vector3.new(x, y, z))
    end
    local HEIGHT = 26
    local tops: { [number]: { Vector3 } } = { [-1] = {}, [1] = {} }
    for i, z in zs do
        for _, s in { -1, 1 } do
            local x = s * halfX
            cylinder("Pole", HEIGHT, 1.5, CFrame.new(at(x, HEIGHT / 2, z)) * origin.Rotation * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Concrete, Color3.fromRGB(156, 152, 146), poles)
            deco("CrossArm", Vector3.new(6, 0.5, 0.5), CFrame.new(at(x, HEIGHT - 1.5, z)) * origin.Rotation, Enum.Material.Metal, Color3.fromRGB(70, 70, 72), poles)
            for _, dx in { -2.4, 0, 2.4 } do
                deco("Insulator", Vector3.new(0.35, 0.6, 0.35), CFrame.new(at(x + dx, HEIGHT - 1, z)) * origin.Rotation, Enum.Material.SmoothPlastic, Color3.fromRGB(230, 230, 225), poles)
            end
            table.insert(tops[s], at(x, HEIGHT - 0.8, z))
            if i == 2 and s == 1 then -- pole-top transformer
                cylinder("Transformer", 3.2, 2.2, CFrame.new(at(x + 1.6, HEIGHT - 5, z)) * origin.Rotation * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Color3.fromRGB(120, 124, 120), poles, false)
            end
            -- sodium streetlamp reaching over the road
            local base, tip = at(x, 19, z), at(x - s * 7, 20.4, z)
            line("LampArm", base, tip, 0.3, Enum.Material.Metal, Color3.fromRGB(60, 62, 64), poles)
            local head = deco("LampHead", Vector3.new(2.2, 0.6, 1.1), CFrame.lookAt(tip, tip + (tip - base) * Vector3.new(1, 0, 1)) * CFrame.Angles(0, math.rad(90), 0),
                Enum.Material.Metal, Color3.fromRGB(56, 58, 60), poles)
            local glow = deco("LampGlow", Vector3.new(1.6, 0.1, 0.7), head.CFrame * CFrame.new(0, -0.33, 0), Enum.Material.Neon, Color3.fromRGB(255, 170, 90), poles)
            local lamp = light("SpotLight", glow, SODIUM, 5, 52, true) :: SpotLight
            lamp.Face = Enum.NormalId.Bottom
            lamp.Angle = 125
        end
    end

    local black = Color3.fromRGB(18, 18, 18)
    local function wire(a: Vector3, b: Vector3, sag: number)
        local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
        line("Wire", a, mid, 0.14, Enum.Material.Rubber, black, poles)
        line("Wire", mid, b, 0.14, Enum.Material.Rubber, black, poles)
    end
    for i = 1, #zs do
        for k, off in { -0.6, 0, 0.6 } do
            wire(tops[-1][i] + Vector3.new(0, -k * 0.3, off), tops[1][i] + Vector3.new(0, -k * 0.3, off), 2 + k * 0.6)
        end
        if i < #zs then
            for _, s in { -1, 1 } do
                for k = 0, 2 do
                    wire(tops[s][i] + Vector3.new(0, -k * 0.35, 0), tops[s][i + 1] + Vector3.new(0, -k * 0.35, 0), 1.4 + k * 0.5)
                end
            end
        end
        for _, s in { -1, 1 } do -- service drops to the houses behind the pole
            for _, dz in { -9, 7 } do
                wire(tops[s][i], at(s * (halfX + 1.5), 16.5, zs[i] + dz), 1.2)
            end
        end
    end

    -- Banderitas zig-zag between consecutive pole pairs, tied below the cross-arms
    local colors = { Color3.fromRGB(235, 45, 45), Color3.fromRGB(245, 215, 30), Color3.fromRGB(35, 130, 240), Color3.fromRGB(40, 200, 70), Color3.fromRGB(250, 250, 250) }
    local tieY = HEIGHT - 4
    for i = 1, #zs - 1 do
        for _, s in { -1, 1 } do
            local a, b = at(s * halfX, tieY, zs[i]), at(-s * halfX, tieY, zs[i + 1])
            local steps = math.floor((b - a).Magnitude / 2.2)
            local prev = a
            for step = 1, steps do
                local t = step / steps
                local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 3.5, 0)
                line("String", prev, p, 0.07, Enum.Material.Fabric, Color3.fromRGB(235, 230, 215), poles)
                prev = p
                if step < steps then
                    local flag = Instance.new("WedgePart")
                    flag.Name = "Flag"
                    flag.Size = Vector3.new(0.08, 1.4, 1.2)
                    flag.CFrame = CFrame.lookAt(p - Vector3.new(0, 0.75, 0), p - Vector3.new(0, 0.75, 0) + (b - a).Unit) * CFrame.Angles(math.pi, 0, 0)
                    flag.Material = Enum.Material.Fabric
                    flag.Color = colors[step % #colors + 1]
                    flag.Anchored, flag.CanCollide, flag.CanQuery, flag.CanTouch, flag.CastShadow = true, false, false, false, false
                    flag.Parent = poles
                end
            end
        end
    end
    poles.Parent = parent
    return poles
end

-- Blue hour: deep blue sky with the last light, cool ambient, warm pools under the lamps.
function HubStreet.SetupNightLighting()
    Lighting.ClockTime = 18.95
    Lighting.GeographicLatitude = 14.6
    Lighting.Brightness = 1.1
    Lighting.OutdoorAmbient = Color3.fromRGB(76, 84, 116)
    Lighting.Ambient = Color3.fromRGB(38, 40, 54)
    Lighting.ColorShift_Top = Color3.fromRGB(130, 150, 210)
    Lighting.ColorShift_Bottom = Color3.fromRGB(60, 50, 60)
    Lighting.EnvironmentDiffuseScale = 0.35
    Lighting.EnvironmentSpecularScale = 0.5
    Lighting.ShadowSoftness = 0.25
    Lighting.ExposureCompensation = 0.25
    Lighting.GlobalShadows = true

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
    atmosphere.Density = 0.34
    atmosphere.Offset = 0.15
    atmosphere.Color = Color3.fromRGB(96, 104, 140)
    atmosphere.Decay = Color3.fromRGB(150, 90, 90)
    atmosphere.Glare = 0
    atmosphere.Haze = 1.6
    atmosphere.Parent = Lighting
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
    bloom.Intensity = 0.9
    bloom.Size = 30
    bloom.Threshold = 0.95
    bloom.Parent = Lighting
    local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
    grade.Contrast = 0.12
    grade.Saturation = 0.06
    grade.TintColor = Color3.fromRGB(232, 236, 255)
    grade.Parent = Lighting
    local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
    if rays then
        rays.Intensity = 0
    end
end

-- Target heights (studs) of the imported props; matches tools/blender/hub_props.py (height in m x 3.2).
local PROPS: { [string]: { template: string, height: number, solid: boolean } } = {
    Jeepney = { template = "Prop_Jeepney", height = 8, solid = true },
    Tricycle = { template = "Prop_Tricycle", height = 5.3, solid = true },
    Monobloc = { template = "Prop_Monobloc", height = 2.7, solid = true },
    Drum = { template = "Prop_WaterDrum", height = 3, solid = true },
    LPG = { template = "Prop_LPG", height = 1.9, solid = true },
    Bin = { template = "Prop_Bin", height = 2.9, solid = true },
    Plant = { template = "Prop_Plant", height = 3.8, solid = false },
    Aircon = { template = "Prop_Aircon", height = 1.8, solid = false },
    Meter = { template = "Prop_Meter", height = 1.6, solid = false },
    TableSet = { template = "Prop_TableSet", height = 2.7, solid = true },
}
-- Extra yaw per template so its front matches the spot's LookVector (set from a look in Studio).
HubStreet.PropYaw = {} :: { [string]: number }

-- Puts a copy of the matching template at every PropSpot under `root`. Templates are Models or MeshParts
-- named Prop_<Key> anywhere under `templates`; copies are anchored, scaled to the target height, bottom on the
-- spot. Returns how many were placed. Re-running replaces earlier copies (named HubProp).
function HubStreet.Dress(root: Instance, templates: Instance): number
    for _, old in root:GetDescendants() do
        if old.Name == "HubProp" and old.Parent then
            old:Destroy()
        end
    end
    local byName: { [string]: Instance } = {}
    for _, t in templates:GetDescendants() do
        if t.Name:sub(1, 5) == "Prop_" and (t:IsA("Model") or t:IsA("BasePart")) and not byName[t.Name] then
            byName[t.Name] = t
        end
    end
    local placed = 0
    for _, a in root:GetDescendants() do
        if not (a:IsA("Attachment") and a.Name == "PropSpot") then continue end
        local info = PROPS[a:GetAttribute("Kind") :: string]
        local template = if info then byName[info.template] else nil
        if not info or not template then continue end
        local model: Model
        if template:IsA("Model") then
            model = template:Clone()
        else
            model = Instance.new("Model")
            template:Clone().Parent = model
        end
        model.Name = "HubProp"
        for _, d in model:GetDescendants() do
            if d:IsA("BaseScript") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = info.solid
                d.CanTouch = false
                d.CanQuery = info.solid
                d.CastShadow = true
            end
        end
        local cf, size = model:GetBoundingBox()
        model:ScaleTo(model:GetScale() * info.height / size.Y)
        cf, size = model:GetBoundingBox()
        local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
        local yaw = HubStreet.PropYaw[info.template] or 0
        model:PivotTo(a.WorldCFrame * CFrame.Angles(0, yaw, 0) * bottom:ToObjectSpace(model:GetPivot()))
        model.Parent = a.Parent
        placed += 1
    end
    return placed
end

return HubStreet
