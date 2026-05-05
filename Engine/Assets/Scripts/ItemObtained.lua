
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

local function show(itemText, itemIcon, onClose)
    _G.OnItemObtainedClosed = onClose
    UI.SetElementText("ItemObtainedText", itemText or "¡Objeto obtenido!")
    updateInputIcon()
    UI.SetElementVisibility("ItemObtainedPanel", true)
    if canvas then
        canvas:PlayStoryboard("PotionAppear", "ItemObtainedPanel")
        Engine.Log("[ItemObtained] Storyboard PotionAppear lanzado")
    else
        Engine.Log("[ItemObtained] ERROR: canvas nil, no se puede lanzar PotionAppear")
    end
    active = true
    _G.ItemObtainedActive = true
    Engine.Log("[ItemObtained] Mostrado: " .. tostring(itemText))
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
