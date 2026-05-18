public = {
    updateWhenPaused = true,
}

PRESETS = {
    intro = {
        duration = 3.0,
        slots = {
            { img = "HintImg_Caminar",       key = "HintKey_WASD"  },
        },
    },
    run = {
        duration = 2.0,
        slots = {
            { img = "HintImg_Correr",        key = "HintKey_Shift" },
        },
    },
    combat = {
        duration = 8.0,
        slots = {
            { img = "HintImg_AtaqueNormal",  key = "HintKey_E"    },
            { img = "HintImg2_Roll",         key = "HintKey2_Ctrl" },
        },
    },
    heavy_attack = {
        duration = 5.0,
        slots = {
            { img = "HintImg_AtaqueFuerte",  key = "HintKey_Q"    },
        },
    },
    change_mask = {
        duration = 5.0,
        slots = {
            { img = "HintImg_CambiarMascaras", key = "HintKey_8"  },
        },
    },
    potion_health = {
        duration = 10.0,
        slots = {
            { img = "HintImg_Health",        key = "HintKey_R"    },
        },
    },
    potion_berserk = {
        duration = 5.0,
        slots = {
            { img = "HintImg_Berserk",       key = "HintKey_8"    },
        },
    },
}

local ONCE_ONLY = {
    intro          = true,
    run            = true,
    combat         = true,
    heavy_attack   = true,
    change_mask    = true,
    potion_health  = true,
    potion_berserk = true,
}

local ALL_IMGS = {
    "HintImg_Caminar",
    "HintImg_AtaqueNormal",
    "HintImg_AtaqueFuerte",
    "HintImg_Correr",
    "HintImg_CambiarMascaras",
    "HintImg_Health",
    "HintImg_Berserk",
    "HintImg2_Roll",
    "HintImg2_AtaqueNormal",
}

local ALL_KEYS = {
    "HintKey_WASD",
    "HintKey_E",
    "HintKey_Q",
    "HintKey_Ctrl",
    "HintKey_Shift",
    "HintKey_R",
    "HintKey_F",
    "HintKey_8",
    "HintKey2_Ctrl",
    "HintKey2_E",
}

local SLOTS = { "HintSlot1", "HintSlot2" }

local seenPresets   = {}
local currentPreset = nil
local timer         = 0.0
local duration      = nil
local changeMaskTutorialActive  = false
local changeMaskTutorialPending = false

local function hideAll()
    for _, img in ipairs(ALL_IMGS) do
        UI.SetElementVisibility(img, false)
    end
    for _, key in ipairs(ALL_KEYS) do
        UI.SetElementVisibility(key, false)
    end
    for _, slot in ipairs(SLOTS) do
        UI.SetElementVisibility(slot, false)
    end
end

local function hideHints()
    UI.SetElementVisibility("ControlsHintPanel", false)
    hideAll()
    currentPreset    = nil
    timer            = 0.0
    duration         = nil
    _G._IsHintActive = false   --UIQueueManager
end

-- overrideDuration: cuando el UIQueueManager re-encola un hint interrumpido
-- pasa el tiempo restante para que no empiece de cero
local function showPreset(presetName, overrideDuration)

    if not overrideDuration then
        if ONCE_ONLY[presetName] and seenPresets[presetName] then
            Engine.Log("[ControlsHint] Ya mostrado: " .. presetName)
            return
        end
    end

    local preset = PRESETS[presetName]
    if not preset then
        Engine.Log("[ControlsHint] Preset no encontrado: " .. presetName)
        return
    end

    if ONCE_ONLY[presetName] then
        seenPresets[presetName] = true
    end

    currentPreset = presetName
    timer         = 0.0
    duration      = overrideDuration or preset.duration  -- usa el tiempo restante si existe

    hideAll()

    for i, slot in ipairs(preset.slots) do
        UI.SetElementVisibility(SLOTS[i],  true)
        UI.SetElementVisibility(slot.img,  true)
        UI.SetElementVisibility(slot.key,  true)
    end

    if #preset.slots == 1 then
        UI.SetElementMargin("HintSlot1", 200, 0, 0, 0)
    else
        UI.SetElementMargin("HintSlot1", 0, 0, 16, 0)
    end

    UI.SetElementVisibility("ControlsHintPanel", true)
    _G._IsHintActive = true    -- UIQueueManager
    Engine.Log("[ControlsHint] Mostrando: " .. presetName
        .. (overrideDuration and (" (restante: " .. string.format("%.1f", overrideDuration) .. "s)") or ""))
end

function Start(self)
    _G._IsHintActive = false   -- UIQueueManager
    hideAll()
    UI.SetElementVisibility("ControlsHintPanel", false)
    UI.SetElementVisibility("ChangeMaskTutorialPanel", false)

    _G.ShowControlsHint = showPreset
    _G.HideControlsHint = hideHints

    _G._HintTimeRemaining = function()
        if not currentPreset or not duration then return 0 end
        return math.max(0, duration - timer)
    end
    _G._HintCurrentPreset = function()
        return currentPreset
    end

    _G.ShowChangeMaskTutorial = function()
        Engine.Log("[ChangeMaskTutorial] Llamado!")
        UI.SetElementVisibility("ChangeMaskTutorialPanel", true)
        changeMaskTutorialActive  = false
        changeMaskTutorialPending = true
    end

    Engine.Log("[ControlsHint] Ready")
end

function Update(self, dt)
    if changeMaskTutorialPending then
        changeMaskTutorialPending = false
        changeMaskTutorialActive  = true
        return
    end

    if changeMaskTutorialActive then
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            Engine.Log("[ChangeMaskTutorial] Cerrando")
            UI.SetElementVisibility("ChangeMaskTutorialPanel", false)
            changeMaskTutorialActive = false
        end
    end

    if not currentPreset then return end

    if duration then
        timer = timer + dt
        if timer >= duration then
            hideHints()
            return
        end
    end
end