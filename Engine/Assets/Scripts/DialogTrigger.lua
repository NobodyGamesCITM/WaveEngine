public = {
    radius           = 3.0,
    sequenceId       = "intro",
    skipTime         = 5.0,
    updateWhenPaused = true,
    isAmbient        = false,
}

local function fire(self)
    if self._isAmbient == true or self._isAmbient == "true" then
        if _G.ShowAmbientDialog then
            _G.ShowAmbientDialog(self._sequenceId, self._skipTime)
        else
            self._triggered   = false
            self._pendingFire = true
        end
    else
        _G.DialogAmbientMode = false
        if _G.TriggerSequence then
            _G.TriggerSequence(self._sequenceId)
        else
            self._triggered   = false
            self._pendingFire = true
        end
    end
end

function Start(self)
    self._radius      = self.public.radius
    self._sequenceId  = self.public.sequenceId
    self._skipTime    = self.public.skipTime
    self._isAmbient   = self.public.isAmbient
    self._triggered   = false
    self._pendingFire = false
end

function Update(self, dt)
    if self._pendingFire then
        local ready = (self._isAmbient == true or self._isAmbient == "true")
                      and _G.ShowAmbientDialog
                   or ((self._isAmbient ~= true and self._isAmbient ~= "true")
                      and _G.TriggerSequence)
        if not ready then return end
        self._pendingFire = false
        fire(self)
        return
    end

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
    fire(self)
end