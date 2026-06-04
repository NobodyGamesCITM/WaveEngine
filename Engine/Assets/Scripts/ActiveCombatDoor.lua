-- ActiveCombatDoor.lua
public = {
    doorsTag = "Door_Combat_1",
    enemiesTag = "Enemy_Combat_1",
    aresCombat = false
}
local doors = nil
local enemies = nil
local init = true

local initCombat = false
local endCombat = false
local reviveEnemies = false

function Start(self)
    doors = GameObject.FindByTag(self.public.doorsTag)
    enemies = GameObject.FindByTag(self.public.enemiesTag)

    self.combatName = self.gameObject.name
    if _G.CombatStates and _G.CombatStates[self.combatName] then
        endCombat = true
        initCombat = true
        init = false
        
        for i, door in ipairs(doors) do
            if door then
                local doorScript = door:GetComponent("Script")
                if doorScript and doorScript.ForceOpen then
                    doorScript:ForceOpen()
                end
            end
        end
    end

    self.startCombat = function(self)
        if not initCombat and not endCombat then 
            initCombat = true 
            reviveEnemies = true
        end
        return initCombat
    end
end

function Update (self, deltaTime) 
    if init and self.public.aresCombat then 
        for i, enemy in ipairs(enemies) do
            if enemy then
                local enemyScript = enemy:GetComponent("Script")
                if enemyScript and enemyScript.SetDead then enemyScript:SetDead() end
            end
        end
        init = false
    end

    if endCombat then return end 

    if initCombat and reviveEnemies then
        for i, enemy in ipairs(enemies) do
            if enemy then
                local enemyScript = enemy:GetComponent("Script")
                if enemyScript and enemyScript.SetAlive then enemyScript:SetAlive() end
            end
        end
        for i, door in ipairs(doors) do
            if door then
                local doorScript = door:GetComponent("Script")
                if doorScript and not doorScript.isClose then
                    if doorScript.CloseDoor then doorScript:CloseDoor() end
                end
            end
        end
        reviveEnemies = false
    end

    if initCombat and not endCombat and not reviveEnemies then
        local deads = 0
        local numEnim = 0
        for i, enemy in ipairs(enemies) do
            if enemy then
                local enemyScript = enemy:GetComponent("Script")
                if enemyScript then
                    local isDead = false
                    if enemyScript.CheckAlive then isDead = enemyScript:CheckAlive()
                    elseif enemyScript.isDead ~= nil then isDead = enemyScript.isDead end
                    
                    if isDead then deads = deads + 1 end
                end
                numEnim = numEnim + 1
            end
        end
        
        if numEnim > 0 and deads == numEnim then 
            for i, door in ipairs(doors) do
                if door then
                    local doorScript = door:GetComponent("Script")
                    if doorScript and doorScript.OpenDoor then
                        doorScript:OpenDoor()
                    end
                end
            end
            endCombat = true         
            
            _G.CombatStates = _G.CombatStates or {}
            _G.CombatStates[self.combatName] = true
        end 
        
        local playerHealth = 100
        if _G.PlayerInstance then playerHealth = _G.PlayerInstance.public.health end
        
        if playerHealth <= 0 then
            for i, door in ipairs(doors) do
                if door then
                    local doorScript = door:GetComponent("Script")
                    if doorScript and doorScript.OpenDoor then
                        doorScript:OpenDoor()
                    end
                end
            end
            initCombat = false
            self.public.aresCombat = false
        end   
    end 
end

function OnTriggerEnter(self, other)
    if self.public.aresCombat then return end
    if endCombat then return end 
    
    if not initCombat and other:CompareTag("Player") then
        for i, door in ipairs(doors) do
            if door then
                local doorScript = door:GetComponent("Script")
                if doorScript and not doorScript.isClose then
                    if doorScript.CloseDoor then doorScript:CloseDoor() end
                end
            end
        end
        initCombat = true
        reviveEnemies = true
    end
end