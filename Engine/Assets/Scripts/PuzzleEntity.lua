-- PuzzleEntity.lua
public = {
    managerName = "Manager_Sala_1",
    entityType = "Rock",  -- "Rock" o "Statue"
    gridR = 2,            
    gridC = 2,            
    moveSpeed = 8.0,
    hitDistance = 3.5     -- Distancia a la que detecta el golpe de la espada del Player, está en 3.5 para probar pero habrá que ajustarlo más adelante
}

local managerScript = nil
local isMoving = false
local isRotating = false
local targetX = 0.0
local targetZ = 0.0
local currentYaw = 0.0
local targetYaw = 0.0
local setupDone = false
local playerAttackHandled = false
local rockSFX = nil

function Start(self)
    local rot = self.transform.rotation
    currentYaw = rot.y
    targetYaw = rot.y
    --audio
    rockSFX = self.gameObject:GetComponent("Audio Source")
    if not rockSFX then 
        Engine.Log("[PUZZLE ENTITY] Could not retrieve Movable Rock Audio Source")
    else
        Engine.Log("[PUZZLE ENTITY] Rock Audio Source found!")
    end

end

-- Esta función hace la lógica del impacto con la Entity, se llama por Trigger o Distancia porque no detecta según como, pdte de mejorar la llamada
local function ProcessHit(self, attackType, playerObj)
    if isMoving or isRotating then return end
    
    Engine.Log("[PuzzleEntity] IMPACTO Tipo: " .. attackType .. " en " .. self.public.entityType)
    
    local isHeavy = (attackType == "heavy" or attackType == "charge")
    local isLight = (attackType == "light")

    -- Statue LightAttack Rotation
    -- HAOSHENG LI PERDOOOOOOOOOOOOOOOOOOOOOOON
    if self.public.entityType == "Statue" and isLight then
        --targetYaw = currentYaw + 90.0
        --isRotating = true
        --_G._PlayerController_lastAttack = ""
        --Engine.Log("[PuzzleEntity] Statue Rotating.")
        return
    end

    -- Rock LightAttack Nonchalant
    if self.public.entityType == "Rock" and isLight then
        Engine.Log("[PuzzleEntity] LightAttack on rock, not affected.")
        return
    end

    -- HeavyAttack
    if isHeavy then
        local playerPos = playerObj.transform.position
        local myPos = self.transform.position
        
        local dx = myPos.x - playerPos.x
        local dz = myPos.z - playerPos.z
        
        local dR, dC = 0, 0
        
        -- Push
        if math.abs(dx) > math.abs(dz) then
            dC = (dx > 0) and 1 or -1
        else
            dR = (dz > 0) and 1 or -1
        end

        Engine.Log("[PuzzleEntity] Moving: dR=" .. dR .. ", dC=" .. dC)
        -- Check if theres any object blocking the movement
        if managerScript and managerScript.RequestMove then
            local canMove, wX, wZ = managerScript:RequestMove(self.public.gridR, self.public.gridC, dR, dC)
            if canMove then
                targetX = wX
                targetZ = wZ
                self.public.gridR = self.public.gridR + dR
                self.public.gridC = self.public.gridC + dC
                isMoving = true
                Engine.Log("[PuzzleEntity] Movement is possible, no object in the way.")
            end
        end
        
        _G._PlayerController_lastAttack = ""
    end
end

function Update(self, dt)
    if not setupDone then
        local managerObj = GameObject.Find(self.public.managerName)
        if managerObj then
            managerScript = managerObj:GetComponent("Script")
            if managerScript and managerScript.IsReady and managerScript:IsReady() then
                local registered = managerScript:RegisterEntity(self.public.gridR, self.public.gridC)
                if registered then
                    local wX = managerScript.public.originX + ((self.public.gridC - 1) * managerScript.public.cellSize)
                    local wZ = managerScript.public.originZ + ((self.public.gridR - 1) * managerScript.public.cellSize)
                    self.transform:SetPosition(wX, self.transform.position.y, wZ)
                    setupDone = true
                end
            end
        end
        return
    end

    -- Distance detection, in case trigger failed, same code as Enemy script
    local currentAttack = _G._PlayerController_lastAttack
    if currentAttack and currentAttack ~= "" then
        if not playerAttackHandled then
            local player = GameObject.Find("Player")
            if player then
                local dx = self.transform.position.x - player.transform.position.x
                local dz = self.transform.position.z - player.transform.position.z
                local dist = math.sqrt(dx*dx + dz*dz)
                
                if dist <= self.public.hitDistance then
                    playerAttackHandled = true
                    ProcessHit(self, currentAttack, player)
                    if rockSFX then rockSFX:PlayAudioEvent() end
                end
            end
        end
    else
        playerAttackHandled = false
    end

    -- Movement
    if isMoving then
        local pos = self.transform.position
        local newX = pos.x + (targetX - pos.x) * self.public.moveSpeed * dt
        local newZ = pos.z + (targetZ - pos.z) * self.public.moveSpeed * dt
        
        self.transform:SetPosition(newX, pos.y, newZ)
        
        if math.abs(targetX - pos.x) < 0.05 and math.abs(targetZ - pos.z) < 0.05 then
            self.transform:SetPosition(targetX, pos.y, targetZ)
            isMoving = false
        end
    end

    -- Rotation
    if isRotating then
        currentYaw = currentYaw + (targetYaw - currentYaw) * self.public.moveSpeed * dt
        self.transform:SetRotation(0, currentYaw, 0)
        
        if math.abs(targetYaw - currentYaw) < 1.0 then
            self.transform:SetRotation(0, targetYaw, 0)
            currentYaw = targetYaw
            isRotating = false
        end
    end
end

-- OnTriggerEnter for Rigidbody in rocks, no quitar de momento
function OnTriggerEnter(self, other)
    if not setupDone then return end
    if other:CompareTag("Player") then
        local attackType = _G._PlayerController_lastAttack
        if attackType and attackType ~= "" and not playerAttackHandled then
            playerAttackHandled = true
            ProcessHit(self, attackType, other)
        end
    end
end