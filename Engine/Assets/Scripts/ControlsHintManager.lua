public = {
    updateWhenPaused = true,
}

PRESETS = {
    intro = {
        duration = 5.0,
        slots = {
            { img = "HintImg_Caminar",         key = "HintKey_WASD",   gp = "HintGP_Joystick" },
        },
    },
    run = {
        duration = 4.0,
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
    ares_puzzle = {
        duration = 5.0,
        condition = function() return _G._UnlockedMasks and _G._UnlockedMasks.Ares == true end,
        slots = {
            { img = "HintImg_Ares",            key = "HintKey_Q",      gp = "HintGP_Y" },
        },
    },
    apolo_puzzle = {
        duration = 5.0,
        condition = function() return _G._UnlockedMasks and _G._UnlockedMasks.Apollo == true end,
        slots = {
            { img = "HintImg_ApoloFuerte",      key = "HintKey_E",           gp = "HintGP_Y" },
        },
    },
    apolo_puzzleDisparo = {
        duration = 5.0,
        condition = function() return _G._UnlockedMasks and _G._UnlockedMasks.Apollo == true end,
        slots = {
            { img = "HintImg_ApoloDisparo",         key = "HintKey_Q",      gp = "HintGP_Y" },
        },
    },
}

local ONCE_ONLY = {
    intro                = true,
    run                  = true,
    combat               = true,
    heavy_attack         = true,
    change_mask          = true,
    potion_health        = true,
    potion_berserk       = true,
    ares_puzzle          = true,
    apolo_puzzle         = true,
    apolo_puzzleDisparo  = true,
}

local PANEL_WIDTH         = 767
local PANEL_PADDING_X     = 40
local PANEL_PADDING_Y     = 8
local PANEL_MAX_CONTENT_W = PANEL_WIDTH - (2 * PANEL_PADDING_X)
local PANEL_MAX_CONTENT_H = 172
local SLOT_GAP            = 28
local IMG_KEY_GAP         = 14

local IMG_GRIDS = { "HintImgGrid1", "HintImgGrid2" }
local KEY_GRIDS = { "HintKeyGrid1", "HintKeyGrid2" }

local IMG_SIZES = {
    HintImg_ApoloFuerte     = { w = 300, h = 80 },
    HintImg_ApoloDisparo    = { w = 300, h = 90 },
    HintImg_Ares            = { w = 180, h = 120 },
    HintImg_Caminar         = { w = 180, h = 100 },
    HintImg_AtaqueNormal    = { w = 180, h = 120 },
    HintImg_AtaqueFuerte    = { w = 180, h = 120 },
    HintImg_Correr          = { w = 180, h = 120 },
    HintImg_CambiarMascaras = { w = 180, h = 120 },
    HintImg_Health          = { w = 180, h = 100 },
    HintImg_Berserk         = { w = 180, h = 120 },
    HintImg2_Estatua        = { w = 180, h = 120 },
    HintImg2_ApoloFuerte    = { w = 180, h = 120 },
    HintImg2_Roll           = { w = 197, h = 106 },
    HintImg2_AtaqueNormal   = { w = 180, h = 120 },
}

local KEY_SIZES = {
    HintKey_WASD     = { w = 100, h = 100 },
    HintKey_E        = { w = 75,  h = 75 },
    HintKey_Q        = { w = 75,  h = 75 },
    HintKey_Ctrl     = { w = 75,  h = 75 },
    HintKey_Shift    = { w = 75,  h = 75 },
    HintKey_R        = { w = 75,  h = 75 },
    HintKey_F        = { w = 75,  h = 75 },
    HintKey_8        = { w = 75,  h = 75 },
    HintKey2_Ctrl    = { w = 75,  h = 75 },
    HintKey2_E       = { w = 75,  h = 75 },
    HintGP_X         = { w = 75,  h = 75 },
    HintGP_Cruz      = { w = 75,  h = 75 },
    HintGP_Joystick  = { w = 75,  h = 75 },
    HintGP_LB        = { w = 75,  h = 75 },
    HintGP_RB        = { w = 75,  h = 75 },
    HintGP_LT        = { w = 75,  h = 75 },
    HintGP_Y         = { w = 75,  h = 75 },
    HintGP2_B        = { w = 75,  h = 75 },
}

local ALL_IMGS = {}
for name, _ in pairs(IMG_SIZES) do
    ALL_IMGS[#ALL_IMGS + 1] = name
end

local ALL_KEYS = {}
for name, _ in pairs(KEY_SIZES) do
    ALL_KEYS[#ALL_KEYS + 1] = name
end

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

local function getImgSize(name)
    return IMG_SIZES[name] or { w = 120, h = 80 }
end

local function getKeySize(name)
    return KEY_SIZES[name] or { w = 75, h = 75 }
end

local function resetElementSizes()
    for name, sz in pairs(IMG_SIZES) do
        UI.SetElementWidth(name, sz.w)
        UI.SetElementHeight(name, sz.h)
    end
    for name, sz in pairs(KEY_SIZES) do
        UI.SetElementWidth(name, sz.w)
        UI.SetElementHeight(name, sz.h)
    end
    for _, gridName in ipairs(IMG_GRIDS) do
        UI.SetElementWidth(gridName, 1)
        UI.SetElementHeight(gridName, 1)
    end
    for _, gridName in ipairs(KEY_GRIDS) do
        UI.SetElementWidth(gridName, 1)
        UI.SetElementHeight(gridName, 1)
        UI.SetElementMargin(gridName, 0, 0, 0, 0)
    end
end

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
    for _, kg in ipairs(KEY_GRIDS) do
        UI.SetElementVisibility(kg, false)
    end
    resetElementSizes()
    UI.SetElementMargin("ControlsHintContent", PANEL_PADDING_X, PANEL_PADDING_Y, PANEL_PADDING_X, PANEL_PADDING_Y)
    UI.SetElementMargin("HintSlot1", 0, 0, 0, 0)
    UI.SetElementMargin("HintSlot2", 0, 0, 0, 0)
end

local function layoutSlots(preset)
    local numSlots = #preset.slots
    local totalW   = 0
    local maxH     = 0
    local slotInfos = {}

    for i, slot in ipairs(preset.slots) do
        local keyName = usingGamepad() and slot.gp or slot.key
        local imgSz   = getImgSize(slot.img)
        local keySz   = (keyName and keyName ~= "") and getKeySize(keyName) or { w = 0, h = 0 }
        local keyGap  = (keyName and keyName ~= "") and IMG_KEY_GAP or 0
        local slotW   = imgSz.w + keyGap + keySz.w
        local slotH   = math.max(imgSz.h, keySz.h)
        totalW = totalW + slotW
        maxH   = math.max(maxH, slotH)
        slotInfos[i] = {
            img = slot.img,
            key = keyName,
            imgSz = imgSz,
            keySz = keySz,
            keyGap = keyGap,
            slotW = slotW,
        }
    end

    if numSlots > 1 then
        totalW = totalW + SLOT_GAP
    end

    local scaleW = PANEL_MAX_CONTENT_W / math.max(totalW, 1)
    local scaleH = PANEL_MAX_CONTENT_H / math.max(maxH, 1)
    local scale  = math.min(1.0, scaleW, scaleH)

    for i, info in ipairs(slotInfos) do
        local imgW = info.imgSz.w * scale
        local imgH = info.imgSz.h * scale
        UI.SetElementWidth(IMG_GRIDS[i], imgW)
        UI.SetElementHeight(IMG_GRIDS[i], imgH)
        UI.SetElementWidth(info.img, imgW)
        UI.SetElementHeight(info.img, imgH)
        if info.key and info.key ~= "" then
            local keyW = info.keySz.w * scale
            local keyH = info.keySz.h * scale
            local keyGap = info.keyGap * scale
            UI.SetElementMargin(KEY_GRIDS[i], keyGap, 0, 0, 0)
            UI.SetElementWidth(KEY_GRIDS[i], keyW)
            UI.SetElementHeight(KEY_GRIDS[i], keyH)
            UI.SetElementWidth(info.key, keyW)
            UI.SetElementHeight(info.key, keyH)
        else
            UI.SetElementMargin(KEY_GRIDS[i], 0, 0, 0, 0)
            UI.SetElementWidth(KEY_GRIDS[i], 1)
            UI.SetElementHeight(KEY_GRIDS[i], 1)
        end
    end

    UI.SetElementMargin("ControlsHintContent", PANEL_PADDING_X, PANEL_PADDING_Y, PANEL_PADDING_X, PANEL_PADDING_Y)

    if numSlots > 1 then
        UI.SetElementMargin("HintSlot1", 0, 0, SLOT_GAP * scale, 0)
        UI.SetElementMargin("HintSlot2", 0, 0, 0, 0)
    else
        UI.SetElementMargin("HintSlot1", 0, 0, 0, 0)
        UI.SetElementMargin("HintSlot2", 0, 0, 0, 0)
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

local function applySlots(preset)
    hideAll()
    for i, slot in ipairs(preset.slots) do
        local keyName = usingGamepad() and slot.gp or slot.key
        UI.SetElementVisibility(SLOTS[i], true)
        UI.SetElementVisibility(slot.img, true)
        if keyName and keyName ~= "" then
            UI.SetElementVisibility(KEY_GRIDS[i], true)
            UI.SetElementVisibility(keyName, true)
        end
    end
    layoutSlots(preset)
end

function refreshCurrentHint()
    if not currentPreset then return end
    local preset = PRESETS[currentPreset]
    if not preset then return end
    applySlots(preset)
end

local function showPreset(presetName, overrideDuration)
    local preset = PRESETS[presetName]
    if not preset then
        return
    end

    if preset.condition and not preset.condition() then
        return
    end

    if ONCE_ONLY[presetName] and seenPresets[presetName] then
        return
    end

    if ONCE_ONLY[presetName] then
        seenPresets[presetName] = true
    end

    currentPreset = presetName
    timer         = 0.0
    duration      = overrideDuration or preset.duration

    applySlots(preset)
    UI.SetElementVisibility("ControlsHintPanel", true)
    _G._IsHintActive = true
end

function Start(self)
    _G._IsHintActive  = false
    _G.LastInputType  = _G.LastInputType or "keyboard"
    hideAll()
    UI.SetElementVisibility("ControlsHintPanel", false)
    UI.SetElementVisibility("ChangeMaskTutorialBackground", false)
    UI.SetElementVisibility("ChangeMaskTutorialGradient",   false)
    UI.SetElementVisibility("ChangeMaskTutorialPanel",      false)

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
        Engine.Log("[ChangeMaskTutorial] Llamado")
        UI.SetElementVisibility("ChangeMaskTutorialBackground", true)
        UI.SetElementVisibility("ChangeMaskTutorialGradient",   true)
        UI.SetElementVisibility("ChangeMaskTutorialPanel",      true)
        if _G.ApplyChangeMaskTutorialGradient then
            _G.ApplyChangeMaskTutorialGradient(true)
        end
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
            UI.SetElementVisibility("ChangeMaskTutorialBackground", false)
            UI.SetElementVisibility("ChangeMaskTutorialGradient",   false)
            UI.SetElementVisibility("ChangeMaskTutorialPanel",      false)
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
