--!strict
--[[
    SoundController.luau
    Client sound system managing audio buses, pitch variation,
    footsteps, sneaker screeches, referee whistles, slide friction,
    and celebratory "TUBIG!" fanfare.
]]

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local SoundController = {}

-- Audio Bus Groups
local masterGroup: SoundGroup
local sfxGroup: SoundGroup
local uiGroup: SoundGroup
local ambienceGroup: SoundGroup

-- Verified Audio Assets from Creator Store
local SOUND_CONFIGS: { [string]: { id: string, volume: number, looped: boolean? } } = {
    WhistleShort = { id = "rbxassetid://9117261163", volume = 0.8 },
    WhistleLong = { id = "rbxassetid://9118113825", volume = 0.9 },
    WhistleDouble = { id = "rbxassetid://9118114334", volume = 0.85 },
    SneakerSqueak1 = { id = "rbxassetid://72827234719643", volume = 0.65 },
    SneakerSqueak2 = { id = "rbxassetid://72827234719643", volume = 0.65 },
    SlideWhoosh = { id = "rbxassetid://9126229255", volume = 0.85 },
    TagSlap = { id = "rbxassetid://9120499748", volume = 1.0 },
    TubigFanfare = { id = "rbxassetid://9067124098", volume = 0.95 },
    CheckpointChime = { id = "rbxassetid://1301186018", volume = 0.75 },
    StreetAmbience = { id = "rbxassetid://108780908532387", volume = 0.35, looped = true },
}

local loadedSounds: { [string]: Sound } = {}
local activeSlideSound: Sound? = nil
local ambienceSound: Sound? = nil

local function setupAudioBuses()
    masterGroup = Instance.new("SoundGroup")
    masterGroup.Name = "PatinteroMaster"
    masterGroup.Volume = 1.0
    masterGroup.Parent = SoundService

    sfxGroup = Instance.new("SoundGroup")
    sfxGroup.Name = "SFX"
    sfxGroup.Volume = 0.9
    sfxGroup.Parent = masterGroup

    uiGroup = Instance.new("SoundGroup")
    uiGroup.Name = "UI"
    uiGroup.Volume = 0.85
    uiGroup.Parent = masterGroup

    ambienceGroup = Instance.new("SoundGroup")
    ambienceGroup.Name = "Ambience"
    ambienceGroup.Volume = 0.4
    ambienceGroup.Parent = masterGroup
end

local function getTargetSoundGroup(name: string): SoundGroup
    if name == "StreetAmbience" then
        return ambienceGroup
    elseif name == "TubigFanfare" or name == "CheckpointChime" or string.find(name, "Whistle") then
        return uiGroup
    end
    return sfxGroup
end

local function preloadSounds()
    local soundFolder = Instance.new("Folder")
    soundFolder.Name = "PatinteroSoundCache"
    soundFolder.Parent = SoundService

    for name, config in pairs(SOUND_CONFIGS) do
        local sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = config.id
        sound.Volume = config.volume
        sound.Looped = config.looped or false
        sound.SoundGroup = getTargetSoundGroup(name)
        sound.Parent = soundFolder
        loadedSounds[name] = sound
    end
end

-- Play a 2D Sound with pitch variation to eliminate ear fatigue
function SoundController.PlaySFX(name: string, pitchRange: Vector2?, volumeMultiplier: number?)
    local template = loadedSounds[name]
    if not template then return end

    local sound = template:Clone()
    local minPitch = if pitchRange then pitchRange.X else 0.95
    local maxPitch = if pitchRange then pitchRange.Y else 1.05
    sound.PlaybackSpeed = minPitch + math.random() * (maxPitch - minPitch)

    if volumeMultiplier then
        sound.Volume = template.Volume * volumeMultiplier
    end

    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

-- Play a 3D Spatial Sound at a physical world position
function SoundController.PlaySpatialSFX(name: string, position: Vector3, pitchRange: Vector2?)
    local template = loadedSounds[name]
    if not template then return end

    local anchor = Instance.new("Part")
    anchor.Name = "SpatialAudioNode"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = position
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = Workspace

    local sound = template:Clone()
    local minPitch = if pitchRange then pitchRange.X else 0.95
    local maxPitch = if pitchRange then pitchRange.Y else 1.05
    sound.PlaybackSpeed = minPitch + math.random() * (maxPitch - minPitch)
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = 90
    sound.Parent = anchor

    sound:Play()
    sound.Ended:Once(function()
        anchor:Destroy()
    end)
    Debris:AddItem(anchor, 5)
