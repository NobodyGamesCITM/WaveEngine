public = {
    updateWhenPaused = false,
}

local MASK_DATA = {
    hermes = {
        name      = "LA MÁSCARA DE HERMES",
        maskImg   = "MaskImg_Hermes",
        skillImgs = { "MaskSkill_Hermes_Heavy", "MaskSkill_Hermes_Run" },
        hint      = "heavy_attack",
    },
    apolo = {
        name      = "LA MÁSCARA DE APOLO",
        maskImg   = "MaskImg_Apolo",
        skillImgs = { "MaskSkill_Apolo_Heavy" },
        hint      = "heavy_attack",
    },
    ares = {
        name      = "LA MÁSCARA DE ARES",
        maskImg   = "MaskImg_Ares",
        skillImgs = { "MaskSkill_Ares_Heavy" },
        hint      = "heavy_attack",
    },
}

local ALL_MASK_IMGS = {
    "MaskImg_Hermes", "MaskImg_Apolo", "MaskImg_Ares",
}
local ALL_SKILL_IMGS = {
    "MaskSkill_Hermes_Heavy", "MaskSkill_Hermes_Run",
    "MaskSkill_Apolo_Heavy",
    "MaskSkill_Ares_Heavy",
}

local active      = false
local pendingHint = nil

local function hideAll()
    for _, img in ipairs(ALL_MASK_IMGS)  do UI.SetElementVisibility(img, false) end
    for _, img in ipairs(ALL_SKILL_IMGS) do UI.SetElementVisibility(img, false) end
    UI.SetElementVisibility("MaskObtainedName", false)
end

local function closeMaskPanel()
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel", false)

    if pendingHint and _G.ShowControlsHint then
        _G.ShowControlsHint(pendingHint)
    end

    active      = false
    pendingHint = nil
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

    for _, img in ipairs(data.skillImgs) do
        UI.SetElementVisibility(img, true)
    end

    UI.SetElementVisibility("MaskObtainedPanel", true)

    active      = true
    pendingHint = data.hint

    Engine.Log("[MaskObtained] Mostrando: " .. maskKey)
end

function Start(self)
    hideAll()
    UI.SetElementVisibility("MaskObtainedPanel", false)

    _G.ShowMaskObtained = showMaskObtained

    Engine.Log("[MaskObtained] Ready")
end

function Update(self, dt)
    if not active then return end

    if Input.GetKeyDown("F") then
        closeMaskPanel()
    end
end