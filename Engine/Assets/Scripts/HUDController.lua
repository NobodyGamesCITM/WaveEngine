local HEALTH_BAR_MAX_WIDTH  = 334.0
local STAMINA_BAR_MAX_WIDTH = 251.0

local currentDisplayHealth  = 100.0
local currentDisplayDamage  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0
local staminaPulseTimer = 0.0
local DAMAGE_LERP_SPEED = 2.5

local MASK_DISPLAY_ORDER = { "Apolo", "Hermes", "Ares" }

local prevHasHermes  = false
local prevHasAres    = false
local prevHasApolo   = false
local prevActiveMask = ""
local myCanvas = nil

-- ─── Helpers
local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

-- ─── Márgenes de los fondos de máscara según la máscara activa
local MASK_BG_MARGINS = {
    [""] = {
        apollo = { 31,  59, 121,  22 },
        hermes = { 73,   6,  65,  59 },
        ares   = {128,  59,  24,  22 },
    },
    ["Hermes"] = {
        apollo = { 31,  59, 121,  22 },   -- tamaño base
        hermes = { 57,   6,  49,  59 },   -- 114px ancho ACTIVO
        ares   = {128,  59,  24,  22 },   -- tamaño base
    },
    ["Ares"] = {
        apollo = { 31,  59, 121,  22 },   -- tamaño base
        hermes = { 73,   6,  65,  59 },   -- tamaño base
        ares   = {112,  59,   8,  22 },   -- 114px ancho ACTIVO
    },
    ["Apolo"] = {
        apollo = { 15,  59, 105,  22 },   -- 114px ancho ACTIVO
        hermes = { 73,   6,  65,  59 },   -- tamaño base
        ares   = {128,  59,  24,  22 },   -- tamaño base
    },
}

-- ─── Aplicar márgenes a los tres fondos según la máscara activa
local function RefreshMaskBackgrounds(activeMask)
    local key = activeMask or ""
    local margins = MASK_BG_MARGINS[key] or MASK_BG_MARGINS[""]

    -- UI.SetElementMargin espera (elementName, left, top, right, bottom)
    local a = margins.apollo
    UI.SetElementMargin("ApolloBackground_Image", a[1], a[2], a[3], a[4])

    local h = margins.hermes
    UI.SetElementMargin("HermesBackground_Image", h[1], h[2], h[3], h[4])

    local r = margins.ares
    UI.SetElementMargin("AresBackground_Image",   r[1], r[2], r[3], r[4])
end

-- ─── Barras
local function RefreshHealthBar(targetHealth, dt)
    if dt then
        currentDisplayHealth = Lerp(currentDisplayHealth, targetHealth, dt * LERP_SPEED)
        currentDisplayDamage = Lerp(currentDisplayDamage, targetHealth, dt * DAMAGE_LERP_SPEED)

        if currentDisplayDamage < currentDisplayHealth then
            currentDisplayDamage = currentDisplayHealth
        end
    else
        currentDisplayHealth = targetHealth
        currentDisplayDamage = targetHealth
    end

    local clampedHP = math.max(0, math.min(100, currentDisplayHealth))
    UI.SetElementWidth("HealthBarContainer", (clampedHP / 100.0) * HEALTH_BAR_MAX_WIDTH)

    local clampedDmg = math.max(0, math.min(100, currentDisplayDamage))
    UI.SetElementWidth("DamageBarContainer", (clampedDmg / 100.0) * HEALTH_BAR_MAX_WIDTH)
end

local function RefreshStaminaBar(targetStamina, dt)
    currentDisplayStamina = dt
        and Lerp(currentDisplayStamina, targetStamina, dt * LERP_SPEED)
        or  targetStamina
    local clamped = math.max(0, math.min(100, currentDisplayStamina))
    UI.SetElementWidth("StaminaBarContainer", (clamped / 100.0) * STAMINA_BAR_MAX_WIDTH)

    if _G._PlayerController_staminaLocked then
        if dt then
            staminaPulseTimer = staminaPulseTimer + dt
        end
        -- Oscila entre 0.5 (50%) y 1.0 (100%) a una frecuencia de ~2Hz
        local alpha = 0.75 + 0.25 * math.sin(staminaPulseTimer * 12.0)
        UI.SetElementOpacity("StaminaBarContainer", alpha)
    else
        staminaPulseTimer = 0
        --UI.SetElementOpacity("StaminaBarContainer", 1.0)
    end
end

