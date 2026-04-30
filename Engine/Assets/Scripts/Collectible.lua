public = {
    varName      = "keysCollected",  
    amount       = 1.0,
    collectKey   = "X",
    totalInLevel = 3,                
}

function Start(self)
    self.playerInside = false
    self.isCollected  = false

    local currentTotal = _G.TotalStatuesToDestroy or 0
    if (self.public.totalInLevel or 0) > currentTotal then
        _G.TotalStatuesToDestroy = self.public.totalInLevel
    end

    _G.MissionVarName = self.public.varName or "keysCollected"

    if _G[_G.MissionVarName] == nil then
        _G[_G.MissionVarName] = 0
    end

    Engine.Log("[Collectible] Start. Total en nivel: " .. tostring(_G.TotalStatuesToDestroy))
end

function Update(self, dt)
    if self.isCollected then return end

    if self.playerInside and Input.GetKeyDown(self.public.collectKey or "X") then
        self.isCollected = true

        local varName = self.public.varName or "keysCollected"
        local current = _G[varName] or 0
        _G[varName]   = current + (self.public.amount or 1.0)

        Engine.Log("[Collectible] Recogido. " .. varName .. " = " .. tostring(_G[varName]))

        if _G.HUD_RefreshStatuesDestroyed then
            _G.HUD_RefreshStatuesDestroyed()
        end

        self:Destroy()
    end
end

function OnTriggerEnter(self, other)
    if other and other:CompareTag("Player") then
        self.playerInside = true
    end
end

function OnTriggerExit(self, other)
    if other and other:CompareTag("Player") then
        self.playerInside = false
    end
end