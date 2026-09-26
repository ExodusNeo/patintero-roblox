--!strict
--[[
    CourtGeometry.luau
    Stateless geometric and mathematical helpers for Patintero.
    Calculates line segments, point-to-line projections, and zone bounds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)

local CourtGeometry = {}

function CourtGeometry.GetLineDefinitions(): { [Types.GuardRole]: Types.LineDefinition }
    local court = Config.Court
    local halfLength = court.TotalLength / 2
    local halfWidth = court.TotalWidth / 2
    local centerY = court.CenterPosition.Y

    local lineZPositions = {
        Line1 = -halfLength,
        Line2 = 0,
        Line3 = halfLength,
    }

    local definitions: { [Types.GuardRole]: Types.LineDefinition } = {
        Line1 = {
            id = "Line1",
            name = "Front Line",
            startPoint = Vector3.new(-halfWidth, centerY, lineZPositions.Line1),
            endPoint = Vector3.new(halfWidth, centerY, lineZPositions.Line1),
            width = court.LineThickness,
        },
        Line2 = {
            id = "Line2",
            name = "Mid Line",
            startPoint = Vector3.new(-halfWidth, centerY, lineZPositions.Line2),
            endPoint = Vector3.new(halfWidth, centerY, lineZPositions.Line2),
            width = court.LineThickness,
        },
        Line3 = {
            id = "Line3",
            name = "Back Line",
            startPoint = Vector3.new(-halfWidth, centerY, lineZPositions.Line3),
            endPoint = Vector3.new(halfWidth, centerY, lineZPositions.Line3),
            width = court.LineThickness,
        },
        Patotot = {
            id = "Patotot",
            name = "Center Patotot Line",
            startPoint = Vector3.new(0, centerY, -halfLength),
            endPoint = Vector3.new(0, centerY, halfLength),
            width = court.LineThickness,
        },
    }

    return definitions
end

function CourtGeometry.GetZoneDefinitions(): { Types.ZoneBounds }
    local court = Config.Court
    local halfLength = court.TotalLength / 2
    local halfWidth = court.TotalWidth / 2
    local bottomY = court.CenterPosition.Y - 5
    local topY = court.CenterPosition.Y + 20

    local zones: { Types.ZoneBounds } = {
        {
            id = "HomeZone",
            name = "Home Base",
            minPoint = Vector3.new(-halfWidth, bottomY, -halfLength - 20),
            maxPoint = Vector3.new(halfWidth, topY, -halfLength),
            checkpointIndex = 0,
            isEndZone = false,
            isHomeZone = true,
        },
        {
            id = "Zone1",
            name = "Zone 1 (First Quarter)",
            minPoint = Vector3.new(-halfWidth, bottomY, -halfLength),
            maxPoint = Vector3.new(halfWidth, topY, 0),
            checkpointIndex = 1,
            isEndZone = false,
            isHomeZone = false,
        },
        {
            id = "Zone2",
            name = "Zone 2 (Second Quarter)",
            minPoint = Vector3.new(-halfWidth, bottomY, 0),
            maxPoint = Vector3.new(halfWidth, topY, halfLength),
            checkpointIndex = 2,
            isEndZone = false,
            isHomeZone = false,
        },
        {
            id = "EndZone",
            name = "Safehouse / End Zone",
            minPoint = Vector3.new(-halfWidth, bottomY, halfLength),
            maxPoint = Vector3.new(halfWidth, topY, halfLength + 20),
            checkpointIndex = 3,
            isEndZone = true,
            isHomeZone = false,
        },
    }

    return zones
end

--[[
    Projects a 3D point onto a finite line segment in the horizontal plane (XZ).
    Preserves point's Y coordinate or matches line Y.
]]
function CourtGeometry.ProjectPointOntoSegment(point: Vector3, startPoint: Vector3, endPoint: Vector3): Vector3
    local segmentVector = endPoint - startPoint
    local segmentLength = segmentVector.Magnitude

    if segmentLength <= 0.0001 then
        return startPoint
    end

    local unitDirection = segmentVector / segmentLength
    local toPoint = point - startPoint
    local scalarProjection = toPoint:Dot(unitDirection)
    local clampedScalar = math.clamp(scalarProjection, 0, segmentLength)

    local projectedPoint = startPoint + (unitDirection * clampedScalar)
    return Vector3.new(projectedPoint.X, point.Y, projectedPoint.Z)
end

--[[
    Calculates horizontal (XZ) distance from a point to a finite line segment.
]]
function CourtGeometry.GetHorizontalDistanceToSegment(point: Vector3, startPoint: Vector3, endPoint: Vector3): number
    local projected = CourtGeometry.ProjectPointOntoSegment(point, startPoint, endPoint)
    local diff = Vector3.new(point.X - projected.X, 0, point.Z - projected.Z)
    return diff.Magnitude
end

--[[
    Determines which zone a point currently resides in.
]]
function CourtGeometry.GetZoneAtPosition(point: Vector3): Types.ZoneBounds?
    local zones = CourtGeometry.GetZoneDefinitions()
    for _, zone in ipairs(zones) do
        if point.X >= zone.minPoint.X and point.X <= zone.maxPoint.X
            and point.Z >= zone.minPoint.Z and point.Z <= zone.maxPoint.Z then
            return zone
        end
    end
    return nil
end

return CourtGeometry
