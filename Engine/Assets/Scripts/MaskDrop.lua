-- Mask Drop Script 

local maskAnimDuration = 34.0


-- local statueAnim = nil
-- local statueMesh = nil
-- local statueMat  = nil
--local activatedStatue = false
--local maskAnimTimer = 0

public = {
    near = 8.0,
    DropApoloMask  = false,
    DropHermesMask = false,
    DropAresMask   = false
}

local function FindStoneMasks(self)
    local stoneApoloMask  = GameObject.FindInChildren(self.gameObject, "stoneApoloMask")
    local stoneHermesMask = GameObject.FindInChildren(self.gameObject, "stoneHermesMask")
    local stoneAresMask   = GameObject.FindInChildren(self.gameObject, "stoneAresMask")

    if self.public.DropApoloMask then
        if stoneApoloMask  then stoneApoloMask:SetActive(true)   end
        if stoneAresMask   then stoneAresMask:SetActive(false)   end
        if stoneHermesMask then stoneHermesMask:SetActive(false) end
        self.stoneMask = stoneApoloMask
    elseif self.public.DropHermesMask then
        if stoneApoloMask  then stoneApoloMask:SetActive(false)  end
        if stoneAresMask   then stoneAresMask:SetActive(false)   end
        if stoneHermesMask then stoneHermesMask:SetActive(true)  end
        self.stoneMask = stoneHermesMask
    elseif self.public.DropAresMask then
        if stoneApoloMask  then stoneApoloMask:SetActive(false)  end
        if stoneAresMask   then stoneAresMask:SetActive(true)    end
        if stoneHermesMask then stoneHermesMask:SetActive(false) end
        self.stoneMask = stoneAresMask
    end
end

local function FindStatueInteractPrompt(self)
    self.interactive = GameObject.FindInChildren(self.gameObject, "Interactive")
    if not self.interactive then 
        Engine.Log("[MASKDROP] Unable to retrieve Interactive Prompt GameObject")
    else 
        self.interactive:SetActive(true) 
    end
end

local function FindStatueAudioSource(self)

    self.statueSource = GameObject.FindInChildren(self.gameObject, "StatueSource")
    if self.statueSource then 
        self.statueSFX = self.statueSource:GetComponent("Audio Source")
        if not self.statueSFX then 
            Engine.Log("[MASKDROP] Unable to retrieve Audio Source Component from Bust Statue")
        end

    else
        Engine.Log("[MASKDROP] Unable to find Audio GameObject from Bust Statue")
    end
end

function Initialize(self)
    self.statueMesh = GameObject.FindInChildren(self.gameObject, "mesh")
    if self.statueMesh then 
        self.statueMat = self.statueMesh:GetComponent("Material")
        if self.statueMat then 
            self.statueMat.SetTexture("10286171976575561541")
        else
            Engine.Log("[MASKDROP] Material Component not found on Bust Statue, unable to set asleep texture!")
        end

    end

    self.dustVFX = GameObject.FindInChildren(self.gameObject, "DustParticles")
    if not self.dustVFX then Engine.Log("[MASKDROP] Unable to find dustVFX GameObject")
    else
        self.dustPs = self.dustVFX:GetComponent("ParticleSystem")
        if not self.dustPs then 
            Engine.Log("Unable to retrieve dust Particle System Component")
        end
    end

    self.statueAnim = self.gameObject:GetComponent("Animation") 
    

    FindStatueAudioSource(self)
    FindStatueInteractPrompt(self)
    FindStoneMasks(self)
    maskAnimDuration = 34.0
    self.activatedStatue = false
    self.removedStoneMask = false
    self.maskAnimTimer = 0   
    self.stopAnimTimer = 0
end



function Start(self)
    Initialize(self)
end

function Update(self, dt)


    if not self.stoneMask then
        FindStoneMasks(self)
    end

    if not self.statueSFX then 
        FindStatueAudioSource(self)
    end

    if not self.interactive then
        FindStatueInteractPrompt(self)
    end

    if interact == true and not self.activatedStatue then
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position
        local pos = self.transform.worldPosition
        if math.abs(pos.x - playerPos.x) < self.public.near and
           math.abs(pos.z - playerPos.z) < self.public.near then

            Engine.Log("[MASKDROP] Interacted with bust statue")
            if self.public.DropApoloMask  then giveApoloMask  = true end
            if self.public.DropHermesMask then giveHermesMask = true end
            if self.public.DropAresMask   then giveAresMask   = true end

            --local statueAnim = self.gameObject:GetComponent("Animation") 
            if self.statueAnim then self.statueAnim:Play("Activate", 0.15) end

            self.activatedStatue = true
            self.removedStoneMask = false
            self.maskAnimTimer = 0
            if self.statueSFX then self.statueSFX:PlayAudioEvent() end
                
            if self.interactive then GameObject.Destroy(self.interactive) end
            

            --local statueMesh = GameObject.FindInChildren(self.gameObject, "mesh")
            if self.statueMesh then 
                --local statueMat = self.statueMesh:GetComponent("Material")
                if self.statueMat then 
                    self.statueMat.SetTexture("16679556794755767834")
                    if self.dustPs then self.dustPs:Play() end
                else
                    Engine.Log("[MASKDROP] Material Component not found on Bust Statue, unable to set awoken texture!")
                end

            end
            
            
        end
    end

    if self.activatedStatue then

        --Engine.Log("Activated Statue")
        self.maskAnimTimer = self.maskAnimTimer + dt
        if self.maskAnimTimer >= 15.0 and not self.removedStoneMask then
            if self.stoneMask then self.stoneMask:SetActive(false)
            else Engine.Log("[MASKDROP] Stone Mask not found, unable to remove from statue")
            end
            self.removedStoneMask = true
        end

        if self.maskAnimTimer >= 30.0 then
            self.statueAnim:SetLooping("Activate", false)
            if self.statueSFX then self.statueSFX:StopAudioEvent() end
        end

        if self.maskAnimTimer >= maskAnimDuration then

            --won't reset bc the animation should only play once (you only get the mask once obv)
            --self.activatedStatue = false
            self.maskAnimTimer = 0

            if self.statueMesh then 
                if self.statueMat then 
                    self.statueMat.SetTexture("10286171976575561541")
                    if self.dustPs then self.dustPs:Play() end
                    
                else
                    Engine.Log("[MASKDROP] Material Component not found on Bust Statue, unable to set asleep texture!")
                end
            end
        end
    end
end
