local initCombat = false
local endCombat = false
public = {
    doorsTag = "Door_Combat_1",
    enemiesTag = "Enemy_Combat_1"
}
local doors = nil
local enemies = nil

function Start(self)
    doors = GameObject.FindByTag(self.public.doorsTag)
    enemies = GameObject.FindByTag(self.public.enemiesTag)
end

function Update (self, deltaTime) 
    if initCombat and not endCombat then
        Engine.Log("loooooooooooooooooooooooooooooook")
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