--!strict
--[[
    Remotes.luau
    Centralized declaration and initialization of RemoteEvents and RemoteFunctions.
    Ensures safe access on both Server and Client without race conditions.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "PatinteroRemotes"

local REMOTE_DEFINITIONS = {
    Events = {
        TagAttempt = "RemoteEvent",
        TagConfirmed = "RemoteEvent",
        MatchStateUpdated = "RemoteEvent",
        PlayerStateUpdated = "RemoteEvent",
        ZoneCheckpointReached = "RemoteEvent",
        TubigScored = "RemoteEvent",
        UseSkill = "RemoteEvent", -- client -> server: (slot)
        SkillCast = "RemoteEvent", -- server -> all: (casterUserId, styleId, slot, position)
        SwitchLine = "RemoteEvent", -- client -> server: guard hops to the next free line
    },
    UnreliableEvents = {
        CosmeticAction = "UnreliableRemoteEvent",
    },
    Functions = {
        GetInitialMatchData = "RemoteFunction",
        Spin = "RemoteFunction", -- client -> server, returns rolled style id or nil
    },
}

local Remotes = {}

local function getOrCreateFolder(): Folder
    local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = FOLDER_NAME
            folder.Parent = ReplicatedStorage
        else
            folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10) :: Folder
            assert(folder, "Client timed out waiting for Remotes folder")
        end
    end
    return folder :: Folder
end

function Remotes.Init()
    local folder = getOrCreateFolder()

    if RunService:IsServer() then
        for name, className in pairs(REMOTE_DEFINITIONS.Events) do
            if not folder:FindFirstChild(name) then
                local remote = Instance.new(className)
                remote.Name = name
                remote.Parent = folder
            end
        end

        for name, className in pairs(REMOTE_DEFINITIONS.UnreliableEvents) do
            if not folder:FindFirstChild(name) then
                local remote = Instance.new(className)
                remote.Name = name
                remote.Parent = folder
            end
        end

        for name, className in pairs(REMOTE_DEFINITIONS.Functions) do
            if not folder:FindFirstChild(name) then
                local func = Instance.new(className)
                func.Name = name
                func.Parent = folder
            end
        end
    end
end

function Remotes.GetEvent(name: string): RemoteEvent
    local folder = getOrCreateFolder()
    local remote = folder:WaitForChild(name, 5)
    assert(remote and remote:IsA("RemoteEvent"), `RemoteEvent {name} not found`)
    return remote :: RemoteEvent
end

function Remotes.GetUnreliableEvent(name: string): UnreliableRemoteEvent
    local folder = getOrCreateFolder()
    local remote = folder:WaitForChild(name, 5)
    assert(remote and remote:IsA("UnreliableRemoteEvent"), `UnreliableRemoteEvent {name} not found`)
    return remote :: UnreliableRemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
    local folder = getOrCreateFolder()
    local remote = folder:WaitForChild(name, 5)
    assert(remote and remote:IsA("RemoteFunction"), `RemoteFunction {name} not found`)
    return remote :: RemoteFunction
end

return Remotes
