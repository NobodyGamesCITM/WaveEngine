public = {
    updateWhenPaused = false,
}

local MASK_DATA = {
    hermes = {
        name    = "LA MÁSCARA DE HERMES",
        maskImg = "MaskImg_Hermes",
        panel   = "MaskPanel_Hermes",
    },
    apolo = {
        name    = "LA MÁSCARA DE APOLO",
        maskImg = "MaskImg_Apolo",
        panel   = "MaskPanel_Apolo",
    },
    ares = {
        name    = "LA MÁSCARA DE ARES",
        maskImg = "MaskImg_Ares",
        panel   = "MaskPanel_Ares",
    },
}

local ALL_MASK_IMGS = { "MaskImg_Hermes", "MaskImg_Apolo", "MaskImg_Ares" }
local ALL_PANELS    = { "MaskPanel_Hermes", "MaskPanel_Apolo", "MaskPanel_Ares" }

local active      = false
local pendingHint = nil

local ALL_KEY_IMGS = { "MaskKey_Q", "MaskKey_Shift" }

local function hideAll()
    for _, img in ipairs(ALL_MASK_IMGS) do UI.SetElementVisibility(img, false) end
    for _, p   in ipairs(ALL_PANELS)    do UI.SetElementVisibility(p,   false) end
    UI.SetElementVisibility("MaskObtainedName", false)
end

local function closeMaskPanel()
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel", false)

    Engine.Log("[MaskObtained] _MaskCount al cerrar: " .. tostring(_G._MaskCount))

    if _G._MaskCount == 2 then
        Engine.Log("[MaskObtained] Mostrando ChangeMaskTutorialPanel")
        if _G.ShowChangeMaskTutorial then
            _G.ShowChangeMaskTutorial()
        else
            UI.SetElementVisibility("ChangeMaskTutorialPanel", true)
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
    UI.SetElementVisibility("MaskObtainedName", true)
    UI.SetElementVisibility(data.maskImg, true)
    UI.SetElementVisibility(data.panel, true)
    UI.SetElementVisibility("MaskObtainedPanel", true)

    active      = true
    pendingHint = data.hint

    -- UIQueueManager
    _G._IsMaskActive = true
    Engine.Log("[MaskObtained] Mostrando: " .. maskKey .. " | _IsMaskActive = true")
end

function Start(self)
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel", false)

    _G._IsMaskActive    = false
    _G.ShowMaskObtained = showMaskObtained

    Engine.Log("[MaskObtained] Ready")
end

function Update(self, dt)
    if not active then return end

    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        closeMaskPanel()
    end
end