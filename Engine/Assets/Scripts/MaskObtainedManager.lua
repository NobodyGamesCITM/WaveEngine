public = {
    updateWhenPaused = false,
}

local MASK_DATA = {
    hermes = {
        name      = "MASK OF HERMES",
        maskImg   = "MaskImg_Hermes",
        maskImg001 = "MaskImg_Hermes001",
        panel     = "MaskPanel_Hermes",
    },
    apolo = {
        name      = "MASK OF APOLO",
        maskImg   = "MaskImg_Apolo",
        maskImg001 = "MaskImg_Apolo001",
        panel     = "MaskPanel_Apolo",
    },
    ares = {
        name      = "MASK OF ARES",
        maskImg   = "MaskImg_Ares",
        maskImg001 = "MaskImg_Ares001",
        panel     = "MaskPanel_Ares",
    },
}

local ALL_MASK_IMGS = {
    "MaskImg_Hermes", "MaskImg_Hermes001",
    "MaskImg_Apolo",  "MaskImg_Apolo001",
    "MaskImg_Ares",   "MaskImg_Ares001",
}
local ALL_PANELS    = { "MaskPanel_Hermes", "MaskPanel_Apolo", "MaskPanel_Ares" }

local active      = false
local pendingHint = nil
local aresActive  = false

local ALL_KEY_IMGS_GP = { "MaskKey_Q_GP", "MaskKey_Q1_GP", "MaskKey_Q2_GP", "MaskKey_Shift_GP" }
local ALL_KEY_IMGS_KB = { "MaskKey_Q_KB", "MaskKey_Q1_KB", "MaskKey_Q2_KB", "MaskKey_Shift_KB" }

local function updateMaskKeys()
    local isGamepad = (_G.LastInputType == "gamepad")
    for _, img in ipairs(ALL_KEY_IMGS_GP) do UI.SetElementVisibility(img, isGamepad)  end
    for _, img in ipairs(ALL_KEY_IMGS_KB) do UI.SetElementVisibility(img, not isGamepad) end
end

local lastW, lastH = 0, 0

local function hideAll()
    for _, img in ipairs(ALL_MASK_IMGS) do UI.SetElementVisibility(img, false) end
    for _, p   in ipairs(ALL_PANELS)    do UI.SetElementVisibility(p,   false) end
    UI.SetElementVisibility("MaskObtainedName", false)
end

local TUTORIAL_GRADIENT_CENTER_X = 146
local TUTORIAL_GRADIENT_CENTER_Y = 104
local TUTORIAL_GRADIENT_RADIUS_X = 320
local TUTORIAL_GRADIENT_RADIUS_Y = 160

local function applyTutorialGradient(force)
    local w, h = Camera.GetViewportSize()
    if not w or w == 0 or not h or h == 0 then return end
    if not force and w == lastW and h == lastH then return end
    lastW, lastH = w, h

    local scale   = math.min(w / 1920, h / 1080)
    local offsetX = (w - 1920 * scale) * 0.5
    local offsetY = (h - 1080 * scale) * 0.5
    local centerX = offsetX + TUTORIAL_GRADIENT_CENTER_X * scale
    local centerY = offsetY + TUTORIAL_GRADIENT_CENTER_Y * scale
    UI.SetRadialGradientCenterAndRadius(
        "TutorialGradientRect",
        centerX, centerY,
        TUTORIAL_GRADIENT_RADIUS_X * scale,
        TUTORIAL_GRADIENT_RADIUS_Y * scale
    )
end

local function closeMaskPanel()
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel",      false)
    UI.SetElementVisibility("MaskObtainedBackground", false)

    Engine.Log("[MaskObtained] _MaskCount al cerrar: " .. tostring(_G._MaskCount))

    if _G._MaskCount == 2 then
        Engine.Log("[MaskObtained] Mostrando ChangeMaskTutorialPanel")
        if _G.ShowChangeMaskTutorial then
            _G.ShowChangeMaskTutorial()
        else
            UI.SetElementVisibility("ChangeMaskTutorialBackground", true)
            UI.SetElementVisibility("ChangeMaskTutorialGradient",   true)
            UI.SetElementVisibility("ChangeMaskTutorialPanel",      true)
            applyTutorialGradient(true)
        end
    end

    active      = false
    pendingHint = nil

    -- UIQueueManager
    _G._IsMaskActive = false
    Engine.Log("[MaskObtained] _IsMaskActive = false")
end

local function showMaskObtained(maskKey)
    local data = MASK_DATA[maskKey]
    if not data then
        Engine.Log("[MaskObtained] Máscara desconocida: " .. tostring(maskKey))
        return
    end

    hideAll()

    UI.SetElementText("MaskObtainedName", data.name)
    UI.SetElementVisibility("MaskObtainedName",       true)
    UI.SetElementVisibility(data.maskImg,             true)
    UI.SetElementVisibility(data.maskImg001,          true)
    UI.SetElementVisibility(data.panel,               true)
    UI.SetElementVisibility("MaskObtainedBackground", true)
    UI.SetElementVisibility("MaskObtainedPanel",      true)

    active      = true
    pendingHint = data.hint

    updateMaskKeys()

    -- Ares combat
    if data.name == "MÁSCARA DE ARES" then aresActive = true end

    -- UIQueueManager
    _G._IsMaskActive = true
    Engine.Log("[MaskObtained] Mostrando: " .. maskKey .. " | _IsMaskActive = true")
end

function Start(self)
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel",      false)
    UI.SetElementVisibility("MaskObtainedBackground", false)

    _G._IsMaskActive    = false
    _G.ShowMaskObtained = showMaskObtained

    applyTutorialGradient(true)
    _G.ApplyChangeMaskTutorialGradient = function(force)
        applyTutorialGradient(force)
    end

    Engine.Log("[MaskObtained] Ready")
end

function Update(self, dt)
    applyTutorialGradient()

    if not active then return end

    updateMaskKeys()

    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        
        if aresActive then 
            if _G.PlayGauntletAresCinematic then
                _G.PlayGauntletAresCinematic()
            end
            
            local combat = GameObject.Find("AresCombat")
            if combat then
                local combatScript = combat:GetComponent("Script")
                if combatScript and combatScript.startCombat then 
                    combatScript.startCombat() 
                end 
            end
            aresActive = false
        end
        
        closeMaskPanel()
    end
end