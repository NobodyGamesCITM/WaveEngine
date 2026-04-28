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
    if active then hide() end

    
    _G.DialogAmbientMode = true 

    if _G.TriggerSequence then
        _G.TriggerSequence(sequenceId)
    end

    active   = true
    timer    = 0.0
    duration = skipTime or 5.0
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