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
local player = nil

function Start(self)
    isUnlocked = false
    inRange = false
    player = GameObject.Find("Player")
    
    initialChains = GameObject.FindInChildren(self.gameObject, "chains")
    brokenChains = GameObject.FindInChildren(self.gameObject, "broken_chains")
    
    local currentState = _G.PortalState or 0
    if (currentState & self.public.statueBitValue) ~= 0 then
        isUnlocked = true
        if initialChains then initialChains:SetActive(false) end
        if brokenChains then brokenChains:SetActive(true) end
        return
    end

    if initialChains then initialChains:SetActive(true) end
    if brokenChains then brokenChains:SetActive(false) end
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
            isUnlocked = true
            if _G.HideControlsHint then _G.HideControlsHint() end

            if _G.PortalManagerInstance then
                _G.PortalManagerInstance:ActivateStatue(self.public.statueBitValue, self.public.statueId, self.gameObject, initialChains, brokenChains)
            end
        end
    else
        if inRange then
            inRange = false
            if _G.HideControlsHint then _G.HideControlsHint() end
        end
    end
end