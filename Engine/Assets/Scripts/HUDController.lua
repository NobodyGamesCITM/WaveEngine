-- HUDController.lua

local HEALTH_BAR_MAX_WIDTH  = 334.0  
local STAMINA_BAR_MAX_WIDTH = 251.0   

local currentDisplayHealth  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0

local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

local function RefreshHealthBar(targetHealth, dt)
    currentDisplayHealth = dt and Lerp(currentDisplayHealth, targetHealth, dt * LERP_SPEED) or targetHealth
    local clamped = math.max(0, math.min(100, currentDisplayHealth))
    UI.SetElementWidth("HealthBarContainer", (clamped / 100.0) * HEALTH_BAR_MAX_WIDTH)
end

local function RefreshStaminaBar(targetStamina, dt)
    currentDisplayStamina = dt and Lerp(currentDisplayStamina, targetStamina, dt * LERP_SPEED) or targetStamina
    local clamped = math.max(0, math.min(100, currentDisplayStamina))
    UI.SetElementWidth("StaminaBarContainer", (clamped / 100.0) * STAMINA_BAR_MAX_WIDTH)
end

local function RefreshPotionUI(potions)
    -- Sincronizado con las 4 imágenes de poción del HUD.xaml (asumiendo Potion1, Potion2, etc.)
    for i = 1, 4 do
        UI.SetElementVisibility("Potion" .. i, i <= potions)
        UI.SetElementVisibility("UsedPotion" .. i, i > potions)
    end
end

function ForceRefreshHUD()
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        -- FIX: forzar reset de currentDisplayHealth para que el lerp arranque desde el valor real
        currentDisplayHealth  = p.health
        currentDisplayStamina = p.stamina
        RefreshHealthBar(p.health)
        RefreshStaminaBar(p.stamina)
    else
        currentDisplayHealth  = 100.0
        currentDisplayStamina = 100.0
        RefreshHealthBar(100)
        RefreshStaminaBar(100)
    end

    local potions = (_G.PotionSystem and _G.PotionSystem.public) and _G.PotionSystem.public.potionCount or 0
    RefreshPotionUI(potions)
end
_G.ForceRefreshHUD = ForceRefreshHUD

function Start(self)
    ForceRefreshHUD()
end

function Update(self, dt)
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        RefreshHealthBar(p.health, dt)
        RefreshStaminaBar(p.stamina, dt)
    end

    local potions = (_G.PotionSystem and _G.PotionSystem.public) and _G.PotionSystem.public.potionCount or 0
    RefreshPotionUI(potions)
end