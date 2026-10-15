--!strict
--[[
    LeaderboardService.luau
    Weekly TUBIG leaderboard. Matches count each Tubig (RecordTubig) in an OrderedDataStore scoped to the
    week (Monday 00:00 UTC); the hub shows the top Config.Hub.LeaderboardSize on a board (ShowOn), refreshed
    every Config.Hub.LeaderboardRefresh seconds.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)

local LeaderboardService = {}

local WEEK = 7 * 86400
local names: { [number]: string } = {}

local function weekStore(): OrderedDataStore?
    local week = math.floor((os.time() + 3 * 86400) / WEEK) -- the Unix epoch was a Thursday
    local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.Data.WeeklyTubigStore, tostring(week))
    return if ok then store else nil
end

function LeaderboardService.RecordTubig(player: Player)
    if RunService:IsStudio() then return end -- Studio tests (incl. Player1.. test accounts) would land on the live board
    local store = weekStore()
    if not store then return end
    task.spawn(function()
        local ok, err = pcall(store.IncrementAsync, store, tostring(player.UserId), 1)
        if not ok then
            warn(`[LeaderboardService] RecordTubig failed: {err}`)
        end
    end)
end

local function nameOf(userId: number): string
    local cached = names[userId]
    if cached then return cached end
    local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    local result = if ok then name else "?"
    names[userId] = result
    return result
end

-- rows[i] shows place i; empty places stay blank
local function refresh(rows: { TextLabel })
    local store = weekStore()
    if not store then return end
    local ok, pages = pcall(store.GetSortedAsync, store, false, #rows)
    if not ok then
        warn(`[LeaderboardService] read failed: {pages}`)
        return
    end
    local entries = (pages :: DataStorePages):GetCurrentPage()
    for i, row in rows do
        local entry = entries[i]
        local userId = if entry then tonumber(entry.key) else nil
        row.Text = if entry and userId then `{i}. {nameOf(userId)}   {entry.value}` else ""
    end
end

function LeaderboardService.ShowOn(rows: { TextLabel })
    task.spawn(function()
        while true do
            refresh(rows)
            task.wait(Config.Hub.LeaderboardRefresh)
        end
    end)
end

return LeaderboardService
