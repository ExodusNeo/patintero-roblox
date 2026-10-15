--!strict
--[[
    ProgressionService.luau
    XP and levels (both places). The Player attribute `XP` (loaded/saved by DataService) is the source; `Level`
    is derived from it and shown in the player list (leaderstats). Matches award XP with AddXP; crossing a
    level fires LevelUp to that player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local ProgressionService = {}

function ProgressionService.LevelFor(xp: number): number
    return 1 + math.floor(math.sqrt(xp / Config.Progression.XPLevelBase))
end

local function refresh(player: Player)
    local xp = player:GetAttribute("XP")
    if typeof(xp) ~= "number" then return end
    local level = ProgressionService.LevelFor(xp)
    player:SetAttribute("Level", level)

    local stats = player:FindFirstChild("leaderstats")
    if not stats then
        stats = Instance.new("Folder")
        stats.Name = "leaderstats"
        stats.Parent = player
    end
    local value = stats:FindFirstChild("Level") :: IntValue?
    if not value then
        local created = Instance.new("IntValue")
        created.Name = "Level"
        created.Parent = stats
        value = created
    end
    (value :: IntValue).Value = level
end

-- No-op until the player's data has loaded (XP attribute missing), so a load can't overwrite awarded XP
function ProgressionService.AddXP(player: Player, amount: number)
    local xp = player:GetAttribute("XP")
    if typeof(xp) ~= "number" or amount <= 0 then return end
    local before = ProgressionService.LevelFor(xp)
    player:SetAttribute("XP", xp + amount)
    local after = ProgressionService.LevelFor(xp + amount)
    if after > before then
        Remotes.GetEvent("LevelUp"):FireClient(player, after)
    end
end

local function watch(player: Player)
    player:GetAttributeChangedSignal("XP"):Connect(function()
        refresh(player)
    end)
    refresh(player)
end

function ProgressionService.Init()
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return ProgressionService
