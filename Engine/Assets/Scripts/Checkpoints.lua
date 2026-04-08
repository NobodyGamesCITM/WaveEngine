public = {
    --Spawn Offset
    offsetX = 0.0,
    offsetY = 0.0,    
    offsetZ = 0.0,
    --Distancia entre player y estatua
    near = 8.0,         
}

function Start(self)
    checkpoints = GameObject.FindByTag("CheckPoint")
end

function Update(self, deltaTime)

    if interact == true then 
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position

        for i, checkpoint in ipairs(checkpoints) do
            local pos = checkpoint.transform.worldPosition
            --Engine.Log("Checkpoint x: " ..tostring(pos.x).."  y: "..tostring(pos.y))
            if (math.abs(pos.x - playerPos.x) < self.public.near) then
                if (math.abs(pos.z - playerPos.z) < self.public.near) then
                    Engine.Log("Checkpoint taken")
                    
                    pos.x = pos.x + self.public.offsetX
                    pos.y = pos.y + self.public.offsetY
                    pos.z = pos.z + self.public.offsetZ

                    lastCheckpoint = pos 
                    Restore(self)
                end
            end
        end
    end
end 

function Restore(self)
    --player lifes etc
end
