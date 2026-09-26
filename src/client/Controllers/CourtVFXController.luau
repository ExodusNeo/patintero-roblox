--!strict
--[[
    CourtVFXController.luau
    Client presentation controller for audio-visual effects:
    Chalk line highlights, asphalt slide dust bursts, and tag impact VFX.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local CourtVFXController = {}

local function createHitBurst(position: Vector3)
    local part = Instance.new("Part")
    part.Name = "TagHitVFX"
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = Workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = part

    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 80, 50))
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Lifetime = NumberRange.new(0.3, 0.5)
    particles.Rate = 0
    particles.Speed = NumberRange.new(10, 20)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = attachment

    particles:Emit(25)
    Debris:AddItem(part, 1)
end

local function createSlideDust(position: Vector3)
    local part = Instance.new("Part")
    part.Name = "SlideDustVFX"
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = position - Vector3.new(0, 1.5, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = Workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = part

    local dust = Instance.new("ParticleEmitter")
    dust.Color = ColorSequence.new(Color3.fromRGB(190, 180, 170), Color3.fromRGB(220, 215, 210))
    dust.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 2.5),
    })
    dust.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    dust.Lifetime = NumberRange.new(0.4, 0.7)
    dust.Rate = 0
    dust.Speed = NumberRange.new(4, 8)
    dust.SpreadAngle = Vector2.new(60, 60)
    dust.Parent = attachment

    dust:Emit(20)
    Debris:AddItem(part, 1)
end

local function highlightGuardLine(guardRole: Types.GuardRole?)
    local court = Workspace:FindFirstChild("PatinteroCourt")
    if not court then return end

    local chalkLines = court:FindFirstChild("ChalkLines")
    if not chalkLines then return end

    for _, child in ipairs(chalkLines:GetChildren()) do
        if child:IsA("BasePart") then
            local highlight = child:FindFirstChild("LineHighlight")
            if highlight then
                highlight:Destroy()
            end

            if guardRole and child.Name == guardRole then
                local hl = Instance.new("Highlight")
                hl.Name = "LineHighlight"
                hl.FillColor = Color3.fromRGB(255, 200, 50)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0.2
                hl.Adornee = child
                hl.Parent = child
            end
        end
    end
end

function CourtVFXController.Init()
    -- Listen to player role updates to highlight their line
    local playerStateEvent = Remotes.GetEvent("PlayerStateUpdated")
    playerStateEvent.OnClientEvent:Connect(function(state: Types.PlayerMatchState)
        highlightGuardLine(state.guardRole)
    end)

    -- Tag impact burst
    local tagConfirmedEvent = Remotes.GetEvent("TagConfirmed")
    tagConfirmedEvent.OnClientEvent:Connect(function(_taggerId: number, _targetId: number, hitPos: Vector3)
        createHitBurst(hitPos)
    end)

    -- Cosmetic action (Slide dust)
    local cosmeticEvent = Remotes.GetUnreliableEvent("CosmeticAction")
    cosmeticEvent.OnClientEvent:Connect(function(actionType: string, position: Vector3)
        if actionType == "Slide" then
            createSlideDust(position)
        end
    end)
end

return CourtVFXController
