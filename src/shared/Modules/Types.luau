--!strict
--[[
    Types.luau
    Centralized type definitions for Patintero systems.
]]

export type Team = "Passers" | "Guards" | "Spectators"

export type GuardRole = "Line1" | "Line2" | "Line3" | "Patotot"

export type MatchPhase = "Lobby" | "Countdown" | "RoundActive" | "RoundEnded" | "MatchOver"

export type LapPhase = "Outbound" | "Inbound"

export type LineDefinition = {
    id: GuardRole,
    name: string,
    startPoint: Vector3,
    endPoint: Vector3,
    width: number,
}

export type ZoneBounds = {
    id: string,
    name: string,
    minPoint: Vector3,
    maxPoint: Vector3,
    checkpointIndex: number,
    isEndZone: boolean,
    isHomeZone: boolean,
}

export type PlayerMatchState = {
    userId: number,
    team: Team,
    guardRole: GuardRole?,
    lapPhase: LapPhase,
    highestZoneCleared: number,
    hasReachedEndZone: boolean,
    isTagged: boolean,
}

export type MatchState = {
    phase: MatchPhase,
    roundNumber: number,
    timeRemaining: number,
    passerScore: number,
    guardScore: number,
    activePasserCount: number,
}

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"

export type SkillKind = "Dash" | "Blink" | "Haste" | "SecondWind" | "LongArm" | "Slow" | "Veil"

export type SkillSlot = "Q" | "E"

-- power: Dash speed / Blink distance / SecondWind stamina / LongArm reach / Haste mult
-- mult: Slow speed multiplier (0 = freeze)
export type SkillDef = {
    name: string,
    kind: SkillKind,
    cooldown: number,
    power: number?,
    duration: number?,
    radius: number?,
    mult: number?,
}

export type StyleDef = {
    id: string,
    name: string,
    rarity: Rarity,
    description: string,
    speedMult: number,
    staminaMult: number,
    reachBonus: number,
    skills: { Q: SkillDef, E: SkillDef },
    -- Showcase pose: an emote from the character's Animate script
    -- (wave, point, dance, dance2, dance3, cheer, laugh)
    pose: string,
}

return {}
