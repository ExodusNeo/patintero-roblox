--!strict
--[[
    CourtService.luau
    Authoritative server service responsible for the Patintero court.
    Builds the physical asphalt court, chalk lines, spawn locations, and boundary barriers.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.Modules.CourtGeometry)

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
    linePart.Color = Color3.fromRGB(240, 240, 240)
    linePart.CastShadow = false
    linePart.Parent = parent

    return linePart
end

function CourtService.Init()
    -- Check if court already exists or construct procedural court
    local existingCourt = Workspace:FindFirstChild("PatinteroCourt")
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

    -- 1. Asphalt Court Ground
    local ground = Instance.new("Part")
    ground.Name = "CourtFloor"
    -- Extra 20 studs on Home & End for safezones
    ground.Size = Vector3.new(courtConfig.TotalWidth + 10, 2, courtConfig.TotalLength + 50)
    ground.Position = Vector3.new(0, centerY - 1, 0)
    ground.Anchored = true
    ground.CanCollide = true
    ground.Material = Enum.Material.Asphalt
    ground.Color = Color3.fromRGB(45, 45, 48)
    ground.Parent = folder

    -- 2. Chalk Lines for Guard Rails
    local linesFolder = Instance.new("Folder")
    linesFolder.Name = "ChalkLines"
    linesFolder.Parent = folder

    local lineDefs = CourtGeometry.GetLineDefinitions()
    for _, def in pairs(lineDefs) do
        createChalkLine(def.id, def.startPoint, def.endPoint, linesFolder)
    end

    -- 3. Outer Boundary Chalk Lines (Perimeter)
    local pTL = Vector3.new(-halfW, centerY, -halfL)
    local pTR = Vector3.new(halfW, centerY, -halfL)
    local pBL = Vector3.new(-halfW, centerY, halfL)
    local pBR = Vector3.new(halfW, centerY, halfL)

    createChalkLine("BorderLeft", pTL, pBL, linesFolder)
    createChalkLine("BorderRight", pTR, pBR, linesFolder)

    -- 4. Invisible Boundary Barriers
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
    local totalCourtZ = courtConfig.TotalLength + 50
    -- Left & Right Barriers
    createBarrier("BarrierLeft", Vector3.new(2, barrierHeight, totalCourtZ), Vector3.new(-halfW - 3, centerY + barrierHeight / 2, 0))
    createBarrier("BarrierRight", Vector3.new(2, barrierHeight, totalCourtZ), Vector3.new(halfW + 3, centerY + barrierHeight / 2, 0))
    -- Home & End Barriers
    createBarrier("BarrierHomeBack", Vector3.new(courtConfig.TotalWidth + 10, barrierHeight, 2), Vector3.new(0, centerY + barrierHeight / 2, -halfL - 25))
    createBarrier("BarrierEndBack", Vector3.new(courtConfig.TotalWidth + 10, barrierHeight, 2), Vector3.new(0, centerY + barrierHeight / 2, halfL + 25))
end

function CourtService.GetSpawnCFrame(team: Types.Team, guardRole: Types.GuardRole?): CFrame
    local courtConfig = Config.Court
    local halfL = courtConfig.TotalLength / 2
    local centerY = courtConfig.CenterPosition.Y + 3

    if team == "Passers" then
        -- Home Base
        return CFrame.new(0, centerY, -halfL - 10) * CFrame.Angles(0, 0, 0)
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

return CourtService
