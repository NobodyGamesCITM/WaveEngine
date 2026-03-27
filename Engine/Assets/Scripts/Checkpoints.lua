public = {
    offsetX = 0,
    offsetY = 0,    
    offsetZ = 0
}

function Start(self)
    pos = self.transform.position
    pos.x = pos.x + offsetX
    pos.y = pos.y + offsetY
    pos.z = pos.z + offsetZ
end

function Update(self, deltaTime)
    local obj = GameObject.Find("Player")
    local playerPos = obj.transform.position

    if interact == true then 
        if (math.abs(pos.x - playerPos.x) < 10) then
            if (math.abs(pos.z - playerPos.z) < 10) then
                Engine.Log("Checkpoint taken")
                lastCheckpoint = pos 
                Engine.Log("Checkpoint" .. tostring(lastCheckpoint))
                giveApoloMask = true
                Restore(self)
            end
        end
    end
end 

function Restore(self)
    --player lifes etc
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        if interact then
            --activate UI
            lastCheckpoint = pos   
            Engine.Log("Checkpoint taken")
            Restore()
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then  
        --desactivate UI
    end
end

