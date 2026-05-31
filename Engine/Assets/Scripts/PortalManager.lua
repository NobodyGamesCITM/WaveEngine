-- PortalManager.lua

public = {
    updateWhenPaused = true,
    portalMeshName   = "PortalMesh",
    
    mat_0_None       = "UID_10335364735429396590", 
    mat_1_Circle     = "UID_4367927446732336835",
    mat_2_Arch       = "UID_10923264245461588399", 
    mat_3_CircArch   = "UID_14855737213172546021", 
    mat_4_T          = "UID_8973639582815948807", 
    mat_5_CircT      = "UID_854134053850521907", 
    mat_6_ArchT      = "UID_6492819221197486088", 
    mat_7_All        = "UID_11329386542813936116", 

    cinematicMidPoint = 5.0, 
    cinematicEndTime  = 10.0  
}

local portalState = 0 
local activeFires = 0
local portalMatComp = nil
local portalSource = nil
local brokenChains  = nil
local inCinematic = false
local cinTimer = 0.0
local pendingMaterialUpdate = false
local fireParticles = {}
local fireSources = {}

local function UpdatePortalVisuals(self)
    if not portalMatComp then 
        Engine.Log("[PortalManager] ERROR: No hay componente Material en el Portal.")
        return 
    end

    local matArray = {
        [0] = self.public.mat_0_None,
        [1] = self.public.mat_1_Circle,
        [2] = self.public.mat_2_Arch,
        [3] = self.public.mat_3_CircArch,
        [4] = self.public.mat_4_T,
        [5] = self.public.mat_5_CircT,
        [6] = self.public.mat_6_ArchT,
        [7] = self.public.mat_7_All
    }

    local targetMatUID = matArray[portalState]
    if targetMatUID and targetMatUID ~= "UID_0" and targetMatUID ~= "" then
        
        local cleanUID = string.sub(targetMatUID, 5)
        
        portalMatComp.SetTexture(cleanUID)
        Engine.Log("[PortalManager] Material del portal actualizado al UID: " .. cleanUID)
    end

    if activeFires <= 3 and fireParticles[activeFires] and fireSources[activeFires] then
        fireParticles[activeFires]:Play()
        fireSources[activeFires]:SelectPlayAudioEvent("SFX_TorchFire")
        if portalSource then 
            portalSource:SelectPlayAudioEvent("SFX_PortalFireOn") 
            Engine.Log("[PortalManager] Played SFX_PortalFireOn")
        else
            Engine.Log("[PortalManager] Portal Audio Source not found!")
        end
        
        Engine.Log("[PortalManager] Fuego " .. activeFires .. " encendido.")
    end
end

function Start(self)
    _G.PortalManagerInstance = self
    _G.TotalStatuesToDestroy = 3
    _G.keysCollected = 0

    local portalObj = GameObject.Find(self.public.portalMeshName)
    if portalObj then
        portalMatComp = portalObj:GetComponent("Material")
        portalSource = portalObj:GetComponent("Audio Source")
    else
        Engine.Log("[PortalManager] ERROR: No se encontró el mesh del portal.")
    end

    for i = 1, 3 do
        local fireObj = GameObject.Find("Fire" .. i)
        if fireObj then
            local ps = fireObj:GetComponent("ParticleSystem")
            local audiosource = fireObj:GetComponent("Audio Source")

            if ps then ps:Stop() end 
            if audiosource then audiosource:StopAudioEvent() end
            
            fireParticles[i] = ps
            fireSources[i] = audiosource
        end
    end

    self.ActivateStatue = function(self, bitValue, statueId, statueObj)
        if inCinematic then return end 
        
        portalState = portalState | bitValue
        activeFires = activeFires + 1
        _G.keysCollected = activeFires

        if _G.HUD_RefreshStatuesDestroyed then _G.HUD_RefreshStatuesDestroyed() end

        inCinematic = true
        cinTimer = 0.0
        pendingMaterialUpdate = true

        if _G.PlayerInstance then _G.PlayerInstance.public.canMove = false end

        local dustObj = GameObject.FindInChildren(statueObj, "DustParticles")
        local chainsObj = GameObject.FindInChildren(statueObj, "ChainParticles")
        local audioObj = GameObject.FindInChildren(statueObj, "StatueSource")
        brokenChains = GameObject.FindInChildren(statueObj, "broken_chains")

        if dustObj then
            local ps = dustObj:GetComponent("ParticleSystem")
            if ps then ps:Play() end
        end
        
        if chainsObj then
            local ps = chainsObj:GetComponent("ParticleSystem")
            if ps then ps:Play() end
        end

        if audioObj then
            local chainSFX = audioObj:GetComponent("Audio Source")
            if chainSFX then chainSFX:SelectPlayAudioEvent("SFX_ChainBreak") 
            else 
                Engine.Log("[Portal Manager] Failed to retrieve Audio Source Component from Key Statue "..tostring(statueId)) 
            end
        end


        if _G.PlayStatueCinematic then
            _G.PlayStatueCinematic(statueId)
        end
    end

    self.IsPortalOpen = function(self)
        return portalState == 7
    end
end

function Update(self, dt)
    if not inCinematic then return end

    cinTimer = cinTimer + dt

    if brokenChains then

        if cinTimer >= 0.5 and not brokenChains:IsActive() then 
            brokenChains:SetActive(true)
        end
    end

    if pendingMaterialUpdate and cinTimer >= self.public.cinematicMidPoint then
        UpdatePortalVisuals(self)
        pendingMaterialUpdate = false
    end

    if cinTimer >= self.public.cinematicEndTime then
        inCinematic = false
        if _G.PlayerInstance then _G.PlayerInstance.public.canMove = true end
        
        if portalState == 7 then 
            Engine.Log("[PortalManager] Portal completamente abierto.")
        end
    end
end