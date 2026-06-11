local maskAnimDuration = 34.0

public = {
    near           = 8.0,
    DropApoloMask  = false,
    DropHermesMask = false,
    DropAresMask   = false,
    updateWhenPaused = true,
}

local function FindStoneMasks(self)
    local stoneApolo  = GameObject.FindInChildren(self.gameObject, "apolo1")
    local stoneHermes = GameObject.FindInChildren(self.gameObject, "hermes1")
    local stoneAres   = GameObject.FindInChildren(self.gameObject, "ares1")

    if self.public.DropApoloMask then
        if stoneApolo  then stoneApolo:SetActive(true)   end
        if stoneAres   then stoneAres:SetActive(false)   end
        if stoneHermes then stoneHermes:SetActive(false) end
        self.stoneMask = stoneApolo
    elseif self.public.DropHermesMask then
        if stoneApolo  then stoneApolo:SetActive(false)  end
        if stoneAres   then stoneAres:SetActive(false)   end
        if stoneHermes then stoneHermes:SetActive(true)  end
        self.stoneMask = stoneHermes
    elseif self.public.DropAresMask then
        if stoneApolo  then stoneApolo:SetActive(false)  end
        if stoneAres   then stoneAres:SetActive(true)    end
        if stoneHermes then stoneHermes:SetActive(false) end
        self.stoneMask = stoneAres
    end
end

local function FindStatueInteractPrompt(self)
    self.interactive = GameObject.FindInChildren(self.gameObject, "Interactive")
    if self.interactive then self.interactive:SetActive(true) end
end

local function FindStatueAudioSource(self)
    local src = GameObject.FindInChildren(self.gameObject, "StatueSource")
    if src then self.statueSFX = src:GetComponent("Audio Source") end
end

local function FindStatueMeshandMat(self)
    self.statueMesh = GameObject.FindInChildren(self.gameObject, "mesh")
    if self.statueMesh then
        self.statueMat = self.statueMesh:GetComponent("Material")
    end
end

local function FindStatueAnimation(self)
    self.statueAnim = self.gameObject:GetComponent("Animation")
    local maskObj = GameObject.FindInChildren(self.gameObject, "masks")
    if maskObj then self.maskAnim = maskObj:GetComponent("Animation") end
end

local function FindStatueParticles(self)
    self.dustVFX = GameObject.FindInChildren(self.gameObject, "DustParticles")
    if self.dustVFX then self.dustPs = self.dustVFX:GetComponent("ParticleSystem") end
end

local function ActivateStatue(self)
    if self.statueAnim then
        self.statueAnim:SetLooping("Activate", true)
        self.statueAnim:Play("Activate", 0.15)
    end

    self.activatedStatue  = true
    self.removedStoneMask = false
    self.maskAnimTimer    = 0

    if self.statueSFX then self.statueSFX:SelectPlayAudioEvent("SFX_GM_StatueOn") end
    if self.interactive then GameObject.Destroy(self.interactive) end

    if self.statueMat then
        self.statueMat.SetTexture("16679556794755767834")
        if self.dustPs then self.dustPs:Play() end
    end

    if self.public.DropApoloMask  then giveApoloMask  = true end
    if self.public.DropHermesMask then giveHermesMask = true end
    if self.public.DropAresMask   then giveAresMask   = true end

    _G.UnregisterInteractable(self.gameObject)
end
function Initialize(self)
    Engine.RequestResource("16679556794755767834")
    Engine.RequestResource("10286171976575561541")

    FindStatueMeshandMat(self)
    if self.statueMat then self.statueMat.SetTexture("10286171976575561541") end

    FindStatueAnimation(self)
    if self.statueAnim then self.statueAnim:SetLooping("Activate", true) end

    FindStatueParticles(self)
    FindStatueAudioSource(self)
    FindStatueInteractPrompt(self)
    FindStoneMasks(self)

    maskAnimDuration      = 34.0
    self.activatedStatue  = false
    self.removedStoneMask = false
    self.finished         = false
    self.maskAnimTimer    = 0
    self.inRange          = false

    _G._InteractCallbacks = _G._InteractCallbacks or {}
    _G._InteractCallbacks[self.gameObject] = function()
        if not self.activatedStatue then
            ActivateStatue(self)
        end
    end
end

function Start(self)
    Initialize(self)
end

function Update(self, dt)
    -- Re-find en caso de nil (igual que antes)
    if not self.statueMesh or not self.statueMat then FindStatueMeshandMat(self) end
    if not self.statueAnim                       then FindStatueAnimation(self)  end
    if not self.stoneMask                        then FindStoneMasks(self)        end
    if not self.statueSFX                        then FindStatueAudioSource(self) end
    if not self.dustPs                           then FindStatueParticles(self)   end

    if not self.activatedStatue then
        local player = _G.PlayerInstance or GameObject.Find("Player")
        if player then
            local myPos     = self.transform.worldPosition
            local playerPos = player.transform.worldPosition
            local dx = myPos.x - playerPos.x
            local dz = myPos.z - playerPos.z
            local dist = math.sqrt(dx * dx + dz * dz)

            if dist < self.public.near then
                if not self.inRange then
                    self.inRange = true
                    _G.RegisterInteractable(self.gameObject, "maskstatue")
                end
            else
                if self.inRange then
                    self.inRange = false
                    _G.UnregisterInteractable(self.gameObject)
                end
            end
        end
    end
    if self.activatedStatue and not self.finished then
        self.maskAnimTimer = self.maskAnimTimer + dt

        if self.maskAnimTimer >= 8.0 and self.maskAnim
           and not self.maskAnim:IsPlayingAnimation("ActivateMasks") then
            self.maskAnim:Play("ActivateMasks")
        end

        if self.maskAnimTimer >= 14.25 and not self.removedStoneMask then
            if self.stoneMask then self.stoneMask:SetActive(false) end
            self.removedStoneMask = true
        end

        if self.maskAnimTimer >= 30.0 then
            if self.statueAnim then self.statueAnim:SetLooping("Activate", false) end
            if self.statueSFX  then self.statueSFX:StopAudioEvent()               end
        end

        if self.maskAnimTimer >= maskAnimDuration then
            self.maskAnimTimer = 0
            if self.statueMat then
                self.statueMat.SetTexture("10286171976575561541")
                if self.dustPs    then self.dustPs:Play()                               end
                if self.statueSFX then self.statueSFX:SelectPlayAudioEvent("SFX_GM_StatueOff") end
                self.finished = true
            end
        end
    end
end