public = {
    brokenPrefabName = "",
    meshObjName = "",
    nearX = 5.0,
    nearY = 5.0,
    nearZ = 5.0,
    dropChance = 0.0,
    dropPrefabName = "HealingPotion",
    cleanUpTime = 5.0,
}

local broken = false
local hidden = false

local brokenPrefab = nil
local dropPrefab = nil
local brokenPrefabPath = ""
local dropPrefabPath = ""
local audioSource = nil
local aliveTimer = 0

local myPos 
local myRot 
local myScale

local destroyQueue = {}
local destroyCooldown = 0
local DESTROY_INTERVAL = 0.05


local function BreakObject(self)
        
    if brokenPrefabPath then 
        brokenPrefab = Prefab.Instantiate(brokenPrefabPath)

        local rand = math.random(0,100)

        if rand <= self.public.dropChance then 
            Engine.Log("[BreakObject] Random num was "..tostring(rand).." out of "..tostring(self.public.dropChance)..", dropping item...")
            if dropPrefabPath then
                dropPrefab = Prefab.Instantiate(dropPrefabPath)
            end
        else
            Engine.Log("[BreakObject] Random num was "..tostring(rand).." out of "..tostring(self.public.dropChance)..", no drop")
        end

        if audioSource then audioSource:PlayAudioEvent() end

        myPos = self.transform.worldPosition
        myRot = self.transform.rotation
        myScale = self.transform.scale

        if not brokenPrefab then
            --Engine.Log("Unable to load prefab from "..tostring(prefabPath))   
        end
    end
end

local function HideWholeModel(self)
    local meshObj = GameObject.FindInChildren(self.gameObject, tostring(self.public.meshObjName))
    if meshObj and meshObj:IsActive() then 
        meshObj:SetActive(false)
        local collider = self.gameObject:GetComponent("Box Collider")
        if collider then collider:Disable() end
        hidden = true 
    else
        --Engine.Log("Unable to find meshObj")
    end
end

local function Initialize(self)
    brokenPrefabPath = "Prefabs/" ..tostring(self.public.brokenPrefabName)..".prefab"
    dropPrefabPath = "Prefabs/" ..tostring(self.public.dropPrefabName)..".prefab"
    audioSource = self.gameObject:GetComponent("Audio Source")
    broken = false
end

function Start(self)
    Initialize(self)
end


function Update(self, dt)

    -- Process destroy queue
    if #destroyQueue > 0 then
        destroyCooldown = destroyCooldown - dt
        if destroyCooldown <= 0 then
            local go = table.remove(destroyQueue, 1)
            if go then GameObject.Destroy(go) end
            destroyCooldown = DESTROY_INTERVAL
        end
    end

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
        if brokenPrefab.transform then 
            brokenPrefab.transform:SetPosition(myPos.x, myPos.y, myPos.z)
            brokenPrefab.transform:SetRotation(myRot.x, myRot.y, myRot.z)
            brokenPrefab.transform:SetScale(myScale.x, myScale.y, myScale.z)

            if dropPrefab then
                if dropPrefab.transform then
                    dropPrefab.transform:SetPosition(myPos.x, myPos.y + 2.0, myPos.z)
                    dropPrefab.transform:SetRotation(myRot.x, myRot.y, myRot.z)
                end
            end

            if not hidden then HideWholeModel(self) end
        end
    end

    if broken then 
        aliveTimer = aliveTimer + dt

        if aliveTimer >= self.public.cleanUpTime then
            aliveTimer = 0
            if brokenPrefab then table.insert(destroyQueue, brokenPrefab) end
            if dropPrefab then table.insert(destroyQueue, dropPrefab) end
            brokenPrefab = nil
            dropPrefab = nil
            self.gameObject:SetActive(false)
        end
    end
end

function OnCollisionEnter(self, other)
    if other:CompareTag("Enemy") and not broken then 
        BreakObject(self)
        broken = true
    end
end