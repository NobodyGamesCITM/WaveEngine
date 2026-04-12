public = {
    radius      = 3.0,
    sequenceId  = "intro",
    autoSkip    = true,   -- true = se cierra solo después de X segundos
    skipTime    = 5.0,    -- segundos hasta que se cierra
}

local triggered  = false
local skipTimer  = 0.0
local counting   = false

local function startAmbientSequence(sequenceId)
    if _G.CurrentXAML and _G.CurrentXAML ~= "HUD.xaml" then return end
    if not _G.TriggerSequence then return end
    _G.TriggerSequence(sequenceId)
end

function Update(self, dt)
    -- Comprobar distancia y disparar
    if not triggered then
        local player = GameObject.Find("Player")
        if not player then return end

        local myPos     = self.transform.worldPosition
        local playerPos = player.transform.worldPosition
        local dx = myPos.x - playerPos.x
        local dz = myPos.z - playerPos.z
        local dist = math.sqrt(dx*dx + dz*dz)

        if dist < self.public.radius then
            triggered = true
            counting  = false
            startAmbientSequence(self.public.sequenceId)
        end
        return
    end

    -- Auto-skip timer
    if self.public.autoSkip and _G.DialogActive then
        if not counting then
            skipTimer = 0.0
            counting  = true
        end
        skipTimer = skipTimer + dt
        if skipTimer >= self.public.skipTime then
            counting = false
            if _G.ForceCloseDialog then _G.ForceCloseDialog() end
        end
    end
end