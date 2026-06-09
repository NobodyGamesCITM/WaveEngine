public = {
    updateWhenPaused = true,
}

local canvas = nil
local active = false

local function updateInputIcon()
    local input = _G.LastInputType or "keyboard"
    if input == "gamepad" then
        UI.SetElementVisibility("ItemObtainedKeyIcon",     false)
        UI.SetElementVisibility("ItemObtainedGamepadIcon", true)
    else
        UI.SetElementVisibility("ItemObtainedKeyIcon",     true)
        UI.SetElementVisibility("ItemObtainedGamepadIcon", false)
    end
end

-- Muestra el icono correcto según el tipo de poción
local function updateItemIcon(potionType)
    if potionType == "Berserk" then
        UI.SetElementVisibility("PotionImageHealth",  false)
        UI.SetElementVisibility("PotionImageBerserk", true)
        UI.SetElementVisibility("BerserkUseHint",     true)   
    else
        -- "Health" o cualquier otro valor
        UI.SetElementVisibility("PotionImageHealth",  true)
        UI.SetElementVisibility("PotionImageBerserk", false)
        UI.SetElementVisibility("BerserkUseHint",     false)  
    end
end

local function hide()
    UI.SetElementVisibility("ItemObtainedPanel", false)
    active = false
    _G.ItemObtainedActive = false
    if _G.OnItemObtainedClosed then
        _G.OnItemObtainedClosed()
        _G.OnItemObtainedClosed = nil
    end
    Engine.Log("[ItemObtained] Cerrado")
end

-- potionType: "Health" | "Berserk"  (opcional, por defecto "Health")
local function show(itemText, potionType, onClose)
    _G.OnItemObtainedClosed = onClose
    UI.SetElementText("ItemObtainedText", itemText or "¡Objeto obtenido!")
    -- Panel visible primero para que Noesis encuentre los hijos
    UI.SetElementVisibility("ItemObtainedPanel", true)
    updateInputIcon()
    updateItemIcon(potionType)
    if canvas then
        canvas:PlayStoryboard("PotionAppear", "ItemObtainedPanel")
        Engine.Log("[ItemObtained] Storyboard PotionAppear lanzado")
    else
        Engine.Log("[ItemObtained] ERROR: canvas nil, no se puede lanzar PotionAppear")
    end
    active = true
    _G.ItemObtainedActive = true
    Engine.Log("[ItemObtained] Mostrado: " .. tostring(itemText) .. " | Tipo: " .. tostring(potionType))
end

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")
    if not canvas then
        Engine.Log("[ItemObtained] ERROR: No ComponentCanvas found")
    end
    UI.SetElementVisibility("ItemObtainedPanel", false)
    _G.ItemObtainedActive = false
    _G.ShowItemObtained   = show
    _G.HideItemObtained   = hide
    Engine.Log("[ItemObtained] Ready")
end

function Update(self, dt)
    if active then
        updateInputIcon()
    end
end