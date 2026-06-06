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

local function updateItemIcon(potionType)
    if potionType == "Berserk" then
        UI.SetElementVisibility("PotionImageHealth",  false)
        UI.SetElementVisibility("PotionImageBerserk", true)
    else
        UI.SetElementVisibility("PotionImageHealth",  true)
        UI.SetElementVisibility("PotionImageBerserk", false)
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

local function show(itemText, potionType, onClose)
    _G.OnItemObtainedClosed = onClose
    UI.SetElementText("ItemObtainedText", itemText or "¡Objeto obtenido!")
    UI.SetElementVisibility("ItemObtainedPanel", true)
    updateInputIcon()
    updateItemIcon(potionType)

    if canvas then
        canvas:PlayStoryboard("PotionAppear")
        Engine.Log("[ItemObtained] Storyboard PotionAppear lanzado")
        if potionType ~= "Berserk" then
            canvas:PlayStoryboard("PotionSpriteAnim")
            Engine.Log("[ItemObtained] Storyboard PotionSpriteAnim lanzado")
        end
    else
        Engine.Log("[ItemObtained] ERROR: canvas nil, no se lanza storyboard")
    end

    active = true
    _G.ItemObtainedActive = true
    Engine.Log("[ItemObtained] Mostrado: " .. tostring(itemText) .. " | Tipo: " .. tostring(potionType))
end

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")
    if canvas then
        canvas:LoadXAML("ChestItem.xaml")
        Engine.Log("[ItemObtained] XAML ChestItem.xaml cargado")
    else
        Engine.Log("[ItemObtained] ERROR: no hay Canvas en este GameObject")
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