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

    self.statueAnim = self.gameObject:GetComponent("Animation") 

    FindStoneMasks(self)
    maskAnimDuration = 34.0

    self.activatedStatue = false
    self.maskAnimTimer = 0   
end



function Start(self)
    Initialize(self)
end

function Update(self, dt)


    if not stoneMask then
        FindStoneMasks(self)
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
            self.maskAnimTimer = 0

            --local statueMesh = GameObject.FindInChildren(self.gameObject, "mesh")
            if self.statueMesh then 
                --local statueMat = self.statueMesh:GetComponent("Material")
                if self.statueMat then 
                    self.statueMat.SetTexture("16679556794755767834")
                else
                    Engine.Log("[MASKDROP] Material Component not found on Bust Statue, unable to set awoken texture!")
                end

            end
                
            
        end
    end

    if self.activatedStatue then
        Engine.Log("Activated Statue")
        self.maskAnimTimer = self.maskAnimTimer + dt

        if self.maskAnimTimer <= 20.0 and self.maskAnimTimer >= 21.0 then
            if stoneMask then stoneMask:SetActive(false) end
            if not stoneMask then Engine.Log("[MASKDROP] Couldn't find stoneMask") end
        end

        if self.maskAnimTimer >= maskAnimDuration then
            if self.statueAnim then self.statueAnim:Stop() end
            
            --won't reset the statue since the animation should only play once (the first and only time you get the mask)
            --self.activatedStatue = false
            --self.maskAnimTimer = 0

            
            if self.statueMesh then 
                if self.statueMat then 
                    self.statueMat.SetTexture("10286171976575561541")
                else
                    Engine.Log("[MASKDROP] Material Component not found on Bust Statue, unable to set asleep texture!")
                end

            end
        end
    end
end
