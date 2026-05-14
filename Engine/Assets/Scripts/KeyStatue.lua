-- KeyStatue.lua
public = {
    statueId = "Circle", -- Inspector
    statueBitValue = 1,  -- 1 (Circle), 2 (Arch), 4 (T)
    interactionRadius = 8.0,
    updateWhenPaused = true
}

local isUnlocked = false
local inRange = false
local initialChains = nil
local brokenChains = nil
local statueSFX = nil
local player = nil

function Start(self)
    isUnlocked = false
    inRange = false
    player = GameObject.Find("Player")
    
    initialChains = GameObject.FindInChildren(self.gameObject, "chains")
    brokenChains = GameObject.FindInChildren(self.gameObject, "broken_chains")
    
    local audioObj = GameObject.FindInChildren(self.gameObject, "StatueSource")
    if audioObj then statueSFX = audioObj:GetComponent("Audio Source") end

    if initialChains then initialChains:SetActive(true) end
    if brokenChains then brokenChains:SetActive(false) end
    
    Engine.Log("[KeyStatue] Estatua inicializada. ID en Inspector: " .. self.public.statueId)
end

function Update(self, dt)
    if isUnlocked then return end
    if not player then player = GameObject.Find("Player"); return end

    local myPos = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

    if dist <= self.public.interactionRadius then
        if not inRange then
            inRange = true
            if _G.ShowControlsHint then _G.ShowControlsHint("interact") end 
        end
        
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            Engine.Log("[KeyStatue] Interacción detectada en estatua: " .. self.public.statueId)
            
            isUnlocked = true
            
            if _G.HideControlsHint then _G.HideControlsHint() end

            if initialChains then initialChains:SetActive(false) end
            --if brokenChains then brokenChains:SetActive(true) end

            --if statueSFX then statueSFX:SelectPlayAudioEvent("SFX_GM_StatueOn") end

            if _G.PortalManagerInstance then
                Engine.Log("[KeyStatue] Avisando al PortalManager...")
                _G.PortalManagerInstance:ActivateStatue(self.public.statueBitValue, self.public.statueId, self.gameObject)
            else
                Engine.Log("[KeyStatue] ERROR: PortalManagerInstance es nil.")
            end
        end
    else
        if inRange then
            inRange = false
            if _G.HideControlsHint then _G.HideControlsHint() end
        end
    end
end