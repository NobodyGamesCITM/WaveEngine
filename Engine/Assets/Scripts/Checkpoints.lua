--checkpoints script


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

local function ActivateParticles(self, checkpoint)
    if not checkpoint then 
        Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    lastCheckpointVFX = GameObject.FindInChildren(checkpoint, "LastCheckpointVFX")
    if lastCheckpointVFX then
        lastCheckpointVFX:SetActive(true)
        Engine.Log("Activated Particles GameObject")
        lastCheckpointPs = lastCheckpointVFX:GetComponent("ParticleSystem")
        
        if lastCheckpointPs then 
            if not lastCheckpointPs:IsPlaying() then 
                lastCheckpointPs:Play() 
                Engine.Log("Activated CheckPoint Particle System")
            end
           
        else 
            Engine.Log("Couldn't find Particle System on Last Saved CheckPoint VFX GameObject")
        end
    else 
        Engine.Log("Couldn't retrieve Last Saved CheckPoint VFX GameObject")    
    end
end

local function StopParticles(self, checkpoint)
    if not checkpoint then 
        Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    lastCheckpointVFX = GameObject.FindInChildren(checkpoint, "LastCheckpointVFX")
    if lastCheckpointVFX then
        
        lastCheckpointPs = lastCheckpointVFX:GetComponent("ParticleSystem")
        if lastCheckpointPs then 
            if lastCheckpointPs:IsPlaying() then 
                lastCheckpointPs:Stop() 
                Engine.Log("Deactivated CheckPoint Particle System")
            end
            
        else 
            Engine.Log("Couldn't find Particle System on Last Saved CheckPoint VFX GameObject")
        end

        lastCheckpointVFX:SetActive(false)
        Engine.Log("Deactivated Particles GameObject")
    else 
        Engine.Log("Couldn't retrieve Last Saved CheckPoint VFX GameObject")
    end
end

local function Initialize(self)
   checkpoints = GameObject.FindByTag("CheckPoint")
    
    for i, checkpoint in ipairs(checkpoints) do
        Engine.Log("Deactivating last checkpoint particles from checkpoint ".. i)
        StopParticles(self, checkpoint)
    end
end

function Start(self)
    Initialize(self)
    
end

function Update(self, deltaTime)

    if not checkpoints then
        Initialize(self)
    end

    if interact == true then 
        Engine.Log("Interacted with checkpoint")
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position

        for i, checkpoint in ipairs(checkpoints) do
            
            local pos = checkpoint.transform.worldPosition
            --Engine.Log("Checkpoint x: " ..tostring(pos.x).."  y: "..tostring(pos.y))
            if (math.abs(pos.x - playerPos.x) < self.public.near) then
                if (math.abs(pos.z - playerPos.z) < self.public.near) then
                    Engine.Log("[CHECKPOINT SCRIPT] Checkpoint taken")
					
                    previousCheckpoint = currentCheckpoint
                    currentCheckpoint = checkpoint
                    
                    pos.x = pos.x + self.public.offsetX
                    pos.y = pos.y + self.public.offsetY
                    pos.z = pos.z + self.public.offsetZ

                    lastCheckpoint = pos --current checkpoint transform, not gameobject
					StopParticles(self, previousCheckpoint)
                    ActivateParticles(self, currentCheckpoint)
                    
                    Restore(self)
                end
            end
        end
    end
end 



function Restore(self)
    if _G.PotionSystem then
        _G.PotionSystem.public.potionCount = 4
        _G.PotionSystem.public.berserkCount = 4
    end
end
