public = {
    updateWhenPaused = true,
}

-- Cola con prioridad
--   1 → mask      (máxima prioridad)
--   2 → dialog / ambient
--   3 → hint      (mínima prioridad)

local queue   = {}
local running = false

local PRIORITY = {
    mask    = 1,
    dialog  = 2,
    ambient = 2,
    hint    = 3,
}

local function highestQueuedPriority()
    local min = 99
    for _, item in ipairs(queue) do
        if item.priority < min then min = item.priority end
    end
    return min
end

local function purgeHints()
    for i = #queue, 1, -1 do
        if queue[i].type == "hint" then
            table.remove(queue, i)
        end
    end
end

local function hideActiveHint()
    if _G._RealHideControlsHint then
        _G._RealHideControlsHint()
    elseif _G.HideControlsHint then
        _G.HideControlsHint()
    end
end

local function enqueue(item)
    item.priority = PRIORITY[item.type] or 99

    if item.priority <= 2 then
        purgeHints()
        hideActiveHint()
    end

    local inserted = false
    for i = 1, #queue do
        if item.priority < queue[i].priority then
            table.insert(queue, i, item)
            inserted = true
            break
        end
    end
    if not inserted then
        queue[#queue + 1] = item
    end
end



local function isBusy()
    if _G._IsDialogActive == true then return true end
    if _G._IsMaskActive   == true then return true end

    if _G._IsHintActive == true then
        if highestQueuedPriority() <= 2 then
            hideActiveHint()
            purgeHints()
            return false
        end
        return true
    end

    return false
end


-- Dispatch

local function dispatch(item)
    running = true

    if item.type == "dialog" then
        _G.DialogAmbientMode = false
        hideActiveHint()
        purgeHints()
        if _G._RealTriggerSequence then
            _G._RealTriggerSequence(item.id)
        end

    elseif item.type == "ambient" then
        _G.DialogAmbientMode = true
        hideActiveHint()
        purgeHints()
        if _G._RealTriggerSequence then
            _G._RealTriggerSequence(item.id)
        end

    elseif item.type == "hint" then
        if _G._RealShowControlsHint then
            _G._RealShowControlsHint(item.preset)
        end

    elseif item.type == "mask" then
        if _G._RealShowMaskObtained then
            _G._RealShowMaskObtained(item.mask)
        end
    end
end


-- API interceptada

local function queueDialog(sequenceId)
    if not sequenceId or sequenceId == "" then return end
    enqueue({ type = "dialog", id = sequenceId })
end

local function queueAmbient(sequenceId, skipTime)
    if not sequenceId or sequenceId == "" then return end
    enqueue({ type = "ambient", id = sequenceId, skipTime = skipTime })
end

local function queueHint(preset)
    if not preset or preset == "" then return end
    enqueue({ type = "hint", preset = preset })
end

local function queueMask(maskKey)
    if not maskKey or maskKey == "" then return end
    enqueue({ type = "mask", mask = maskKey })
end


-- Inicialización diferida

local initialized = false
local initTimer   = 0.0
local INIT_DELAY  = 0.05

function Start(self) end

local function tryInit()
    if _G.TriggerSequence and not _G._RealTriggerSequence then
        _G._RealTriggerSequence = _G.TriggerSequence
        _G.TriggerSequence      = queueDialog
    end

    if _G.ShowAmbientDialog and not _G._RealShowAmbientDialog then
        _G._RealShowAmbientDialog = _G.ShowAmbientDialog
        _G.ShowAmbientDialog      = queueAmbient
    end

    if _G.ShowControlsHint and not _G._RealShowControlsHint then
        _G._RealShowControlsHint  = _G.ShowControlsHint
        _G.ShowControlsHint       = queueHint
    end

    if _G.HideControlsHint and not _G._RealHideControlsHint then
        _G._RealHideControlsHint = _G.HideControlsHint
    end

    if _G.ShowMaskObtained and not _G._RealShowMaskObtained then
        _G._RealShowMaskObtained = _G.ShowMaskObtained
        _G.ShowMaskObtained      = queueMask
    end

    if _G._RealTriggerSequence and _G._RealShowControlsHint and _G._RealShowMaskObtained then
        initialized = true
    end
end

function Update(self, dt)
    if not initialized then
        initTimer = initTimer + dt
        if initTimer >= INIT_DELAY then tryInit() end
        return
    end

    if isBusy() then
        running = true
        return
    end

    if running then
        running = false
    end

    if #queue > 0 then
        local next = table.remove(queue, 1)
        dispatch(next)
    end
end