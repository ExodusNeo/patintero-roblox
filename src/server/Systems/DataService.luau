--!strict
--[[
    DataService.luau
    Loads and saves each player's Spins + Style (players keep exactly one style), XP and TutorialDone (finished
    the tutorial or a match). The live values are the Player attributes `Spins`, `Style` (owned by StyleService),
    `XP` (ProgressionService) and `TutorialDone` (TutorialService / MatchService); this service only persists them. The first join of
    each UTC day adds Config.Progression.DailySpins.
    shortcut: no session locking (last write wins across servers); move to ProfileStore if trading/paid spins are added.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)
local Styles = require(ReplicatedStorage.Shared.Modules.Styles)

local DataService = {}

local store: DataStore? = nil
-- Players whose load succeeded. Only these are saved, so a failed load never overwrites real data.
local saveable: { [Player]: boolean } = {}
-- Players saved right before a teleport. Later saves are skipped so a slow save from this server
-- can't land after the destination server has already loaded newer data.
local released: { [Player]: boolean } = {}
-- UTC day number of the last daily-spin grant
local dailyDay: { [Player]: number } = {}

local function keyFor(player: Player): string
    return `u_{player.UserId}`
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
    for attempt = 1, Config.Data.Retries do
        local ok, result = pcall(fn)
        if ok then
            return true, result
        end
        warn(`[DataService] {label} failed (attempt {attempt}): {result}`)
        if attempt < Config.Data.Retries then
            task.wait(attempt)
        end
    end
    return false, nil
end

local function load(player: Player)
    local spins = Config.Styles.StartingSpins
    local style = Config.Styles.DefaultStyle
    local xp = 0
    local lastDaily = 0
    local tutorialDone = false

    local ok, data = false, nil
    if store then
        local ds = store
        ok, data = withRetries(`load {player.UserId}`, function()
            return ds:GetAsync(keyFor(player))
        end)
    end

    if ok and typeof(data) == "table" then
        local savedSpins = data.spins
        if typeof(savedSpins) == "number" and savedSpins == savedSpins and savedSpins >= 0 and savedSpins < 1e9 then
            spins = math.floor(savedSpins)
        end
        if Styles.Exists(data.style) then
            style = data.style
        end
        local savedXp = data.xp
        if typeof(savedXp) == "number" and savedXp == savedXp and savedXp >= 0 and savedXp < 1e9 then
            xp = math.floor(savedXp)
        end
        if typeof(data.lastDaily) == "number" then
            lastDaily = data.lastDaily
        end
        tutorialDone = data.tutorialDone == true or data.seenGuide == true -- seenGuide: the earlier name
    end

    -- Daily spins only on a real load, so a DataStore outage can't hand them out again and again
    local today = math.floor(os.time() / 86400)
    if ok and today > lastDaily then
        spins += Config.Progression.DailySpins
        lastDaily = today
    end

    if not player.Parent then return end
    saveable[player] = ok
    if not ok then
        warn(`[DataService] Using unsaved defaults for {player.Name} (DataStore unavailable; enable Studio API access to test saving)`)
    end
    dailyDay[player] = lastDaily
    player:SetAttribute("Spins", spins)
    player:SetAttribute("Style", style)
    -- Unknown data (load failed) counts as done, so a DataStore outage doesn't send everyone to the tutorial
    player:SetAttribute("TutorialDone", tutorialDone or not ok)
    player:SetAttribute("XP", xp)
end

local function save(player: Player)
    local ds = store
    if not ds or not saveable[player] or released[player] then return end

    local data = {
        spins = player:GetAttribute("Spins"),
        style = player:GetAttribute("Style"),
        xp = player:GetAttribute("XP"),
        lastDaily = dailyDay[player],
        tutorialDone = player:GetAttribute("TutorialDone") == true,
    }
    withRetries(`save {player.UserId}`, function()
        return ds:UpdateAsync(keyFor(player), function()
            return data
        end)
    end)
end

-- Saves in parallel and yields until every save finished.
local function saveAll(players: { Player })
    local pending = #players
    for _, player in players do
        task.spawn(function()
            save(player)
            pending -= 1
        end)
    end
    while pending > 0 do
        task.wait()
    end
end

-- Call right before teleporting players away: saves now, then stops saving them here.
function DataService.Release(players: { Player })
    saveAll(players)
    for _, player in players do
        released[player] = true
    end
end

-- Teleport failed: the player stays, so this server owns their data again.
function DataService.Resume(player: Player)
    released[player] = nil
end

function DataService.Init()
    local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.Data.StoreName)
    if ok then
        store = result
    else
        warn(`[DataService] DataStore unavailable: {result}`)
    end

    Players.PlayerAdded:Connect(load)
    for _, player in Players:GetPlayers() do
        task.spawn(load, player)
    end

    Players.PlayerRemoving:Connect(function(player)
        save(player)
        saveable[player] = nil
        released[player] = nil
        dailyDay[player] = nil
    end)

    game:BindToClose(function()
        saveAll(Players:GetPlayers())
    end)
end

return DataService
