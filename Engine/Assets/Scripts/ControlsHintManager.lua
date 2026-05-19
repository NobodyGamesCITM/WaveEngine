public = {
    updateWhenPaused = true,
}

PRESETS = {
    intro = {
        duration = 3.0,
        slots = {
            { img = "HintImg_Caminar",         key = "HintKey_WASD",   gp = "HintGP_LeftStick" },
        },
    },
    run = {
        duration = 2.0,
        slots = {
            { img = "HintImg_Correr",          key = "HintKey_Shift",  gp = "HintGP_LT" },
        },
    },
    combat = {
        duration = 8.0,
        slots = {
            { img = "HintImg_AtaqueNormal",    key = "HintKey_E",      gp = "HintGP_X" },
            { img = "HintImg2_Roll",           key = "HintKey2_Ctrl",  gp = "HintGP2_B" },
        },
    },
    heavy_attack = {
        duration = 5.0,
        slots = {
            { img = "HintImg_AtaqueFuerte",    key = "HintKey_Q",      gp = "HintGP_Y" },
        },
    },
    change_mask = {
        duration = 5.0,
        slots = {
            { img = "HintImg_CambiarMascaras", key = "HintKey_8",      gp = "HintGP_Cruz" },
        },
    },
    potion_health = {
        duration = 10.0,
        slots = {
            { img = "HintImg_Health",          key = "HintKey_R",      gp = "HintGP_LB" },
        },
    },
    potion_berserk = {
        duration = 5.0,
        slots = {
            { img = "HintImg_Berserk",         key = "HintKey_8",      gp = "HintGP_RB" },
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
    -- teclado
    "HintKey_WASD",
    "HintKey_E",
    "HintKey_Q",
    "HintKey_Ctrl",
    "HintKey_Shift",
    "HintKey_R",
    "HintKey_F",
    "HintKey_8",
    "HintKey_Joystick",
    "HintKey2_Ctrl",
    "HintKey2_E",
    "HintGP_LeftStick",
    "HintGP_X",
    "HintGP_Y",
    "HintGP_B",
    "HintGP_LB",
    "HintGP_RB",
    "HintGP_LT",
    "HintGP_Cruz",
    "HintGP2_B",
}

local SLOTS = { "HintSlot1", "HintSlot2" }

local seenPresets   = {}
local currentPreset = nil
local timer         = 0.0
local duration      = nil
local changeMaskTutorialActive  = false
local changeMaskTutorialPending = false

local function usingGamepad()
    return (_G.LastInputType == "gamepad")
end


-- Utilidades UI
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
    _G._IsHintActive = false
end

-- Aplica los slots del preset según dispositivo
local function applySlots(preset)
    hideAll()
    for i, slot in ipairs(preset.slots) do
        local keyName = usingGamepad() and slot.gp or slot.key
        UI.SetElementVisibility(SLOTS[i], true)
        UI.SetElementVisibility(slot.img, true)
        UI.SetElementVisibility(keyName,  true)
    end

    if #preset.slots == 1 then
        UI.SetElementMargin("HintSlot1", 200, 0, 0, 0)
    else
        UI.SetElementMargin("HintSlot1", 0, 0, 16, 0)
    end
end

function refreshCurrentHint()
    if not currentPreset then return end
    local preset = PRESETS[currentPreset]
    if not preset then return end
    applySlots(preset)
end

-- Mostrar preset
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
    duration      = overrideDuration or preset.duration
    Engine.Log("[ControlsHint] Timer RESET para: " .. presetName .. " duration=" .. tostring(duration))

    applySlots(preset)
    UI.SetElementVisibility("ControlsHintPanel", true)
    _G._IsHintActive = true
    Engine.Log("[ControlsHint] Mostrando: " .. presetName
        .. (overrideDuration and (" (restante: " .. string.format("%.1f", overrideDuration) .. "s)") or "")
        .. " [" .. (usingGamepad() and "GAMEPAD" or "TECLADO") .. "]")
end

-- Start
function Start(self)
    _G._IsHintActive  = false
    _G.LastInputType  = _G.LastInputType or "keyboard"  -- fuente de verdad compartida
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
    if Input.GetGamepadButtonDown("A") or Input.GetGamepadButtonDown("B") or
       Input.GetGamepadButtonDown("X") or Input.GetGamepadButtonDown("Y") or
       Input.GetGamepadButtonDown("LB") or Input.GetGamepadButtonDown("RB") then
        if _G.LastInputType ~= "gamepad" then
            _G.LastInputType = "gamepad"
            Engine.Log("[ControlsHint] Dispositivo: GAMEPAD")
            if currentPreset then refreshCurrentHint() end
        end
    elseif Input.GetKeyDown("W") or Input.GetKeyDown("A") or Input.GetKeyDown("S") or
           Input.GetKeyDown("D") or Input.GetKeyDown("E") or Input.GetKeyDown("Q") or
           Input.GetKeyDown("R") or Input.GetKeyDown("F") or Input.GetKeyDown("Shift") then
        if _G.LastInputType ~= "keyboard" then
            _G.LastInputType = "keyboard"
            Engine.Log("[ControlsHint] Dispositivo: TECLADO")
            if currentPreset then refreshCurrentHint() end
        end
    end

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