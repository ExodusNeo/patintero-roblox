--!strict
--[[
    Types.luau
    Centralized type definitions for Patintero systems.
]]

export type Team = "Passers" | "Guards" | "Spectators"

export type GuardRole = "Line1" | "Line2" | "Line3" | "Patotot"

export type MatchPhase = "Lobby" | "Countdown" | "RoundActive" | "RoundEnded" | "MatchOver"

export type MovementState = "Idle" | "Walking" | "Sprinting" | "Sliding" | "Stunned"

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
    movementState: MovementState,
    stamina: number,
    lives: number,
    checkpointProgress: number,
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

export type TagValidationResult = {
    success: boolean,
    reason: string?,
    taggerUserId: number,
    targetUserId: number,
}

export type TagAttemptPayload = {
    targetCharacter: Model,
    taggerPosition: Vector3,
    targetPosition: Vector3,
    clientTimestamp: number,
}

return {}