end

-- Play random sneaker squeak on rapid turn or sprint start
function SoundController.PlaySneakerSqueak()
    local name = if math.random() > 0.5 then "SneakerSqueak1" else "SneakerSqueak2"
    SoundController.PlaySFX(name, Vector2.new(0.9, 1.1), 0.7)
end

-- Continuous Power Slide Audio
function SoundController.StartSlideSound()
    SoundController.PlaySneakerSqueak()

    local template = loadedSounds["SlideWhoosh"]
    if not template then return end

    if activeSlideSound then
        activeSlideSound:Destroy()
    end

    local slideSound = template:Clone()
    slideSound.Volume = 0.2
    slideSound.PlaybackSpeed = 1.1
    slideSound.Parent = SoundService
    slideSound:Play()

    -- Quick volume ramp up
    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(slideSound, tweenInfo, { Volume = template.Volume }):Play()
    activeSlideSound = slideSound
end

function SoundController.StopSlideSound()
    if activeSlideSound then
        local sound = activeSlideSound
        activeSlideSound = nil
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local fade = TweenService:Create(sound, tweenInfo, { Volume = 0 })
        fade:Play()
        fade.Completed:Once(function()
            sound:Destroy()
        end)
    end
end

-- Stamina Audio Feedback
function SoundController.UpdateStaminaAudio(_staminaRatio: number)
    -- Reserved for heartbeat/breathing cues
end

function SoundController.Init()
    setupAudioBuses()
    preloadSounds()

    -- Start looping street ambience
    local ambTemplate = loadedSounds["StreetAmbience"]
    if ambTemplate then
        ambienceSound = ambTemplate:Clone()
        ambienceSound.Parent = SoundService
        ambienceSound:Play()
    end

    -- Hook Match State Updates for referee whistles
    local lastPhase: Types.MatchPhase = "Lobby"
    local matchStateEvent = Remotes.GetEvent("MatchStateUpdated")
    matchStateEvent.OnClientEvent:Connect(function(state: Types.MatchState)
        if state.phase == "Countdown" and state.timeRemaining <= 3 and state.timeRemaining > 0 then
            SoundController.PlaySFX("WhistleShort", Vector2.new(1.0, 1.0))
        elseif state.phase == "RoundActive" and lastPhase ~= "RoundActive" then
            -- Long sharp referee whistle to start the round!
            SoundController.PlaySFX("WhistleLong", Vector2.new(1.0, 1.05))
        elseif (state.phase == "RoundEnded" or state.phase == "MatchOver") and lastPhase == "RoundActive" then
            -- Double whistle blast for round end
            SoundController.PlaySFX("WhistleDouble", Vector2.new(0.98, 1.02))
        end
        lastPhase = state.phase
    end)

    -- Hook Checkpoint Audio
    local checkpointEvent = Remotes.GetEvent("ZoneCheckpointReached")
    checkpointEvent.OnClientEvent:Connect(function(_userId: number, _zoneName: string)
        SoundController.PlaySFX("CheckpointChime", Vector2.new(0.95, 1.05))
    end)

    -- Hook Tubig Scored Audio (Grand Fanfare!)
    local tubigEvent = Remotes.GetEvent("TubigScored")
    tubigEvent.OnClientEvent:Connect(function(_userId: number, _playerName: string)
        SoundController.PlaySFX("WhistleLong", Vector2.new(1.1, 1.15))
        task.delay(0.2, function()
            SoundController.PlaySFX("TubigFanfare", Vector2.new(1.0, 1.0))
        end)
    end)

    -- Hook Tag Confirmed Audio
    local tagConfirmedEvent = Remotes.GetEvent("TagConfirmed")
    tagConfirmedEvent.OnClientEvent:Connect(function(_taggerId: number, _targetId: number, hitPos: Vector3)
        SoundController.PlaySpatialSFX("TagSlap", hitPos, Vector2.new(0.95, 1.1))
        SoundController.PlaySFX("WhistleShort", Vector2.new(1.15, 1.25))
    end)
end

return SoundController
