-- KeyStatue Script

public = {
    circleVar = false,
    archVar = false,
    Tvar = false,
    near = 8.0
}


local player = nil

local function FindChains(self)
    self.initialChains = GameObject.FindInChildren(self.gameObject, "chains")
    self.brokenChains = GameObject.FindInChildren(self.gameObject, "broken_chains")

    
    


end

-- local function FindKeyStatueParticles(self)
    
-- end

local function FindKeyStatueMat(self)

    local matOBJ = GameObject.FindInChildren(self.gameObject, "keystatue_export3:statue")
    if matOBJ then 
        self.matComp = matOBJ:GetComponent("Material")
        if not self.matComp then  
            Engine.Log("KeyStatue Material Component NOT found!")
        end
    else 
        Engine.Log("KeyStatue Mesh NOT found")
    end
end

local function Initialize(self)

    FindChains(self)
    --FindKeyStatueParticles(self)
    FindKeyStatueMat(self)
    
    if self.matComp then 
        if self.public.circleVar then self.matComp.SetTexture("16421258064931533007")
        elseif self.public.archVar then self.matComp.SetTexture("5568339780968813093")
        elseif self.public.Tvar then self.matComp.SetTexture("8100552288792398666")
        else self.matComp.SetTexture("16421258064931533007") --fallback to circleVar by default
        end
    end

    if self.initialChains then self.initialChains:SetActive(true) end
    if self.brokenChains then self.brokenChains:SetActive(false) end


    self.unlocked = false
    local obj = GameObject.Find("Player")
    

end


function Start(self)
    Initialize(self)
    
end

function Update(self, dt)


    if Input.GetKeyDown("F") then Engine.Log("Pressed F, player interacted") end
    if Input.GetKeyDown("E") then Engine.Log("Pressed E, player attacked") end
 
    if not self.initalChains or not self.brokenChains then 
        FindChains(self)
    end

    if not self.matComp then FindKeyStatueMat(self) end

    if not player then 
        player = GameObject.Find("Player")
    else
        local playerPos = player.transform.position
        local statuePos = self.transform.worldPosition

        if math.abs(statuePos.x - playerPos.x) < self.public.near and
            math.abs(statuePos.z - playerPos.z) < self.public.near then 

            Engine.Log("Player in KeyStatue interact range")

            if Input.GetKeyDown("E") and self.unlocked == false then
                
                
                if self.brokenChains then self.brokenChains:SetActive(true) end
                if self.initialChains then self.initialChains:SetActive(false) end
                self.unlocked = true

                Engine.Log("Unlocked KeyStatue")
                
            end
        end
    end
        
    
end


