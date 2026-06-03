--BreakObjectV2 Script (Instantiates Prefab)


public = {
    brokenPrefabName = "",
    meshObjName = "",
    --brokenObjName = "",
}

local broken = false

local brokenPrefab = nil
local prefabPath = ""

local myPos 
local myRot 
local myScale 


local function BreakObject(self)
        
    if prefabPath then 
        --brokenPrefab:SetActive(true)
        brokenPrefab = Prefab.Instantiate(prefabPath)
        

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
        Engine.Log("meshObj deactivated!")
    else
        Engine.Log("Unable to find meshObj")
    end

    local collider = self.gameObject:GetComponent("Box Collider")

    if collider then collider:Disable() end

end

local function Initialize(self)
    
    prefabPath = "Prefabs/" ..tostring(self.public.brokenPrefabName)..".prefab"
    --Engine.Log("[BreakObject] Prefab Path = "..tostring(prefabPath))
    
    --if brokenPrefab then brokenPrefab:SetActive(false) end

    broken = false
    instantiated = false
    
end

function Start(self)
    Initialize(self)

end


function Update(self, dt)

    if brokenPrefab then 
        brokenPrefab.transform:SetPosition(myPos.x, myPos.y, myPos.z)
        --brokenPrefab.transform:SetRotation(myRot.x, myRot.y, myRot.z)
        brokenPrefab.transform:SetScale(myScale.x, myScale.y, myScale.z)

        HideWholeModel(self)
        
    end
end

function OnCollisionEnter(self, other)
    if other:CompareTag("Player") and not broken then 
        Engine.Log("[BreakObject] Collided with player")
        BreakObject(self)
        broken = true
    end
end