-- ─── Pociones
local function RefreshPotionUI(potions, berserkPotions)
    local ps = _G.PotionSystem and _G.PotionSystem.public
    local maxH = ps and ps.maxPotions or 0
    local maxB = ps and ps.maxBerserk or 0

    for i = 1, 10 do
        local slotVisible = i <= maxH
        UI.SetElementVisibility("Potion" .. i,     slotVisible and i <= potions)
        UI.SetElementVisibility("UsedPotion" .. i, slotVisible and i > potions)
    end
    for i = 1, 10 do
        local slotVisible = i <= maxB
        UI.SetElementVisibility("Berserk" .. i,     slotVisible and i <= (berserkPotions or 0))
        UI.SetElementVisibility("UsedBerserk" .. i, slotVisible and i > (berserkPotions or 0))
    end
end

-- ─── Máscaras (iconos activo/inactivo + fondos)
local function RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)

    -- Apollo (izquierda)
    if hasApolo then
        local isActive = (activeMask == "Apolo")
        UI.SetElementVisibility("Image_Apolo_Active",   isActive)
        UI.SetElementVisibility("Image_Apolo_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Apolo_Active",   false)
        UI.SetElementVisibility("Image_Apolo_Inactive", false)
    end

    -- Hermes (centro)
    if hasHermes then
        local isActive = (activeMask == "Hermes")
        UI.SetElementVisibility("Image_Hermes_Active",   isActive)
        UI.SetElementVisibility("Image_Hermes_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Hermes_Active",   false)
        UI.SetElementVisibility("Image_Hermes_Inactive", false)
    end

    -- Ares (derecha)
    if hasAres then
        local isActive = (activeMask == "Ares")
        UI.SetElementVisibility("Image_Ares_Active",   isActive)
        UI.SetElementVisibility("Image_Ares_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Ares_Active",   false)
        UI.SetElementVisibility("Image_Ares_Inactive", false)
    end

    -- Actualizar tamaños/posición de los fondos según la máscara activa
    RefreshMaskBackgrounds(activeMask)
end

-- ─── API pública
function ForceRefreshHUD()
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        currentDisplayHealth  = p.health
        currentDisplayDamage  = p.health
        currentDisplayStamina = p.stamina
        RefreshHealthBar(p.health)
        RefreshStaminaBar(p.stamina)
    else
        currentDisplayHealth  = 100.0
        currentDisplayDamage  = 100.0
        currentDisplayStamina = 100.0
        RefreshHealthBar(100)
        RefreshStaminaBar(100)
    end

    local potions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.potionCount or 0
    local berserkPotions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.berserkCount or 0

    RefreshPotionUI(potions, berserkPotions)

    local hasHermes = (_G._MaskState_Hermes == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Hermes == true)
    local hasAres   = (_G._MaskState_Ares   == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Ares == true)
    local hasApolo  = (_G._MaskState_Apolo  == true) or (_G._UnlockedMasks and (_G._UnlockedMasks.Apolo == true or _G._UnlockedMasks.Apollo == true))

    local activeMask = _G._PlayerController_currentMask or ""

    RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)

    prevHasHermes  = hasHermes
    prevHasAres    = hasAres
    prevHasApolo   = hasApolo
    prevActiveMask = activeMask
end
_G.ForceRefreshHUD = ForceRefreshHUD

local saveIconTimer = 0.0

function _G.ShowSaveIcon()
    UI.SetElementVisibility("SaveIconContainer", true)
    saveIconTimer = 2.0
end

function Start(self)
    myCanvas = self.gameObject:GetComponent("Canvas")
    ForceRefreshHUD()
end

function Update(self, dt)
    if not myCanvas or myCanvas:GetCurrentXAML() ~= "HUD.xaml" then
        return
    end

    -- Barras
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        RefreshHealthBar(p.health, dt)
        RefreshStaminaBar(p.stamina, dt)
    end

    -- Pociones
    local potions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.potionCount or 0
    local berserkPotions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.berserkCount or 0
    RefreshPotionUI(potions, berserkPotions)

    -- Máscaras
    local hasHermes = (_G._MaskState_Hermes == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Hermes == true)
    local hasAres   = (_G._MaskState_Ares   == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Ares == true)
    local hasApolo  = (_G._MaskState_Apolo  == true) or (_G._UnlockedMasks and (_G._UnlockedMasks.Apolo == true or _G._UnlockedMasks.Apollo == true))

    local activeMask = _G._PlayerController_currentMask or ""

    if hasHermes ~= prevHasHermes or hasAres ~= prevHasAres
       or hasApolo ~= prevHasApolo or activeMask ~= prevActiveMask then
        RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)
        prevHasHermes  = hasHermes
        prevHasAres    = hasAres
        prevHasApolo   = hasApolo
        prevActiveMask = activeMask
    end

    if saveIconTimer > 0 then
        saveIconTimer = saveIconTimer - dt
        if saveIconTimer <= 0 then
            UI.SetElementVisibility("SaveIconContainer", false)
        end
    end
end