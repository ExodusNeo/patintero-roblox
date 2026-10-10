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

    -- 2-3. Street asphalt (kalye) with sidewalks and curbs
    FilipinoStreetEnvironment.BuildStreet(folder, courtConfig.TotalWidth, totalStreetLength, centerY)

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

    CourtService.BuildNeighborhood(folder)
end

-- Rows of houses just outside the invisible barriers so the court sits inside a real barangay street.
-- Also run once in edit mode to add them to the saved map.
function CourtService.BuildNeighborhood(parent: Instance)
    local halfW = Config.Court.TotalWidth / 2
    local left, right = -halfW - 16, halfW + 31 -- left barrier ~ -36; right barrier and store reach ~52
    local endZ = Config.Court.TotalLength / 2 + 37
    local y = Config.Court.CenterPosition.Y

    local neighborhood = Instance.new("Model")
    neighborhood.Name = "Neighborhood"
    FilipinoStreetEnvironment.BuildHouseRow(neighborhood, Vector3.new(left, y, -endZ + 2), Vector3.new(left, y, endZ - 2), Vector3.xAxis, 11)
    FilipinoStreetEnvironment.BuildHouseRow(neighborhood, Vector3.new(right, y, endZ - 2), Vector3.new(right, y, -endZ + 2), -Vector3.xAxis, 22)
    FilipinoStreetEnvironment.BuildHouseRow(neighborhood, Vector3.new(left, y, endZ), Vector3.new(right, y, endZ), -Vector3.zAxis, 33)
    FilipinoStreetEnvironment.BuildHouseRow(neighborhood, Vector3.new(right, y, -endZ), Vector3.new(left, y, -endZ), Vector3.zAxis, 44)
    neighborhood.Parent = parent
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
