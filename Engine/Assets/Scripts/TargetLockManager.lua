-- TargetLockManager.lua

public = {
    maxLockDistance = 30.0,
    tagsToLock = {"Enemy", "Enemy_Combat_1", "Enemy_Combat_Ares", "Lockable"},
    particleYOffset = 1.0,
    baseParticleSize = 3.5
}

local player = nil
local cineCam = nil
local currentTarget = nil
local isLocked = false
local lockParticleObj = nil

local switchCooldown = 0.0
local SWITCH_DELAY = 0.3 

_G.TargetLockManager_IsLocked = false
_G.TargetLockManager_CurrentTarget = nil

local ClearLockInternal 

function Start(self)
    player = GameObject.Find("Player")
    local camObj = GameObject.Find("MainCamera")
    if camObj then cineCam = camObj:GetComponent("CinematicCamera") end
    
    lockParticleObj = GameObject.Find("LockOnParticle")
    if lockParticleObj then
        local ps = lockParticleObj:GetComponent("ParticleSystem")
        if ps then ps:Stop() end
    end

    _G.TargetLockManager_ClearLock = function()
        ClearLockInternal(self)
    end

    _G.TargetLockManager_SetParticleVisibility = function(visible)
        if lockParticleObj then
            if visible and isLocked then
                lockParticleObj:SetActive(true)
            else
                lockParticleObj:SetActive(false)
            end
        end
    end
end

local function IsTargetDead(target)
    if not target then return true end
    if target.transform == nil or not target:IsActive() then return true end
    
    local script = target:GetComponent("Script")
    if script then
        if script.CheckAlive then return script:CheckAlive() end
        if script.isDead ~= nil then return script.isDead end
        if script.hp ~= nil then return script.hp <= 0 end
    end
    return false
end
_G.IsTargetDead = IsTargetDead

local function FindBestTarget(self)
    local bestTarget = nil
    local minSqrDist = self.public.maxLockDistance * self.public.maxLockDistance
    if not player then return nil end
    local playerPos = player.transform.worldPosition

    for _, tag in ipairs(self.public.tagsToLock) do
        local candidates = GameObject.FindByTag(tag)
        if candidates then
            for _, candidate in ipairs(candidates) do
                if not IsTargetDead(candidate) then
                    local cPos = candidate.transform.worldPosition
                    local dx = cPos.x - playerPos.x
                    local dy = cPos.y - playerPos.y
                    local dz = cPos.z - playerPos.z
                    
                    if math.abs(dy) <= 15.0 then
                        local sqrDist = (dx*dx) + (dy*dy) + (dz*dz)

                        if sqrDist < minSqrDist then
                            minSqrDist = sqrDist
                            bestTarget = candidate
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function UpdateParticle(self, target)
    if not lockParticleObj or not target then return end
    
    local tPos = target.transform.worldPosition
    lockParticleObj.transform:SetPosition(tPos.x, tPos.y + self.public.particleYOffset, tPos.z)
    
    local finalSize = self.public.baseParticleSize
    local script = target:GetComponent("Script")
    if script and script.public and script.public.lockOnSize then
        finalSize = script.public.lockOnSize
    end
    
    lockParticleObj:SetActive(true)
    local ps = lockParticleObj:GetComponent("ParticleSystem")
    if ps then
        if ps.SetSize then ps:SetSize(finalSize) end
        if not ps:IsPlaying() then ps:Play() end
    end
end

