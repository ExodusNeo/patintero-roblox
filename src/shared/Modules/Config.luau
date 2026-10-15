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
        PadSizes = { 8 }, -- one 4 V 4 lobby: everyone gathers there; it starts short-handed (MinToStart / FillTimeout)
        CountdownTime = 5,
        MinToStart = 2, -- a lobby that isn't full starts with this many seated...
        FillTimeout = 30, -- ...after waiting this long (seconds) for the rest
        LeaderboardSize = 10,
        LeaderboardRefresh = 60, -- seconds
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
        -- Server movement check for Passers: zone progress is ignored while a Passer moves faster than this
        MaxRunSpeed = 45, -- studs/s sustained (sprint x fastest style x haste, with slack)
        MaxBurst = 32, -- studs on top of that: one dash + one blink + latency
    },

    Progression = {
        XPPerZone = 5,
        XPPerTubig = 25,
        XPPerTag = 15,
        XPPerRound = 10,
        XPPerWin = 20,
        XPLevelBase = 50, -- level = 1 + floor(sqrt(xp / XPLevelBase)): 50 XP -> 2, 200 -> 3, 450 -> 4
        DailySpins = 3, -- once per UTC day, on the first join
        TutorialSpins = 3, -- reward for finishing the tutorial
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

    Avatar = {
        Height = 5.5, -- studs, feet to top of head in the rest pose; every R15 character is scaled to this (default R15 ≈ 5.46)
    },

    Data = {
        StoreName = "PatinteroPlayerData_v1",
        WeeklyTubigStore = "PatinteroWeeklyTubig_v1", -- OrderedDataStore; one scope per week (Monday 00:00 UTC)
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
