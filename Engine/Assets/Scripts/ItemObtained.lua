public = {
updateWhenPaused = true,
}
local active = false
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
local function show(itemText)
UI.SetElementText("ItemObtainedText", itemText or "¡Objeto obtenido!")
UI.SetElementVisibility("ItemObtainedPanel", true)
active = true
_G.ItemObtainedActive = true
Engine.Log("[ItemObtained] Mostrado")
end
function Start(self)
UI.SetElementVisibility("ItemObtainedPanel", false)
_G.ItemObtainedActive = false
_G.HideItemObtained   = hide
_G.ShowItemObtained   = function(itemText, itemIcon, onClose)
_G.OnItemObtainedClosed = onClose
show(itemText)
end
Engine.Log("[ItemObtained] Ready")
end

function Update(self, dt)
end