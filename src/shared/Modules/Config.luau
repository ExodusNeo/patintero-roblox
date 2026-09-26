--!strict
--[[
    Config.luau
    Centralized configuration and tuning parameters for Patintero.
    Single Source of Truth for physics, court geometry, match rules, and netcode tolerances.
]]

local Config = {
    Court = {
        -- Origin is the center of the court at ground level
        CenterPosition = Vector3.new(0, 0, 0),
        TotalLength = 90, -- Z axis (Home to End)
        TotalWidth = 48,  -- X axis (Left to Right)
        LineThickness = 1.0, -- Chalk line width in studs
        LineHeight = 0.1,    -- Slightly raised for visibility without collision tripping
        ZoneCountZ = 2,      -- 2 main box rows (Line 1, Line 2, Line 3)
    },

    Movement = {
        WalkSpeed = 16,
        SprintSpeed = 26,
        SlideInitialSpeed = 34,
        SlideDuration = 0.65,
        SlideCooldown = 1.4,
        GuardStrafeSpeed = 24,

        -- Stamina
        MaxStamina = 100,
        SprintDrainRate = 18, -- stamina / second
        SlideCost = 25,
        StaminaRegenRate = 16, -- stamina / second
        StaminaRegenDelay = 1.0, -- seconds after last drain
    },

    Tagging = {
        BaseReachDistance = 7.0,     -- Max distance from tagger hand/root to target
        MaxLatencySlackDistance = 3.5, -- Server compensation tolerance for ping jitter
        MaxLineDistanceTolerance = 3.0, -- Guard must be within this distance from assigned line
        TagCooldown = 0.8,           -- Seconds before tagger can swing again
        TagStunDuration = 2.0,       -- Seconds target is immobilized upon tag
    },

    Match = {
        MinPlayersToStart = 2,
        IntermissionTime = 15,
        CountdownTime = 5,
        RoundDuration = 90,
        PointsForTubig = 5,       -- Home -> End -> Home full trip
        PointsForZoneAdvance = 1,  -- Entering a new depth zone
        PointsForTag = 2,          -- Defenders earn points per eliminated runner
        MaxLivesPerPasser = 1,     -- 1 life per runner per round
    },

    CollisionGroups = {
        Passer = "PassersGroup",
        Guard = "GuardsGroup",
        CourtBounds = "CourtBoundsGroup",
        LineGuide = "LineGuideGroup",
    },
}

return table.freeze(Config)
