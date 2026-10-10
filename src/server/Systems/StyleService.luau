--!strict
--[[
    StyleService.luau
    Owns each player's Spins and Style (Player attributes) and validates skill casts.
    Movement skills (Dash, Blink, SecondWind) are predicted by the caster's client; this service
    enforces cooldowns and applies everything that affects other players or tagging:
    Character attributes HasteMult, SlowMult, ReachBonus, TagImmune (all timed).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local GameMode = require(ReplicatedStorage.Shared.Modules.GameMode)
local PlayerStateService = require(script.Parent.PlayerStateService)

local StyleService = {}

local rng = Random.new()
local lastSpin: { [Player]: number } = {}
local lastCast: { [Player]: { [string]: number } } = {}
-- Latest expiry per instance+attribute so an older timer never clears a newer effect.
local expiries: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function setTimed(inst: Instance, attribute: string, value: any, duration: number)
    local expiry = os.clock() + duration
    expiries[inst] = expiries[inst] or {}
    expiries[inst][attribute] = expiry
    inst:SetAttribute(attribute, value)

    task.delay(duration, function()
        local byAttr = expiries[inst]
        if byAttr and byAttr[attribute] == expiry then
            byAttr[attribute] = nil
            inst:SetAttribute(attribute, nil)
        end
    end)
end

local function isEnemy(a: Types.Team?, b: Types.Team?): boolean
    return (a == "Passers" and b == "Guards") or (a == "Guards" and b == "Passers")
end

local function applySlow(caster: Player, origin: Vector3, skill: Types.SkillDef)
    local casterState = PlayerStateService.GetState(caster)
    local casterTeam = if casterState then casterState.team else nil
    local radius = skill.radius or 0

    for _, other in Players:GetPlayers() do
        if other == caster then continue end
        local otherState = PlayerStateService.GetState(other)
        if not otherState or not isEnemy(casterTeam, otherState.team) then continue end

        local character = other.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if character and root and (root.Position - origin).Magnitude <= radius then
            setTimed(character, "SlowMult", skill.mult or 0.5, skill.duration or 1)
        end
    end
end

local function applySkill(player: Player, character: Model, root: BasePart, skill: Types.SkillDef)
    local duration = skill.duration or 1
    if skill.kind == "Haste" then
        setTimed(character, "HasteMult", skill.power or 1.25, duration)
    elseif skill.kind == "LongArm" then
        setTimed(character, "ReachBonus", skill.power or 3, duration)
    elseif skill.kind == "Veil" then
        setTimed(character, "TagImmune", true, duration)
    elseif skill.kind == "Slow" then
        applySlow(player, root.Position, skill)
    end
    -- Dash / Blink / SecondWind: caster-side movement only, nothing to apply here.
end

local function onUseSkill(player: Player, slot: any)
    if slot ~= "Q" and slot ~= "E" then return end

    local style = Styles.Get(player:GetAttribute("Style") :: string?)
    local skill = if slot == "Q" then style.skills.Q else style.skills.E

    local now = os.clock()
    local casts = lastCast[player]
    if not casts then
        casts = {}
        lastCast[player] = casts
    end
    if now - (casts[slot] or -math.huge) < skill.cooldown - Config.Styles.SkillCooldownSlack then
        return
    end

    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if not character or not humanoid or humanoid.Health <= 0 or not root then return end

    casts[slot] = now
    applySkill(player, character, root, skill)
    Remotes.GetEvent("SkillCast"):FireAllClients(player.UserId, style.id, slot, root.Position)
end

local function onSpin(player: Player): string?
    -- Spins only in the hub, and not while a teleport is saving this player's data.
    if GameMode.Current ~= "Hub" or player:GetAttribute("Teleporting") then return nil end

    local now = os.clock()
    if now - (lastSpin[player] or -math.huge) < Config.Styles.SpinCooldown then return nil end

    local spins = player:GetAttribute("Spins")
    if typeof(spins) ~= "number" or spins < 1 then return nil end

    lastSpin[player] = now
    local style = Styles.Roll(rng)
    player:SetAttribute("Spins", spins - 1)
    player:SetAttribute("Style", style.id)
    lastCast[player] = nil -- fresh style, fresh cooldowns (the old style is gone: one style per player)
    return style.id
end

function StyleService.AddSpins(player: Player, amount: number)
    local spins = player:GetAttribute("Spins")
    if typeof(spins) == "number" and amount > 0 then
        player:SetAttribute("Spins", spins + math.floor(amount))
    end
end

-- Passive reach plus any active Long Arm bonus.
function StyleService.GetReachBonus(player: Player): number
    local style = Styles.Get(player:GetAttribute("Style") :: string?)
    local character = player.Character
    local active = if character then (character:GetAttribute("ReachBonus") :: number?) or 0 else 0
    return style.reachBonus + active
end

function StyleService.IsTagImmune(character: Model): boolean
    return character:GetAttribute("TagImmune") == true
end

function StyleService.Init()
    Remotes.GetEvent("UseSkill").OnServerEvent:Connect(onUseSkill)
    Remotes.GetFunction("Spin").OnServerInvoke = onSpin

    Players.PlayerRemoving:Connect(function(player)
        lastSpin[player] = nil
        lastCast[player] = nil
    end)
end

return StyleService
