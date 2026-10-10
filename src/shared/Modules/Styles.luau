--!strict
--[[
    Styles.luau
    Rollable style roster (pure data + roll/lookup helpers). Shared so the client can show
    names, rarities and cooldowns; the server is the only one that rolls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Config = require(ReplicatedStorage.Shared.Modules.Config)

local Styles = {}

Styles.RarityOrder = { "Common", "Rare", "Epic", "Legendary" } :: { Types.Rarity }

Styles.RarityColors = table.freeze({
    Common = Color3.fromRGB(200, 200, 210),
    Rare = Color3.fromRGB(80, 160, 255),
    Epic = Color3.fromRGB(190, 90, 255),
    Legendary = Color3.fromRGB(255, 200, 40),
}) :: { [Types.Rarity]: Color3 }

local list: { Types.StyleDef } = {
    {
        id = "Tsinelas", name = "Tsinelas", rarity = "Common", pose = "wave",
        description = "Light on your feet. Slipper-fast bursts.",
        speedMult = 1.05, staminaMult = 1, reachBonus = 0,
        skills = {
            Q = { name = "Dash", kind = "Dash", cooldown = 6, power = 55, duration = 0.2 },
            E = { name = "Takbo!", kind = "Haste", cooldown = 12, power = 1.3, duration = 2.5 },
        },
    },
    {
        id = "Kanto", name = "Kanto", rarity = "Common", pose = "laugh",
        description = "Street-corner endurance. Never runs out of breath.",
        speedMult = 1, staminaMult = 1.25, reachBonus = 0,
        skills = {
            Q = { name = "Dash", kind = "Dash", cooldown = 6, power = 55, duration = 0.2 },
            E = { name = "Second Wind", kind = "SecondWind", cooldown = 14, power = 60 },
        },
    },
    {
        id = "Bantay", name = "Bantay", rarity = "Common", pose = "point",
        description = "Born to guard. Longer arms, longer reach.",
        speedMult = 1, staminaMult = 1, reachBonus = 1,
        skills = {
            Q = { name = "Lunge", kind = "Dash", cooldown = 7, power = 60, duration = 0.15 },
            E = { name = "Long Arm", kind = "LongArm", cooldown = 12, power = 4, duration = 3 },
        },
    },
    {
        id = "Sipa", name = "Sipa", rarity = "Rare", pose = "dance2",
        description = "Hop past the line before anyone blinks.",
        speedMult = 1.05, staminaMult = 1, reachBonus = 0,
        skills = {
            Q = { name = "Hop", kind = "Blink", cooldown = 9, power = 14 },
            E = { name = "Takbo!", kind = "Haste", cooldown = 12, power = 1.3, duration = 2.5 },
        },
    },
    {
        id = "Tumbang", name = "Tumbang", rarity = "Rare", pose = "cheer",
        description = "Knock the can, scatter the crowd.",
        speedMult = 1, staminaMult = 1.1, reachBonus = 0.5,
        skills = {
            Q = { name = "Dash", kind = "Dash", cooldown = 6, power = 55, duration = 0.2 },
            E = { name = "Lata Shock", kind = "Slow", cooldown = 15, radius = 14, mult = 0.5, duration = 2 },
        },
    },
    {
        id = "Habagat", name = "Habagat", rarity = "Epic", pose = "dance3",
        description = "Monsoon wind. Slips through gaps, drags enemies down.",
        speedMult = 1.1, staminaMult = 1.1, reachBonus = 0,
        skills = {
            Q = { name = "Gale Step", kind = "Blink", cooldown = 8, power = 16 },
            E = { name = "Monsoon", kind = "Slow", cooldown = 16, radius = 20, mult = 0.45, duration = 2.5 },
        },
    },
    {
        id = "Anino", name = "Anino", rarity = "Epic", pose = "dance",
        description = "A shadow on the street. Can't tag what you can't touch.",
        speedMult = 1.05, staminaMult = 1, reachBonus = 0,
        skills = {
            Q = { name = "Dash", kind = "Dash", cooldown = 6, power = 60, duration = 0.2 },
            E = { name = "Shadow Veil", kind = "Veil", cooldown = 20, duration = 2.5 },
        },
    },
    {
        id = "Bathala", name = "Bathala", rarity = "Legendary", pose = "cheer",
        description = "The street bows. Time stops for everyone but you.",
        speedMult = 1.1, staminaMult = 1.2, reachBonus = 1,
        skills = {
            Q = { name = "Divine Step", kind = "Blink", cooldown = 7, power = 18 },
            E = { name = "Divine Halt", kind = "Slow", cooldown = 22, radius = 18, mult = 0, duration = 1.5 },
        },
    },
}

local byId: { [string]: Types.StyleDef } = {}
local byRarity: { [Types.Rarity]: { Types.StyleDef } } = {}
for _, style in list do
    byId[style.id] = style
    byRarity[style.rarity] = byRarity[style.rarity] or {}
    table.insert(byRarity[style.rarity], style)
end

Styles.List = list

function Styles.Exists(id: any): boolean
    return typeof(id) == "string" and byId[id] ~= nil
end

-- Unknown ids (e.g. a removed style in old save data) fall back to the default.
function Styles.Get(id: string?): Types.StyleDef
    return (id and byId[id]) or byId[Config.Styles.DefaultStyle]
end

-- Pick a rarity by weight (skipping empty rarities), then a style uniformly within it.
function Styles.Roll(rng: Random): Types.StyleDef
    local weights = Config.Styles.RarityWeights :: { [string]: number }
    local total = 0
    for _, rarity in Styles.RarityOrder do
        if byRarity[rarity] then
            total += weights[rarity] or 0
        end
    end

    local pick = rng:NextNumber() * total
    for _, rarity in Styles.RarityOrder do
        local pool = byRarity[rarity]
        if not pool then continue end
        pick -= weights[rarity] or 0
        if pick <= 0 then
            return pool[rng:NextInteger(1, #pool)]
        end
    end
    return list[1]
end

assert(byId[Config.Styles.DefaultStyle], "Config.Styles.DefaultStyle must be a style id")

return table.freeze(Styles)
