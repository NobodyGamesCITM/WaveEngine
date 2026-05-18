
public = {
    updateWhenPaused = true,
}


--  Cola con prioridad
--  Prioridad más baja = se ejecuta antes.
--    1 → mask      (máxima prioridad)
--    2 → dialog / ambient
--    3 → hint      (mínima prioridad)

local queue   = {}
local running = false

local PRIORITY = {
    mask    = 1,
    dialog  = 2,
    ambient = 2,
    hint    = 3,
}

local function purgeHints()
    for i = #queue, 1, -1 do
        if queue[i].type == "hint" then
            table.remove(queue, i)
        end
    end
end

local function hideActiveHint()
    if _G._IsHintActive and _G.HideControlsHint then
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


-- Estado activo

local function isBusy()
    return (_G._IsDialogActive == true)
        or (_G._IsMaskActive   == true)
        or (_G._IsHintActive   == true)
end


-- Dispatch: lanza el primer elemento de la cola

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


-- Diálogo normal

local function queueDialog(sequenceId)
    if not sequenceId or sequenceId == "" then return end
    enqueue({ type = "dialog", id = sequenceId })
end

-- Diálogo ambient
local function queueAmbient(sequenceId, skipTime)
    if not sequenceId or sequenceId == "" then return end
    enqueue({ type = "ambient", id = sequenceId, skipTime = skipTime })
end

-- Controls hint
local function queueHint(preset)
    if not preset or preset == "" then return end
    enqueue({ type = "hint", preset = preset })
end

-- Máscara obtenida
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
        _G._RealShowControlsHint = _G.ShowControlsHint
        _G.ShowControlsHint      = queueHint
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