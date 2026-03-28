

-- HUDController.lua

local STAMINA_BAR_MAX_HEIGHT = 56.0
local HEALTH_BAR_MAX_HEIGHT  = 74.0

local currentDisplayHealth = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0 

local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

local function RefreshHealthBar(targetHealth, dt)
    currentDisplayHealth = dt and Lerp(currentDisplayHealth, targetHealth, dt * LERP_SPEED) or targetHealth
    local clampedHealth = math.max(0, math.min(100, currentDisplayHealth))
    UI.SetElementHeight("HealthGrid", (clampedHealth / 100.0) * HEALTH_BAR_MAX_HEIGHT)
end

local function RefreshStaminaBar(targetStamina, dt)
    currentDisplayStamina = dt and Lerp(currentDisplayStamina, targetStamina, dt * LERP_SPEED) or targetStamina
    local clampedStamina = math.max(0, math.min(100, currentDisplayStamina))
    UI.SetElementHeight("StaminaGrid", (clampedStamina / 100.0) * STAMINA_BAR_MAX_HEIGHT)
end

local function RefreshPotionUI(potions)
    local clampedPotions = math.max(0, potions)
    UI.SetElementText("PotionsNumber", tostring(clampedPotions))
    UI.SetElementVisibility("Potion_Image",  clampedPotions > 0)
    UI.SetElementVisibility("PotionsNumber", true)
end

function ForceRefreshHUD()
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        RefreshHealthBar(p.health)
        RefreshStaminaBar(p.stamina)
    else
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