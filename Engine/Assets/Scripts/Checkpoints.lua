public = {
    offsetX = 0.0,
    offsetY = 0.0,    
    offsetZ = 0.0
}

function Start(self)
    checkpoints = GameObject.FindByTag("CheckPoint")
end

function Update(self, deltaTime)
    
    local obj = GameObject.Find("Player")
    local playerPos = obj.transform.position

    if interact == true then 
        for i, checkpoint in ipairs(checkpoints) do
            local pos = checkpoint.transform.position
            if (math.abs(pos.x - playerPos.x) < 3) then
                if (math.abs(pos.z - playerPos.z) < 3) then
                    Engine.Log("Checkpoint taken")
                    
                    pos.x = pos.x + self.public.offsetX
                    pos.y = pos.y + self.public.offsetY
                    pos.z = pos.z + self.public.offsetZ

                    lastCheckpoint = pos 
                    giveHermesMask = true
                    Restore(self)
                end
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

