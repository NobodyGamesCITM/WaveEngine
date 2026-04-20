public = {
    updateWhenPaused = true,
}

PRESETS = {
    intro = {
        { keyboard = "WASD",  gamepad = "LS",  text = "Moverse"  },
        { keyboard = "Shift", gamepad = "LB",  text = "Sprint"   },
        { keyboard = "Ctrl",  gamepad = "B",   text = "Roll"     },
    },
    combat = {
        { keyboard = "E",     gamepad = "X",   text = "Ataque"        },
        { keyboard = "Q",     gamepad = "Y",   text = "Ataque Pesado" },
        { keyboard = "Ctrl",  gamepad = "B",   text = "Roll"          },
    },
    interaction = {
        { keyboard = "R",     gamepad = "A",   text = "Interactuar"   },
        { keyboard = "F",     gamepad = "A",   text = "Pasar diálogo" },
    },
    mask = {
        { keyboard = "8",     gamepad = "R1",  text = "Equipar máscara" },
        { keyboard = "8",     gamepad = "L1",  text = "Cambiar máscara" },
    },
}

local currentPreset = nil

local function getHintElements()
    return {
        { panel = "HintSlot1", key = "HintKey1", text = "HintText1" },
        { panel = "HintSlot2", key = "HintKey2", text = "HintText2" },
        { panel = "HintSlot3", key = "HintKey3", text = "HintText3" },
    }
end

local function hideAllSlots()
    local slots = getHintElements()
    for _, slot in ipairs(slots) do
        UI.SetElementVisibility(slot.panel, false)
    end
end

local function showPreset(presetName)
       Engine.Log("[ControlsHint] Keys en PRESETS:")
    for k, v in pairs(PRESETS) do
        Engine.Log("  key: '" .. tostring(k) .. "'")
    end
    local preset = PRESETS[presetName]
    if not preset then
        Engine.Log("[ControlsHint] Preset no encontrado: " .. tostring(presetName))
        hideAllSlots()
        return
    end

    currentPreset = presetName
    local inputType = _G.LastInputType or "keyboard"
    local slots = getHintElements()

    for i, slot in ipairs(slots) do
        local hint = preset[i]
        if hint and hint.text ~= "" then
            local keyLabel = inputType == "gamepad" and hint.gamepad or hint.keyboard
            UI.SetElementText(slot.key, keyLabel)
            UI.SetElementText(slot.text, hint.text)
            UI.SetElementVisibility(slot.panel, true)
        else
            UI.SetElementVisibility(slot.panel, false)
        end
    end

    UI.SetElementVisibility("ControlsHintPanel", true)
end

local function hideHints()
    UI.SetElementVisibility("ControlsHintPanel", false)
    currentPreset = nil
end

function Start(self)
    hideAllSlots()
    UI.SetElementVisibility("ControlsHintPanel", false)

    _G.ShowControlsHint = showPreset
    _G.HideControlsHint = hideHints

    Engine.Log("[ControlsHint] Ready")
end

function Update(self, dt)
    -- Refrescar si cambia el tipo de input
    if currentPreset then
        local inputType = _G.LastInputType or "keyboard"
        local preset = PRESETS[currentPreset]
        local slots = getHintElements()

        for i, slot in ipairs(slots) do
            local hint = preset[i]
            if hint and hint.text ~= "" then
                local keyLabel = inputType == "gamepad" and hint.gamepad or hint.keyboard
                UI.SetElementText(slot.key, keyLabel)
            end
        end
    end
end