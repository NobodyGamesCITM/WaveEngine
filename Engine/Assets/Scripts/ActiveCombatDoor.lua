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

    self.startCombat = function(self)
        if not initCombat then 
            initCombat = true 
            reviveEnemies = true
        end
        return initCombat
    end
end

function Update (self, deltaTime) 
    if init then 
        for i, enemy in ipairs(enemies) do
            if enemy then
                local enemyScript = enemy:GetComponent("Script")
                enemyScript.SetDead()
            end
        end
        init =  false
    end
    if initCombat and reviveEnemies then
        for i, enemy in ipairs(enemies) do
            if enemy then
                local enemyScript = enemy:GetComponent("Script")
                enemyScript.SetAlive()
            end
        end
        for i, door in ipairs(doors) do
            if door then
                local doorScript = door:GetComponent("Script")
                if doorScript and not doorScript.isClose then
                    doorScript:CloseDoor()
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
                if enemyScript.CheckAlive() then deads = deads + 1 end
                numEnim = numEnim + 1
            end
        end
        if deads == numEnim then 
            for i, door in ipairs(doors) do
                if door then
                    local doorScript = door:GetComponent("Script")
                    if doorScript then
                        doorScript:OpenDoor()
                    end
                end
            end
            endCombat = true         
        end 
    end    
end
function OnTriggerEnter(self, other)
    if aresCombat then return end
    if not initCombat then
        for i, door in ipairs(doors) do
            if door then
                local doorScript = door:GetComponent("Script")
                if doorScript and not doorScript.isClose then
                    doorScript:CloseDoor()
                end
            end
        end
        initCombat = true
    end
end

--function OnTriggerExit(self, other)
--end