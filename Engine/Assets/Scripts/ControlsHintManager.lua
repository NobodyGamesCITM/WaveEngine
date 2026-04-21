public = {
    updateWhenPaused = true,
}

PRESETS = {
    intro = {
        duration = 6.0,
        slots = {
            { img = "HintImg_Caminar",       key = "HintKey_WASD"  },
        },
    },
    run = {
        duration = 5.0,
        slots = {
            { img = "HintImg_Correr",        key = "HintKey_Shift" },
        },
    },
    combat = {
        duration = 5.0,
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
        duration = 5.0,
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
local lastMaskCount = 0

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
    currentPreset = nil
    timer         = 0.0
    duration      = nil
end

local function showPreset(presetName)
    if ONCE_ONLY[presetName] and seenPresets[presetName] then
        Engine.Log("[ControlsHint] Ya mostrado: " .. presetName)
        return
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
    duration      = preset.duration

    hideAll()

    for i, slot in ipairs(preset.slots) do
        UI.SetElementVisibility(SLOTS[i],    true)
        UI.SetElementVisibility(slot.img,    true)
        UI.SetElementVisibility(slot.key,    true)
    end

    UI.SetElementVisibility("ControlsHintPanel", true)
    Engine.Log("[ControlsHint] Mostrando: " .. presetName)
end

function Start(self)
    hideAll()
    UI.SetElementVisibility("ControlsHintPanel", false)

    _G.ShowControlsHint = showPreset
    _G.HideControlsHint = hideHints

    Engine.Log("[ControlsHint] Ready")
end

function Update(self, dt)
    -- detector de máscaras, siempre activo
    local currentCount = _G._MaskCount or 0
    if currentCount ~= lastMaskCount then
        lastMaskCount = currentCount
        if currentCount == 1 then
            showPreset("heavy_attack")
        elseif currentCount == 2 then
            showPreset("change_mask")
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