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

local portalState = _G.PortalState or 0 
local activeFires = _G.keysCollected or 0
local portalMatComp = nil
local portalSource = nil
local brokenChains  = nil
local inCinematic = false
local cinTimer = 0.0
local pendingMaterialUpdate = false
local fireParticles = {}
local fireSources = {}

local pendingEffects = false
local currentStatueObj = nil
local currentInitChains = nil
local currentBrokenChains = nil

local fireTransitionActive = false
local fireTransitionTimer = 0.0
local fireTransitionDuration = 1.0

local initGradient = {
    { time = 0.0, color = {1.0, 0.6, 0.0, 1.0} },
    { time = 0.5, color = {1.0, 0.1, 0.0, 0.8} },
    { time = 1.0, color = {0.1, 0.0, 0.0, 0.0} }
}
local initStartColor = {1.0, 0.8, 0.0, 1.0}
local initEndColor   = {1.0, 0.0, 0.0, 0.0}

local targetGradient = {
    { time = 0.25, color = {0.0, 0.737, 1.0, 1.0} },
    { time = 0.5,  color = {0.18, 1.0, 0.831, 0.6} },
    { time = 1.0,  color = {0.0, 0.031, 1.0, 1.0} }
}
local targetStartColor = {0.0, 0.796, 1.0, 1.0}
local targetEndColor   = {0.439, 0.0, 1.0, 1.0}

local function Lerp(a, b, t)
    return a + (b - a) * t
end

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

    for i = 1, activeFires do
        if i <= 3 and fireParticles[i] and fireSources[i] then
            if not fireParticles[i]:IsPlaying() then
                fireParticles[i]:Play()
                fireSources[i]:SelectPlayAudioEvent("SFX_TorchFire")
            end
        end
    end
    
    if activeFires > 0 and portalSource then 
        portalSource:SelectPlayAudioEvent("SFX_PortalFireOn") 
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

    self.ActivateStatue = function(self, bitValue, statueId, statueObj, initChains, brokenChains)
        if inCinematic then return end 
        
        portalState = portalState | bitValue
        _G.PortalState = portalState
        activeFires = activeFires + 1
        _G.keysCollected = activeFires

        if _G.HUD_RefreshStatuesDestroyed then _G.HUD_RefreshStatuesDestroyed() end

        inCinematic = true
        cinTimer = 0.0
        pendingMaterialUpdate = true
        
        pendingEffects = true
        currentStatueObj = statueObj
        currentInitChains = initChains
        currentBrokenChains = brokenChains

        if _G.PlayerInstance then _G.PlayerInstance.public.canMove = false end

        if _G.PlayStatueCinematic then
            _G.PlayStatueCinematic(statueId)
        end
    end

    self.IsPortalOpen = function(self)
        return portalState == 7
    end

    self.StartFireTransition = function(self, duration)
        fireTransitionDuration = duration
        fireTransitionTimer = 0.0
        fireTransitionActive = true
    end
end

function Update(self, dt)
    if _G.ForcePortalUpdate then
        portalState = _G.PortalState or 0
        activeFires = _G.keysCollected or 0
        UpdatePortalVisuals(self)
        _G.ForcePortalUpdate = false
    end

    if fireTransitionActive then
        fireTransitionTimer = fireTransitionTimer + dt
        local t = math.min(fireTransitionTimer / fireTransitionDuration, 1.0)
        
        local smoothT = t * t * (3.0 - 2.0 * t)
        
        for i = 1, 3 do
            if fireParticles[i] then
                fireParticles[i]:ClearColorGradient()
                
                for k = 1, 3 do
                    local kt = Lerp(initGradient[k].time, targetGradient[k].time, smoothT)
                    local kr = Lerp(initGradient[k].color[1], targetGradient[k].color[1], smoothT)
                    local kg = Lerp(initGradient[k].color[2], targetGradient[k].color[2], smoothT)
                    local kb = Lerp(initGradient[k].color[3], targetGradient[k].color[3], smoothT)
                    local ka = Lerp(initGradient[k].color[4], targetGradient[k].color[4], smoothT)
                    fireParticles[i]:AddColorGradientKey(kt, kr, kg, kb, ka)
                end
                
                local sr = Lerp(initStartColor[1], targetStartColor[1], smoothT)
                local sg = Lerp(initStartColor[2], targetStartColor[2], smoothT)
                local sb = Lerp(initStartColor[3], targetStartColor[3], smoothT)
                local sa = Lerp(initStartColor[4], targetStartColor[4], smoothT)
                fireParticles[i]:SetStartColor(sr, sg, sb, sa)
                
                local er = Lerp(initEndColor[1], targetEndColor[1], smoothT)
                local eg = Lerp(initEndColor[2], targetEndColor[2], smoothT)
                local eb = Lerp(initEndColor[3], targetEndColor[3], smoothT)
                local ea = Lerp(initEndColor[4], targetEndColor[4], smoothT)
                fireParticles[i]:SetEndColor(er, eg, eb, ea)
            end
        end
        
        if t >= 1.0 then
            fireTransitionActive = false
        end
    end

    if not inCinematic then return end
    cinTimer = cinTimer + dt

    if pendingEffects and cinTimer >= 1.0 then
        pendingEffects = false
        
        if currentInitChains then currentInitChains:SetActive(false) end
        if currentBrokenChains then currentBrokenChains:SetActive(true) end

        if currentStatueObj then
            local dustObj = GameObject.FindInChildren(currentStatueObj, "DustParticles")
            local chainsObj = GameObject.FindInChildren(currentStatueObj, "ChainParticles")
            local audioObj = GameObject.FindInChildren(currentStatueObj, "StatueSource")

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
                if chainSFX then chainSFX:SelectPlayAudioEvent("SFX_ChainBreak") end
            end
        end
    end

    if pendingMaterialUpdate and cinTimer >= self.public.cinematicMidPoint then
        UpdatePortalVisuals(self)
        pendingMaterialUpdate = false
    end

    if cinTimer >= self.public.cinematicEndTime then
        inCinematic = false
        if _G.PlayerInstance then _G.PlayerInstance.public.canMove = true end
    end
end