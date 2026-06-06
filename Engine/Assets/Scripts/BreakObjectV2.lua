--BreakObjectV2 Script (Instantiates Prefab)


public = {
    brokenPrefabName = "",
    meshObjName = "",
    breakOnTouch = false,
    nearX = 5.0,
    nearY = 5.0,
    nearZ = 5.0,
    --audioEvent = ""
    dropsPotion = false,
    cleanUpTime = 5.0,
}

local broken = false
--local hidden = false

local brokenPrefab = nil
local prefabPath = ""
local audioSource = nil
local aliveTimer = 0

local myPos 
local myRot 
local myScale 


local function BreakObject(self)
        
    if prefabPath then 
        --brokenPrefab:SetActive(true)
        brokenPrefab = Prefab.Instantiate(prefabPath)

         
        if audioSource then audioSource:PlayAudioEvent() end
        
        

        myPos = self.transform.worldPosition
        myRot = self.transform.rotation
        myScale = self.transform.scale

        if not brokenPrefab then
            Engine.Log("Unable to load prefab from "..tostring(prefabPath))   
        end

    end
end

local function HideWholeModel(self)

    local meshObj = GameObject.FindInChildren(self.gameObject, tostring(self.public.meshObjName))
    if meshObj then 
        meshObj:SetActive(false)
        --hidden = true 
        Engine.Log("meshObj deactivated!")
    else
        --Engine.Log("Unable to find meshObj")
    end

    local collider = self.gameObject:GetComponent("Box Collider")

    if collider then collider:Disable() end

    

    --instantiated = true

end

local function Initialize(self)
    
    prefabPath = "Prefabs/" ..tostring(self.public.brokenPrefabName)..".prefab"
    --Engine.Log("[BreakObject] Prefab Path = "..tostring(prefabPath))
    
    --if brokenPrefab then brokenPrefab:SetActive(false) end
    audioSource = self.gameObject:GetComponent("Audio Source")



    

    broken = false
    --instantiated = false
    
end

function Start(self)
    Initialize(self)

end


function Update(self, dt)

    
    if not self.public.breakOnTouch and not broken then
        local playerObj = GameObject.Find("Player")
        local playerPos = playerObj.transform.worldPosition
        local vasePos = self.transform.worldPosition
        local attack = _PlayerController_lastAttack

        if (attack == "light" or attack == "heavy" or attack == "charge") and not _G._PlayerController_isDead and not broken then
            if (math.abs(playerPos.x - vasePos.x) <= self.public.nearX) then
                if (math.abs(playerPos.y - vasePos.y) <= self.public.nearY) then
                    if (math.abs(playerPos.z - vasePos.z) <= self.public.nearZ) then
                        BreakObject(self)
                        broken = true
                        
                        
                    end
                end  
            end     
        end
        
    end

    if brokenPrefab then 
        brokenPrefab.transform:SetPosition(myPos.x, myPos.y, myPos.z)
        brokenPrefab.transform:SetRotation(myRot.x, myRot.y, myRot.z)
        brokenPrefab.transform:SetScale(myScale.x, myScale.y, myScale.z)

        HideWholeModel(self)
        
    end

    if broken then 
        aliveTimer = aliveTimer + dt

        if aliveTimer >= self.public.cleanUpTime then
            aliveTimer = 0
            GameObject.Destroy(brokenPrefab)
            --GameObject.Destroy(self.gameObject)
            
        end
    end
end

function OnCollisionEnter(self, other)
    if other:CompareTag("Player") and not broken and self.public.breakOnTouch then 
        Engine.Log("[BreakObject] Collided with player")
        BreakObject(self)
        broken = true
    end
end






