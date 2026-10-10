--!strict
--[[
    CourtService.luau
    Authoritative server service responsible for the Patintero court and Filipino street environment.
    Builds the authentic barangay street:
    - Asphalt street pavement with curbs and sidewalks
    - Real chalk lines with subtle chalk dust
    - Corner Sari-Sari Store with yero roof, grills, and crates
    - Electric utility poles with tangled spaghetti wires & streetlamp
    - Festive fiesta Banderitas overhead
    - Makeshift plywood basketball hoop
    - Cinder block walls with barangay signage
    - Golden-hour tropical sunset lighting
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)
local FilipinoStreetEnvironment = require(script.Parent.FilipinoStreetEnvironment)

local CourtService = {}
local courtFolder: Folder? = nil

local function createChalkLine(name: string, p1: Vector3, p2: Vector3, parent: Instance): Part
    local distance = (p2 - p1).Magnitude
    local midpoint = (p1 + p2) / 2
    local direction = (p2 - p1).Unit

    local linePart = Instance.new("Part")
    linePart.Name = name
    linePart.Size = Vector3.new(Config.Court.LineThickness, Config.Court.LineHeight, distance)
    linePart.CFrame = CFrame.lookAt(midpoint, midpoint + direction)
    linePart.Anchored = true
    linePart.CanCollide = false
    linePart.Material = Enum.Material.Concrete
    linePart.Color = Color3.fromRGB(245, 245, 245)
    linePart.CastShadow = false
    linePart.Parent = parent

    -- Authentic subtle chalk dust particle effect
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, 0.2, 0)
    attachment.Parent = linePart

    local dustEmitter = Instance.new("ParticleEmitter")
    dustEmitter.Name = "ChalkDust"
    dustEmitter.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
    dustEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0.8),
    })
    dustEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    dustEmitter.Lifetime = NumberRange.new(0.6, 1.2)
    dustEmitter.Rate = 2
    dustEmitter.Speed = NumberRange.new(0.5, 1.5)
    dustEmitter.SpreadAngle = Vector2.new(45, 45)
    dustEmitter.Parent = attachment

    return linePart
end