local function SwitchTarget(self, directionStr)
    if not currentTarget then return end
    local camObj = GameObject.Find("MainCamera")
    if not camObj then return end

    local camRight = camObj.transform.worldRight
    local camFwd = camObj.transform.worldForward
    camFwd.y = 0
    local lenFwd = math.sqrt(camFwd.x^2 + camFwd.z^2)
    if lenFwd > 0.001 then 
        camFwd.x = camFwd.x / lenFwd; camFwd.z = camFwd.z / lenFwd 
    end

    local refDir = {x=0, z=0}
    if directionStr == "Right" then refDir = {x = camRight.x, z = camRight.z}
    elseif directionStr == "Left" then refDir = {x = -camRight.x, z = -camRight.z}
    elseif directionStr == "Up" then refDir = {x = camFwd.x, z = camFwd.z}
    elseif directionStr == "Down" then refDir = {x = -camFwd.x, z = -camFwd.z}
    end

    local playerPos = player.transform.worldPosition
    local currentPos = currentTarget.transform.worldPosition

    local bestTarget = nil
    local bestScore = 999999 

    for _, tag in ipairs(self.public.tagsToLock) do
        local candidates = GameObject.FindByTag(tag)
        if candidates then
            for _, candidate in ipairs(candidates) do
                if candidate ~= currentTarget and not IsTargetDead(candidate) then
                    local cPos = candidate.transform.worldPosition
                    local dx = cPos.x - playerPos.x
                    local dy = cPos.y - playerPos.y
                    local dz = cPos.z - playerPos.z
                    
                    if math.abs(dy) <= 15.0 then
                        local sqrDist = (dx*dx) + (dy*dy) + (dz*dz)

                        if sqrDist < (self.public.maxLockDistance * self.public.maxLockDistance) then
                            local dirToCandX = cPos.x - currentPos.x
                            local dirToCandZ = cPos.z - currentPos.z
                            local lenDir = math.sqrt(dirToCandX^2 + dirToCandZ^2)
                            if lenDir > 0.001 then
                                dirToCandX = dirToCandX / lenDir
                                dirToCandZ = dirToCandZ / lenDir
                                local dot = (dirToCandX * refDir.x) + (dirToCandZ * refDir.z)
                                if dot > 0.4 then
                                    local score = sqrDist - (dot * 50.0)
                                    if score < bestScore then
                                        bestScore = score
                                        bestTarget = candidate
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestTarget then
        cineCam:RemoveTarget(currentTarget)
        currentTarget = bestTarget
        cineCam:AddTarget(currentTarget, 1.0)
        _G.TargetLockManager_CurrentTarget = currentTarget
        UpdateParticle(self, currentTarget)
    end
end

ClearLockInternal = function(self)
    if not isLocked then return end
    isLocked = false
    currentTarget = nil
    _G.TargetLockManager_IsLocked = false
    _G.TargetLockManager_CurrentTarget = nil

    if cineCam then
        cineCam:ClearTargets()
        cineCam:AddTarget(player, 1.0)
        if cineCam.SetCombatLock then cineCam:SetCombatLock(false) end
    end

    if lockParticleObj then
        local ps = lockParticleObj:GetComponent("ParticleSystem")
        if ps then
            ps:Stop()
            ps:Reset()
        end
        lockParticleObj:SetActive(false)
    end
end

local function EngageLock(self)
    local target = FindBestTarget(self)
    if target then
        isLocked = true
        currentTarget = target
        _G.TargetLockManager_IsLocked = true
        _G.TargetLockManager_CurrentTarget = currentTarget

        if cineCam then
            cineCam:ClearTargets()
            cineCam:AddTarget(player, 1.0)
            cineCam:AddTarget(currentTarget, 1.0)
            if cineCam.SetCombatLock then cineCam:SetCombatLock(true) end
        end

        UpdateParticle(self, currentTarget)
    end
end

function Update(self, dt)
    if _G.CinematicActive then 
        if lockParticleObj then lockParticleObj:SetActive(false) end
        return 
    end

    if not player or not cineCam then return end

    if switchCooldown > 0 then switchCooldown = switchCooldown - dt end

    if Input.GetKeyDown("R") or Input.GetGamepadButtonDown("RightStick") then
        if isLocked then
            ClearLockInternal(self)
        else
            EngageLock(self)
        end
    end

    if isLocked and currentTarget then
        if IsTargetDead(currentTarget) then
            ClearLockInternal(self)
            return
        end

        local pPos = player.transform.worldPosition
        local cPos = currentTarget.transform.worldPosition
        local dy = cPos.y - pPos.y
        local sqrDist = ((cPos.x - pPos.x)^2) + (dy^2) + ((cPos.z - pPos.z)^2)
        
        if sqrDist > (self.public.maxLockDistance * self.public.maxLockDistance) or math.abs(dy) > 15.0 then
            ClearLockInternal(self)
            return
        end

        if switchCooldown <= 0 then
            local rsX, rsY = 0, 0
            if Input.HasGamepad() then rsX, rsY = Input.GetRightStick() end
            if Input.GetKeyDown("Right") then rsX = 1 end
            if Input.GetKeyDown("Left") then rsX = -1 end
            if Input.GetKeyDown("Up") then rsY = 1 end
            if Input.GetKeyDown("Down") then rsY = -1 end

            if math.abs(rsX) > 0.6 or math.abs(rsY) > 0.6 then
                if math.abs(rsX) > math.abs(rsY) then
                    SwitchTarget(self, rsX > 0 and "Right" or "Left")
                else
                    SwitchTarget(self, rsY > 0 and "Up" or "Down")
                end
                switchCooldown = SWITCH_DELAY
            end
        end
        UpdateParticle(self, currentTarget)
    end
end