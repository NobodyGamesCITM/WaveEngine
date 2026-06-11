public = {
    statueId          = "Circle",
    statueBitValue    = 1,
    interactionRadius = 8.0,
    updateWhenPaused  = true,
}

local isUnlocked = false
local inRange    = false
local player     = nil

local initialChains = nil
local brokenChains  = nil

local function unlockStatue(self)
    isUnlocked = true

    _G.UnregisterInteractable(self.gameObject)
    if _G.HideControlsHint then _G.HideControlsHint() end

    if _G.PortalManagerInstance then
        _G.PortalManagerInstance:ActivateStatue(
            self.public.statueBitValue,
            self.public.statueId,
            self.gameObject,
            initialChains,
            brokenChains
        )
    end
end

function Start(self)
    isUnlocked = false
    inRange    = false
    player     = GameObject.Find("Player")

    initialChains = GameObject.FindInChildren(self.gameObject, "chains")
    brokenChains  = GameObject.FindInChildren(self.gameObject, "broken_chains")

    if initialChains then initialChains:SetActive(true)  end
    if brokenChains  then brokenChains:SetActive(false)  end

    _G._InteractCallbacks = _G._InteractCallbacks or {}
    _G._InteractCallbacks[self.gameObject] = function()
        unlockStatue(self)
    end
end

function Update(self, dt)
    local currentState = _G.PortalState or 0
    if (currentState & self.public.statueBitValue) ~= 0 then
        if not isUnlocked then
            isUnlocked = true
            if initialChains then initialChains:SetActive(false) end
            if brokenChains  then brokenChains:SetActive(true)   end
            _G.UnregisterInteractable(self.gameObject)
        end
        return
    end

    if isUnlocked then return end

    if not player then
        player = GameObject.Find("Player")
        return
    end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx   = myPos.x - playerPos.x
    local dz   = myPos.z - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist <= self.public.interactionRadius then
        if not inRange then
            inRange = true
            _G.RegisterInteractable(self.gameObject, "keystatue")
            if _G.ShowControlsHint then _G.ShowControlsHint("interact") end
        end
    else
        if inRange then
            inRange = false
            _G.UnregisterInteractable(self.gameObject)
            if _G.HideControlsHint then _G.HideControlsHint() end
        end
    end
end