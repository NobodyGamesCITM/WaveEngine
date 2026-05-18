
public = {
    radius           = 3.0,
    sequenceId       = "intro",
    skipTime         = 5.0,
    updateWhenPaused = true,
    isAmbient        = false,
}

function Start(self)
    self._radius     = self.public.radius
    self._sequenceId = self.public.sequenceId
    self._skipTime   = self.public.skipTime
    self._isAmbient  = self.public.isAmbient
    self._triggered  = false

    local goName = (self.gameObject and self.gameObject.name) or "UnknownGO"

end

function Update(self, dt)
    if self._triggered then return end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx        = myPos.x - playerPos.x
    local dz        = myPos.z - playerPos.z
    local dist      = math.sqrt(dx * dx + dz * dz)

    if dist >= self._radius then return end

    self._triggered = true
    local goName = (self.gameObject and self.gameObject.name) or "UnknownGO"
    
    Engine.Log("[DialogTrigger] [" .. goName .. "] TRIGGERED! seq=" .. tostring(self._sequenceId) .. " | eval_ambient=" .. tostring(self._isAmbient))

    if self._isAmbient == true or self._isAmbient == "true" then
        Engine.Log("[DialogTrigger] [" .. goName .. "] -> Ejecutando ruta AMBIENT")
        if _G.ShowAmbientDialog then
            _G.ShowAmbientDialog(self._sequenceId, self._skipTime)
        else
            Engine.Log("[DialogTrigger] WARN: ShowAmbientDialog no disponible")
        end
    else
        Engine.Log("[DialogTrigger] [" .. goName .. "] -> Ejecutando ruta NORMAL")
        _G.DialogAmbientMode = false
        if _G.TriggerSequence then
            _G.TriggerSequence(self._sequenceId)
        else
            Engine.Log("[DialogTrigger] WARN: TriggerSequence no disponible")
        end
    end
end