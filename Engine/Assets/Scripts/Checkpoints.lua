public = {
    --Spawn Offset
    offsetX = 0.0,
    offsetY = 0.0,    
    offsetZ = 0.0,
    --Distancia entre player y estatua
    near = 8.0,         
}

local lastCheckpointVFX = nil
local lastCheckpointPs = nil

local currentCheckpoint = nil
local previousCheckpoint = nil

function Start(self)
    checkpoints = GameObject.FindByTag("CheckPoint")
    
    for i, checkpoint in ipairs(checkpoints) do
        Engine.Log("Deactivating last checkpoint particles form checkpoint ".. i)
        StopParticles(self, checkpoint)
    end
    
end

function Update(self, deltaTime)

    if interact == true then 
        
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position

        for i, checkpoint in ipairs(checkpoints) do
            StopParticles(self, checkPoint)
            local pos = checkpoint.transform.worldPosition
            --Engine.Log("Checkpoint x: " ..tostring(pos.x).."  y: "..tostring(pos.y))
            if (math.abs(pos.x - playerPos.x) < self.public.near) then
                if (math.abs(pos.z - playerPos.z) < self.public.near) then
                    Engine.Log("Checkpoint taken")
                    previousCheckpoint = currentCheckpoint
                    currentCheckpoint = checkPoint
                    
                    pos.x = pos.x + self.public.offsetX
                    pos.y = pos.y + self.public.offsetY
                    pos.z = pos.z + self.public.offsetZ

                    lastCheckpoint = pos --current checkpoint transform, not gameobject
                    ActivateParticles(self, currentCheckpoint)
                    
                    Restore(self)
                end
            end
        end
    end
end 

function ActivateParticles(self, checkpoint)
    lastCheckpointVFX = GameObject.FindInChildren(checkpoint, "LastCheckpointVFX")
    if lastCheckpointVFX then
        checkPointParticlesGO:SetActive(true)
        lastCheckpointPs = lastCheckpointVFX:GetComponent("Particle System")
        
        if lastCheckpointPs then lastCheckpointPs:Play()
        else 
            Engine.Log("Couldn't find Particle System on Last Saved CheckPoint VFX GameObject")
        end
    else 
        Engine.Log("Couldn't retrieve Last Saved CheckPoint VFX GameObject")    
    end
end

function StopParticles(self, checkpoint)
    lastCheckpointVFX = GameObject.FindInChildren(checkpoint, "lastCheckpointVFX")
    if lastCheckpointVFX then
        
        lastCheckpointPs = lastCheckpointVFX:GetComponent("Particle System")
        if lastCheckpointPs then lastCheckpointPs:Stop()
        else 
            Engine.Log("Couldn't find Particle System on Last Saved CheckPoint VFX GameObject")
        end

        checkPointParticlesGO:SetActive(false)
    else 
        Engine.Log("Couldn't retrieve Last Saved CheckPoint VFX GameObject")
    end
end

function Restore(self)
    if _G.PotionSystem then
        _G.PotionSystem.public.potionCount = 4
        _G.PotionSystem.public.berserkCount = 4
    end
end