public = {
    updateWhenPaused = true,
}

local active   = false
local timer    = 0.0
local duration = 0.0

local function hide()
    if _G.ForceCloseDialog then
        _G.ForceCloseDialog()
    end
    active = false
    Engine.Log("[AmbientDialog] Cerrado")
end

local function show(sequenceId, skipTime)
    if not sequenceId or sequenceId == "" then return end

    -- Si ya hay uno activo lo cerramos primero
    if active then hide() end

    -- Neutralizar pausa antes de llamar al sistema de diálogos
    local originalPause  = Game.Pause
    local originalResume = Game.Resume
    Game.Pause  = function() end
    Game.Resume = function() end

    if _G.TriggerSequence then
        _G.TriggerSequence(sequenceId)
    else
        Engine.Log("[AmbientDialog] ERROR: TriggerSequence no disponible, asegurate de que DialogSystem esta en escena")
        Game.Pause  = originalPause
        Game.Resume = originalResume
        return
    end

    -- Restaurar inmediatamente tras mostrar
    Game.Pause  = originalPause
    Game.Resume = originalResume

    active   = true
    timer    = 0.0
    duration = skipTime or 5.0

    Engine.Log("[AmbientDialog] Mostrando '" .. sequenceId .. "' durante " .. tostring(duration) .. "s")
end

function Start(self)
    _G.ShowAmbientDialog = show
    _G.HideAmbientDialog = hide
    Engine.Log("[AmbientDialog] Ready")
end

function Update(self, dt)
    if not active then return end
    timer = timer + dt
    if timer >= duration then
        hide()
    end
end