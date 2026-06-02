--checkpoints script


public = {
    --Spawn Offset
    offsetX = 0.0,
    offsetY = 0.0,    
    offsetZ = 0.0,
    --Distancia entre player y estatua
    near = 8.0,
    saveCooldown = 5.0,         
}

-- local lastCheckpointVFX = nil
-- local lastCheckpointPs = nil
-- local sparklesVFX = nil
-- local sparklesPs = nil
-- local blueSparklesVFX = nil
-- local blueSparklesPs = nil

local currentCheckpoint = nil
local previousCheckpoint = nil
local normalTexUUID = "15061063724499349633"
local glowingTexUUID = "5205049906102326052"
local saveAgainTimer = 0
local isInCoolDown = false
local canSaveAgain = false


local function ChangeTexture(texUUID, checkpoint)
    if not checkpoint then 
        --Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    local buhoObj = GameObject.FindInChildren(checkpoint, "Buho")
    if buhoObj then
        local buhoMat = buhoObj:GetComponent("Material")
        if not buhoMat then 
            ---Engine.Log("[CHECKPOINTS] Unable to retrieve Buho Material Component")
        else
            buhoMat.SetTexture(texUUID)

            if texUUID == normalTexUUID then 
                --Engine.Log("[CHECKPOINTS] Successfully applied normal eyes to Athena Statue")
            elseif texUUID == glowingTexUUID then 
                --Engine.Log("[CHECKPOINTS] Successfully applied Glowing Eyes to Athena Statue" )
            end
        end
    end


    --the base looks the same in both so it isn't really needed in the base object, I guess

end


local function ActivateParticles(vfxName, checkpoint)
    if not checkpoint then 
        --Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    local VFXobj = GameObject.FindInChildren(checkpoint, tostring(vfxName))

    if VFXobj then
        VFXobj:SetActive(true)
        --Engine.Log("Activated " ..tostring(vfxName).. " Particles GameObject")
        local particleComp = VFXobj:GetComponent("ParticleSystem")
        
        if particleComp then 
            if not particleComp:IsPlaying() then 
                particleComp:Play() 
                --Engine.Log("[Checkpoints] Activated " ..tostring(vfxName).. " Particle System")
            end
           
        else 
            --Engine.Log("[Checkpoints] Couldn't find Particle System on " ..tostring(vfxName).. " GameObject")
        end
    else 
        --Engine.Log("[Checkpoints] Couldn't retrieve " ..tostring(vfxName).. " GameObject")    
    end

    
end

local function StopParticles(vfxName, checkpoint)
    if not checkpoint then 
        --Engine.Log("[CHECKPOINT SCRIPT] Checkpoint was nil!")
        return 
    end

    local VFXobj = GameObject.FindInChildren(checkpoint, tostring(vfxName))
    if VFXobj then
        
        local particleComp = VFXobj:GetComponent("ParticleSystem")
        if particleComp then 
            if particleComp:IsPlaying() then 
                particleComp:Stop() 
                --Engine.Log("[Checkpoints] Deactivated " ..tostring(vfxName)..  " Particle System")
            end
            
        else 
            --Engine.Log("[Checkpoints] Couldn't find Particle System on "..tostring(vfxName).. " GameObject")
        end

        VFXobj:SetActive(false)
        --Engine.Log("[Checkpoints] Deactivated " ..tostring(vfxName).. " Particles GameObject")
    else 
        --Engine.Log("[Checkpoints] Couldn't retrieve " ..tostring(vfxName).. " GameObject")
    end
end

local function FindCheckPointAudioSources(self)

    local saveSource = GameObject.FindInChildren(self.gameObject, "VoiceSource")
    if saveSource then 
        self.saveSFX = saveSource:GetComponent("Audio Source")
    else
        --Engine.Log("[Checkpoints] Unable to retrieve Save (Player's VoiceSource) Source GameObject!")
    end

end


