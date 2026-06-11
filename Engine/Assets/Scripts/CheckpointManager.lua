public = {
    offsetX      = 0.0,
    offsetY      = 0.0,
    offsetZ      = 0.0,
    near         = 10.0,
    saveCooldown = 5.0,
    updateWhenPaused = true,
}

local normalTexUUID  = "15061063724499349633"
local glowingTexUUID = "5205049906102326052"

local currentCheckpoint  = nil
local previousCheckpoint = nil

local checkpointState = {}


local function ChangeTexture(texUUID, checkpoint)
    if not checkpoint then return end
    local buho = GameObject.FindInChildren(checkpoint, "Buho")
    if not buho then return end
    local mat = buho:GetComponent("Material")
    if mat then mat.SetTexture(texUUID) end
end

local function ActivateParticles(vfxName, checkpoint)
    if not checkpoint then return end
    local vfxObj = GameObject.FindInChildren(checkpoint, vfxName)
    if not vfxObj then return end
    vfxObj:SetActive(true)
    local ps = vfxObj:GetComponent("ParticleSystem")
    if ps and not ps:IsPlaying() then ps:Play() end
end

local function StopParticles(vfxName, checkpoint)
    if not checkpoint then return end
    local vfxObj = GameObject.FindInChildren(checkpoint, vfxName)
    if not vfxObj then return end
    local ps = vfxObj:GetComponent("ParticleSystem")
    if ps and ps:IsPlaying() then ps:Stop() end
    vfxObj:SetActive(false)
end

local function FindAudioSource(self)
    local src = GameObject.FindInChildren(self.gameObject, "VoiceSource")
    if src then self.saveSFX = src:GetComponent("Audio Source") end
end

local function activateCheckpoint(self, checkpoint)
    previousCheckpoint = currentCheckpoint
    currentCheckpoint  = checkpoint

    local pos = checkpoint.transform.worldPosition
    pos.x = pos.x + self.public.offsetX
    pos.y = pos.y + self.public.offsetY
    pos.z = pos.z + self.public.offsetZ
    lastCheckpoint = pos

    if previousCheckpoint then
        StopParticles("LastCheckpointVFX", previousCheckpoint)
        StopParticles("BlueSparkles",      previousCheckpoint)
        ActivateParticles("Sparkles",      previousCheckpoint)
        ChangeTexture(normalTexUUID,       previousCheckpoint)
    end

    ActivateParticles("LastCheckpointVFX", currentCheckpoint)
    ActivateParticles("BlueSparkles",      currentCheckpoint)
    StopParticles("YellowSparkles",        currentCheckpoint)
    ChangeTexture(glowingTexUUID,          currentCheckpoint)

    if self.saveSFX then self.saveSFX:SelectPlayAudioEvent("SFX_CheckPointSave") end

    if _G.ShowSaveIcon then _G.ShowSaveIcon() end

    local st = checkpointState[checkpoint]
    st.cooldownTimer = self.public.saveCooldown
    st.registered    = false
    _G.UnregisterInteractable(checkpoint)

    _G.RestorePotions()

    Engine.Log("[CHECKPOINT] Checkpoint activado")
end

local function Initialize(self)
    FindAudioSource(self)
    checkpointState = {}

    _G._InteractCallbacks = _G._InteractCallbacks or {}

    checkpoints = GameObject.FindByTag("CheckPoint")
    for _, cp in ipairs(checkpoints) do
        checkpointState[cp] = {
            inRange      = false,
            cooldownTimer = 0,
            registered   = false,
        }

        StopParticles("LastCheckpointVFX", cp)
        StopParticles("BlueSparkles",      cp)
        ActivateParticles("YellowSparkles", cp)

        -- Captura local para el closure
        local checkpoint = cp
        _G._InteractCallbacks[cp] = function()
            activateCheckpoint(self, checkpoint)
        end
    end
end

function Start(self)
    Initialize(self)
end

function Update(self, dt)
    if not checkpoints then Initialize(self) end
    if not self.saveSFX then FindAudioSource(self) end

    local player = _G.PlayerInstance or GameObject.Find("Player")
    if not player then return end
    local playerPos = player.transform.worldPosition

    for _, cp in ipairs(checkpoints) do
        local st  = checkpointState[cp]
        if not st then
            checkpointState[cp] = { inRange = false, cooldownTimer = 0, registered = false }
            st = checkpointState[cp]
        end

        -- Tick cooldown
        if st.cooldownTimer > 0 then
            st.cooldownTimer = st.cooldownTimer - dt
            if st.cooldownTimer <= 0 then
                st.cooldownTimer = 0
                -- Si el jugador sigue en rango, volver a registrar
                if st.inRange then
                    _G.RegisterInteractable(cp, "checkpoint")
                    st.registered = true
                end
            end
        end

        -- Detección de rango
        local pos = cp.transform.worldPosition
        local dx  = pos.x - playerPos.x
        local dz  = pos.z - playerPos.z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist < self.public.near then
            if not st.inRange then
                st.inRange = true
                if st.cooldownTimer <= 0 and not st.registered then
                    _G.RegisterInteractable(cp, "checkpoint")
                    st.registered = true
                end
            end
        else
            if st.inRange then
                st.inRange    = false
                st.registered = false
                _G.UnregisterInteractable(cp)
            end
        end
    end
end

function _G.RestorePotions()
    if _G.TriggerBlueVignette then _G.TriggerBlueVignette() end

    if _G.PotionSystem then
        local ps = _G.PotionSystem.public
        ps.potionCount  = ps.maxPotions or 0
        ps.berserkCount = ps.maxBerserk or 0
    end

    if _G.PlayerInstance then
        _G.PlayerInstance.public.health  = 100
        _G.PlayerInstance.public.stamina = 100
    end

    if _G.ForceRefreshHUD    then _G.ForceRefreshHUD()         end
    if _G.SaveManager and _G.SaveManager.SaveGame then
        _G.SaveManager.SaveGame()
    end
end