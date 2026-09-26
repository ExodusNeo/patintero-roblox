--!strict
--[[
    Config.luau
    Centralized configuration and tuning parameters for Patintero.
    Single Source of Truth for physics, court geometry, match rules, and netcode tolerances.
]]

local RunService = game:GetService("RunService")

local Config = {
    Court = {
        CenterPosition = Vector3.new(0, 0, 0),
        TotalLength = 90, -- Z axis (Home to End)
        TotalWidth = 48,  -- X axis (Left to Right)
        LineThickness = 1.0, -- Chalk line width in studs
        LineHeight = 0.1,
        ZoneCountZ = 2,
    },

    Movement = {
        WalkSpeed = 16,
        SprintSpeed = 26,
        SlideInitialSpeed = 42, -- Snappy athletic slide
        SlideDuration = 0.7,
        SlideCooldown = 0.8,
        GuardStrafeSpeed = 26,

        -- Stamina
        MaxStamina = 100,
        SprintDrainRate = 18,
        SlideCost = 20,
        StaminaRegenRate = 18,
        StaminaRegenDelay = 0.8,
    },

    Tagging = {
        BaseReachDistance = 7.0,
        MaxLatencySlackDistance = 3.5,
        MaxLineDistanceTolerance = 3.5,
        TagCooldown = 0.8,
        TagStunDuration = 2.0,
    },

    Match = {
        -- Automatically allow solo testing in Studio so 1 player can test all systems
        MinPlayersToStart = if RunService:IsStudio() then 1 else 2,
        IntermissionTime = 10,
        CountdownTime = 3,
        RoundDuration = 90,
        PointsForTubig = 5,
        PointsForZoneAdvance = 1,
        PointsForTag = 2,
        MaxLivesPerPasser = 1,
    },

    CollisionGroups = {
        Passer = "PassersGroup",
        Guard = "GuardsGroup",
        CourtBounds = "CourtBoundsGroup",
        LineGuide = "LineGuideGroup",
    },
}

return table.freeze(Config)
