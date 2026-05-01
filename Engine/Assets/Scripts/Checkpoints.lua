--checkpoints script


public = {
    --Spawn Offset
    offsetX = 0.0,
    offsetY = 0.0,    
    offsetZ = 0.0,
    --Distancia entre player y estatua
    near = 8.0,         
}

-- local lastCheckpointVFX = nil
-- local lastCheckpointPs = nil
-- local sparklesVFX = nil
-- local sparklesPs = nil
-- local blueSparklesVFX = nil
-- local blueSparklesPs = nil

local currentCheckpoint = nil
local previousCheckpoint = nil

local function ActivateParticles(self, vfxName, checkpoint)
    if not checkpoint then 
        Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    local VFXobj = GameObject.FindInChildren(checkpoint, tostring(vfxName))

    if VFXobj then
        VFXobj:SetActive(true)
        Engine.Log("Activated " ..tostring(vfxName).. " Particles GameObject")
        local particleComp = VFXobj:GetComponent("ParticleSystem")
        
        if particleComp then 
            if not particleComp:IsPlaying() then 
                particleComp:Play() 
                Engine.Log("[Checkpoints] Activated " ..tostring(vfxName).. " Particle System")
            end
           
        else 
            Engine.Log("[Checkpoints] Couldn't find Particle System on " ..tostring(vfxName).. " GameObject")
        end
    else 
        Engine.Log("[Checkpoints] Couldn't retrieve " ..tostring(vfxName).. " GameObject")    
    end

    
end

local function StopParticles(self, vfxName, checkpoint)
    if not checkpoint then 
        Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    local VFXobj = GameObject.FindInChildren(checkpoint, tostring(vfxName))
    if VFXobj then
        
        local particleComp = VFXobj:GetComponent("ParticleSystem")
        if particleComp then 
            if particleComp:IsPlaying() then 
                particleComp:Stop() 
                Engine.Log("[Checkpoints] Deactivated " ..tostring(vfxName)..  " Particle System")
            end
            
        else 
            Engine.Log("[Checkpoints] Couldn't find Particle System on "..tostring(vfxName).. " GameObject")
        end

        VFXobj:SetActive(false)
        Engine.Log("[Checkpoints] Deactivated " ..tostring(vfxName).. " Particles GameObject")
    else 
        Engine.Log("[Checkpoints] Couldn't retrieve " ..tostring(vfxName).. " GameObject")
    end
end

local function Initialize(self)
   checkpoints = GameObject.FindByTag("CheckPoint")
    
    for i, checkpoint in ipairs(checkpoints) do
        Engine.Log("[Checkpoints] Deactivating particles from checkpoint ".. i)
        StopParticles(self, "LastCheckpointVFX", checkpoint)
        StopParticles(self, "BlueSparkles", checkpoint)
        ActivateParticles(self, "YellowSparkles", checkpoint)
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
        Engine.Log("[Checkpoints] Interacted with checkpoint")
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
					StopParticles(self, "LastCheckpointVFX", previousCheckpoint)
                    StopParticles(self, "BlueSparkles", previousCheckpoint)
                    ActivateParticles(self, "Sparkles", previousCheckpoint)

                    ActivateParticles(self, "LastCheckpointVFX", currentCheckpoint)
                    ActivateParticles(self, "BlueSparkles", currentCheckpoint)
                    StopParticles(self, "YellowSparkles", currentCheckpoint)
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
