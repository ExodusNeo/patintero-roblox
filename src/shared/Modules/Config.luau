--!strict
--[[
    Config.luau
    Centralized configuration and tuning parameters for Patintero.
    Single Source of Truth for physics, court geometry, match rules, and netcode tolerances.
]]

local RunService = game:GetService("RunService")

local Config = {
    -- One codebase is published to both places; GameMode picks the side by PlaceId.
    Places = {
        HubPlaceId = 88319696116229,
        MatchPlaceId = 70710330155642,
    },

    Hub = {
        Center = Vector3.new(400, 0, 0),
        PadSizes = { 2, 4, 6, 8 },
        CountdownTime = 5,
    },

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

        -- Heavy, momentum-based feel (client): input eases toward its target instead of snapping
        AccelTime = 0.55, -- seconds from standing still to full speed
        DecelTime = 0.4, -- seconds to skid to a stop after letting go
        AirControl = 0.25, -- fraction of acceleration while airborne
        SprintRampRate = 10, -- studs/s of WalkSpeed gained per second (sprint builds up)
        StrafeMult = 0.8, -- first person: sideways speed
        BackpedalMult = 0.6, -- first person: backwards speed
        JumpHeight = 4.5,
        JumpStaminaCost = 12,
        HardLandingSpeed = 60, -- falling faster than this (studs/s, ~9 stud drop) stuns your stride; a normal jump lands ~42
        LandingSlowTime = 0.45,
        LandingSlowMult = 0.5,
    },

    Tagging = {
        BaseReachDistance = 7.0,
        MaxLatencySlackDistance = 3.5,
        MaxLineDistanceTolerance = 3.5,
        TagCooldown = 0.8,
        LineSwitchCooldown = 4, -- guard "line hop" (keeps small matches fair for 1-2 guards)
    },

    Match = {
        -- Automatically allow solo testing in Studio so 1 player can test all systems
        MinPlayersToStart = if RunService:IsStudio() then 1 else 2,
        IntermissionTime = 10,
        ArrivalTimeout = 20, -- match server: max wait for the rest of the hub's party
        JoinSettleTime = 5, -- start only after no one has joined for this long
        CountdownTime = 3,
        RoundDuration = 90,
        PointsForTubig = 5,
        PointsForZoneAdvance = 1,
        PointsForTag = 2,
    },

    Styles = {
        DefaultStyle = "Tsinelas",
        RarityWeights = { Common = 55, Rare = 30, Epic = 12, Legendary = 3 },
        StartingSpins = 10,
        SpinsPerRound = 1,
        SpinsPerTubig = 1,
        SpinCooldown = 1.0, -- server rate limit; also covers the client roll animation (hub only)
        SkillCooldownSlack = 0.15, -- latency tolerance on server cooldown checks
    },

    Data = {
        StoreName = "PatinteroPlayerData_v1",
        Retries = 3,
    },

    CollisionGroups = {
        Passer = "PassersGroup",
        Guard = "GuardsGroup",
        CourtBounds = "CourtBoundsGroup",
        LineGuide = "LineGuideGroup",
    },
}

return table.freeze(Config)