function CourtService.Init()
    -- 1. Setup Golden Hour Dapit-Hapon Lighting
    FilipinoStreetEnvironment.SetupGoldenHourLighting()

    -- Check if court already exists with child instances (customized or pre-built in Studio)
    local existingCourt = Workspace:FindFirstChild("PatinteroCourt")
    if existingCourt and #existingCourt:GetChildren() > 0 then
        -- Preserve existing court in Workspace so manual Studio edits are retained!
        courtFolder = existingCourt
        return
    end

    if existingCourt then
        existingCourt:Destroy()
    end

    local folder = Instance.new("Folder")
    folder.Name = "PatinteroCourt"
    folder.Parent = Workspace
    courtFolder = folder

    local courtConfig = Config.Court
    local halfL = courtConfig.TotalLength / 2
    local halfW = courtConfig.TotalWidth / 2
    local centerY = courtConfig.CenterPosition.Y
    local totalStreetLength = courtConfig.TotalLength + 60

    -- 2. Street Asphalt Ground (Kalye)
    local street = Instance.new("Part")
    street.Name = "StreetAsphalt"
    street.Size = Vector3.new(courtConfig.TotalWidth + 4, 2, totalStreetLength)
    street.Position = Vector3.new(0, centerY - 1, 0)
    street.Anchored = true
    street.CanCollide = true
    street.Material = Enum.Material.Asphalt
    street.Color = Color3.fromRGB(50, 50, 54)
    street.Parent = folder

    -- 3. Sidewalks & Curbs on Left and Right
    local sidewalkWidth = 8
    local sidewalkHeight = 0.8

    local function createSidewalk(name: string, posX: number)
        local sidewalkModel = Instance.new("Model")
        sidewalkModel.Name = name
        sidewalkModel.Parent = folder

        local sidewalk = Instance.new("Part")
        sidewalk.Name = "Walkway"
        sidewalk.Size = Vector3.new(sidewalkWidth, sidewalkHeight + 2, totalStreetLength)
        sidewalk.Position = Vector3.new(posX, centerY + (sidewalkHeight / 2) - 1, 0)
        sidewalk.Anchored = true
        sidewalk.CanCollide = true
        sidewalk.Material = Enum.Material.Concrete
        sidewalk.Color = Color3.fromRGB(155, 155, 160)
        sidewalk.Parent = sidewalkModel
        sidewalkModel.PrimaryPart = sidewalk

        -- Yellow/Black painted curb
        local curbX = if posX < 0 then posX + (sidewalkWidth / 2) else posX - (sidewalkWidth / 2)
        local curb = Instance.new("Part")
        curb.Name = "Curb"
        curb.Size = Vector3.new(0.6, sidewalkHeight + 0.2, totalStreetLength)
        curb.Position = Vector3.new(curbX, centerY + (sidewalkHeight / 2), 0)
        curb.Anchored = true
        curb.CanCollide = true
        curb.Material = Enum.Material.Concrete
        curb.Color = Color3.fromRGB(220, 180, 40) -- Weathered yellow curb
        curb.Parent = sidewalkModel
    end

    createSidewalk("SidewalkLeft", -halfW - (sidewalkWidth / 2) - 2)
    createSidewalk("SidewalkRight", halfW + (sidewalkWidth / 2) + 2)

    -- 4. Authentic Chalk Lines for Guard Rails
    local linesFolder = Instance.new("Folder")
    linesFolder.Name = "ChalkLines"
    linesFolder.Parent = folder

    local lineDefs = CourtGeometry.GetLineDefinitions()
    for _, def in pairs(lineDefs) do
        createChalkLine(def.id, def.startPoint, def.endPoint, linesFolder)
    end

    -- 5. Outer Perimeter Chalk Lines
    local pTL = Vector3.new(-halfW, centerY, -halfL)
    local pTR = Vector3.new(halfW, centerY, -halfL)
    local pBL = Vector3.new(-halfW, centerY, halfL)
    local pBR = Vector3.new(halfW, centerY, halfL)

    createChalkLine("BorderLeft", pTL, pBL, linesFolder)
    createChalkLine("BorderRight", pTR, pBR, linesFolder)

    -- 6. Filipino Street Props & Architecture
    -- Sari-Sari Store on the right sidewalk
    FilipinoStreetEnvironment.BuildSariSariStore(folder, Vector3.new(halfW + 16, centerY, 0))

    -- Electric Utility Poles & Tangled Spaghetti Wires
    FilipinoStreetEnvironment.BuildUtilityPolesAndWires(folder, courtConfig.TotalWidth, courtConfig.TotalLength, centerY)

    -- Fiesta Banderitas (Triangular buntings overhead)
    FilipinoStreetEnvironment.BuildBanderitas(folder, courtConfig.TotalWidth, courtConfig.TotalLength, centerY)

    -- Makeshift Basketball Hoop mounted on left mid pole
    FilipinoStreetEnvironment.BuildMakeshiftBasketballHoop(folder, Vector3.new(-halfW - 7, centerY, 0))

    -- Perimeter Concrete Hollow Block Walls with Barangay Signages
    FilipinoStreetEnvironment.BuildPerimeterWalls(folder, courtConfig.TotalWidth, courtConfig.TotalLength, centerY)

    -- 7. Invisible Boundary Barriers (To keep game contained)
    local barriersFolder = Instance.new("Folder")
    barriersFolder.Name = "Barriers"
    barriersFolder.Parent = folder

    local function createBarrier(name: string, size: Vector3, position: Vector3)
        local wall = Instance.new("Part")
        wall.Name = name
        wall.Size = size
        wall.Position = position
        wall.Anchored = true
        wall.CanCollide = true
        wall.Transparency = 1
        wall.Parent = barriersFolder
    end

    local barrierHeight = 24
    createBarrier("BarrierLeft", Vector3.new(2, barrierHeight, totalStreetLength), Vector3.new(-halfW - 12, centerY + barrierHeight / 2, 0))
    createBarrier("BarrierRight", Vector3.new(2, barrierHeight, totalStreetLength), Vector3.new(halfW + 28, centerY + barrierHeight / 2, 0))
    createBarrier("BarrierHomeBack", Vector3.new(courtConfig.TotalWidth + 40, barrierHeight, 2), Vector3.new(0, centerY + barrierHeight / 2, -halfL - 25))
    createBarrier("BarrierEndBack", Vector3.new(courtConfig.TotalWidth + 40, barrierHeight, 2), Vector3.new(0, centerY + barrierHeight / 2, halfL + 25))
end

function CourtService.GetSpawnCFrame(team: Types.Team, guardRole: Types.GuardRole?): CFrame
    local courtConfig = Config.Court
    local halfL = courtConfig.TotalLength / 2
    local centerY = courtConfig.CenterPosition.Y + 3

    if team == "Passers" then
        -- Home Base, facing forward down the court towards the Safehouse
        return CFrame.lookAt(Vector3.new(0, centerY, -halfL - 10), Vector3.new(0, centerY, 0))
    elseif team == "Guards" and guardRole then
        local lineDefs = CourtGeometry.GetLineDefinitions()
        local lineDef = lineDefs[guardRole]
        if lineDef then
            local midPoint = (lineDef.startPoint + lineDef.endPoint) / 2
            return CFrame.new(midPoint.X, centerY, midPoint.Z)
        end
    end

    -- Default fallback
    return CFrame.new(0, centerY, -halfL - 15)
end

-- Where tagged-out Passers wait: the left sidewalk, facing the court.
function CourtService.GetSidelineCFrame(): CFrame
    local courtConfig = Config.Court
    local x = -courtConfig.TotalWidth / 2 - 6
    local y = courtConfig.CenterPosition.Y + 4
    local z = math.random(-courtConfig.TotalLength / 2, courtConfig.TotalLength / 2)
    return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(0, y, z))
end

return CourtService
