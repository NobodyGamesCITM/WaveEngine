public = {
    updateWhenPaused = true,
    isAmbient        = true,
    sequenceId       = "",
    skipTime         = 5.0,
}

local active   = false
local timer    = 0.0
local duration = 0.0

local function hide()
    if not active then return end
    if _G.ForceCloseDialog then _G.ForceCloseDialog() end
    active = false
end

local function show(sequenceId, skipTime)
    if not sequenceId or sequenceId == "" then return end
    if active then hide() end

    _G.DialogAmbientMode = true

    if not _G.TriggerSequence then
        Engine.Log("[DialogTriggerManager] ERROR: TriggerSequence no disponible")
        return
    end

    _G.TriggerSequence(sequenceId)
    active   = true
    timer    = 0.0
    duration = skipTime or 5.0
end

function Start(self)
    _G.ShowAmbientDialog = show
    _G.HideAmbientDialog = hide
end

function Update(self, dt)
    if not active then return end
    timer = timer + dt
    if timer >= duration then hide() end
end

function Trigger(self)
    if self.public.isAmbient then
        show(self.public.sequenceId, self.public.skipTime)
    else
        _G.DialogAmbientMode = false
        if _G.TriggerSequence then
            _G.TriggerSequence(self.public.sequenceId)
        end
    end
end