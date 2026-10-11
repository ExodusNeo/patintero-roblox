--!strict
--[[
    AvatarService.luau
    Scales every character to the same body height (Config.Avatar.Height) once its appearance has
    loaded, so tall or tiny avatars get no reach or hitbox edge. Runs in both places.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Modules.Config)

local AvatarService = {}

-- Rest-pose offset of a joint from its two rig attachments (works for Motor6D and AnimationConstraint rigs).
local function restOffset(character: Model, part0: string, part1: string, attachment: string): CFrame?
    local a0 = character:FindFirstChild(part0) and (character :: any)[part0]:FindFirstChild(attachment)
    local a1 = character:FindFirstChild(part1) and (character :: any)[part1]:FindFirstChild(attachment)
    if not (a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment")) then
        return nil
    end
    return a0.CFrame * a1.CFrame:Inverse()
end

-- Standing height, feet to top of head, from the rest pose (so the current animation doesn't skew it);
-- accessories (hats, hair) don't count. R15 only (R6 bodies are a fixed size).
local function bodyHeight(character: Model): number?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = humanoid and humanoid.RootPart
    local head = character:FindFirstChild("Head")
    if not (humanoid and root and head and head:IsA("BasePart")) or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return nil
    end
    local rootJoint = restOffset(character, "HumanoidRootPart", "LowerTorso", "RootRigAttachment")
    local waist = restOffset(character, "LowerTorso", "UpperTorso", "WaistRigAttachment")
    local neck = restOffset(character, "UpperTorso", "Head", "NeckRigAttachment")
    if not (rootJoint and waist and neck) then
        return nil
    end
    return humanoid.HipHeight + root.Size.Y / 2 + (rootJoint * waist * neck).Y + head.Size.Y / 2
end

local function normalize(character: Model)
    local height = bodyHeight(character)
    if height and height > 0 then
        character:ScaleTo(character:GetScale() * Config.Avatar.Height / height)
    end
end

function AvatarService.Init()
    local function watch(player: Player)
        player.CharacterAppearanceLoaded:Connect(normalize)
        if player.Character and player:HasAppearanceLoaded() then
            normalize(player.Character)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return AvatarService
