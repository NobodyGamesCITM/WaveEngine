

public = {
    radius           = 3.0,
    sequenceId       = "intro",
    skipTime         = 5.0,
    updateWhenPaused = true,
}

local triggered = false


local ambientActive   = false
local ambientTimer    = 0.0
local ambientDuration = 0.0
local function hideAmbient()
    if not ambientActive then return end
    if _G.ForceCloseDialog then
        _G.ForceCloseDialog()
    end
    ambientActive = false
    Engine.Log("[DialogTrigger] Ambient cerrado")
end

local function showAmbient(sequenceId, skipTime)
    if not sequenceId or sequenceId == "" then return end
    if ambientActive then hideAmbient() end

    _G.DialogAmbientMode = true

    if _G.TriggerSequence then
        _G.TriggerSequence(sequenceId)
    end

    ambientActive   = true
    ambientTimer    = 0.0
    ambientDuration = skipTime or 5.0
    Engine.Log("[DialogTrigger] Ambient iniciado: " .. sequenceId .. " | duracion: " .. tostring(ambientDuration))
end



function Start(self)
    _G.ShowAmbientDialog = showAmbient
    _G.HideAmbientDialog = hideAmbient
    Engine.Log("[DialogTrigger] Ready")
end

function Update(self, dt)
    if ambientActive then
        ambientTimer = ambientTimer + dt
        if ambientTimer >= ambientDuration then
            hideAmbient()
            return
        end
    end

    if triggered then return end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist < self.public.radius then
        triggered = true
        showAmbient(self.public.sequenceId, self.public.skipTime)
    end
end
