public = {
    varName      = "keysCollected",
    amount       = 1.0,
    collectKey   = "X",
}

function Start(self)
    self.playerInside = false
    self.isCollected  = false
end

function Update(self, dt)
    if self.isCollected then return end
    if self.playerInside and Input.GetKeyDown(self.public.collectKey or "X") then
        self.isCollected = true
        local current = _G[self.public.varName or "keysCollected"] or 0
        _G[self.public.varName or "keysCollected"] = current + (self.public.amount or 1.0)
        Engine.Log("[Collectible] Recogido. Total: " .. tostring(_G[self.public.varName or "keysCollected"]))
        if GameObject.Destroy then GameObject.Destroy(self.gameObject) end
    end
end

function OnTriggerEnter(self, other)
    if other and other:CompareTag("Player") then self.playerInside = true end
end

function OnTriggerExit(self, other)
    if other and other:CompareTag("Player") then self.playerInside = false end
end