local function Initialize(self)

    FindCheckPointAudioSources(self)
    isInCoolDown = false
    canSaveAgain = false
    saveAgainTimer = 0

    --Engine.RequestResource(normalTexUUID)
    --Engine.RequestResource(glowingTexUUID)

    checkpoints = GameObject.FindByTag("CheckPoint")
    for i, checkpoint in ipairs(checkpoints) do
       -- Engine.Log("[Checkpoints] Deactivating particles from checkpoint ".. i)
        StopParticles("LastCheckpointVFX", checkpoint)
        StopParticles("BlueSparkles", checkpoint)
        ActivateParticles("YellowSparkles", checkpoint)

        --ChangeTexture(self, checkpoint, normalTexUUID)
    end

end

function Start(self)
    Initialize(self)
    
end

function Update(self, dt)

    if not checkpoints then
        Initialize(self)
    end

    if not self.saveSFX then 
        FindCheckPointAudioSources(self)
    end

    if isInCoolDown then
        saveAgainTimer = saveAgainTimer + dt
        if saveAgainTimer >= (self.public.saveCoolDown or 5.0) then
            saveAgainTimer = 0
            isInCoolDown = false
            
        end
        
    end

    if _G.interact == true then 
        --Engine.Log("[Checkpoints] Interacted with checkpoint")
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.worldPosition

        for i, checkpoint in ipairs(checkpoints) do
            
            local pos = checkpoint.transform.worldPosition
            --Engine.Log("Checkpoint x: " ..tostring(pos.x).."  y: "..tostring(pos.y))
            if (math.abs(pos.x - playerPos.x) < self.public.near) then
                if (math.abs(pos.z - playerPos.z) < self.public.near) then

                   if currentCheckpoint == checkpoint and isInCoolDown then                        
                        Engine.Log("Saved "..tostring(saveAgainTimer).." seconds ago, please wait...")
                        return
                    end

                    Engine.Log("[CHECKPOINT SCRIPT] Checkpoint taken")

                    if _G.RestorePotions then
                        _G.RestorePotions()
                    end

					
                    previousCheckpoint = currentCheckpoint
                    currentCheckpoint = checkpoint
                    
                    pos.x = pos.x + self.public.offsetX
                    pos.y = pos.y + self.public.offsetY
                    pos.z = pos.z + self.public.offsetZ

                    lastCheckpoint = pos 


                    if previousCheckpoint then
                        StopParticles("LastCheckpointVFX", previousCheckpoint)
                        StopParticles("BlueSparkles", previousCheckpoint)
                        ActivateParticles("Sparkles", previousCheckpoint)
                        ChangeTexture(normalTexUUID, previousCheckpoint)
                    end

                    ActivateParticles("LastCheckpointVFX", currentCheckpoint)
                    ActivateParticles("BlueSparkles", currentCheckpoint)
                    StopParticles("YellowSparkles", currentCheckpoint)
                    ChangeTexture(glowingTexUUID, currentCheckpoint)

                    if self.saveSFX then self.saveSFX:SelectPlayAudioEvent("SFX_CheckPointSave") end

                   

                    if _G.SaveManager then
                        _G.SaveManager.SaveGame()
                        if _G.ShowSaveIcon then _G.ShowSaveIcon() end
                    end

                    isInCoolDown = true
                    saveAgainTimer = 0
                    
                    
                end
            end
        end
    end
end 


function _G.RestorePotions()
    if _G.TriggerBlueVignette then
        _G.TriggerBlueVignette()
    end

    if _G.PotionSystem then
        _G.PotionSystem.public.potionCount = _G.PotionSystem.public.maxPotions or 0
        _G.PotionSystem.public.berserkCount = _G.PotionSystem.public.maxBerserk or 0
    end

    if _G.PlayerInstance then
        _G.PlayerInstance.public.health = 100
        _G.PlayerInstance.public.stamina = 100
    end

    if _G.ForceRefreshHUD then
        _G.ForceRefreshHUD()
    end
end
