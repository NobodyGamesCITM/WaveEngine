local HEALTH_BAR_MAX_WIDTH  = 334.0
local STAMINA_BAR_MAX_WIDTH = 251.0

local currentDisplayHealth  = 100.0
local currentDisplayDamage  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0
local staminaPulseTimer = 0.0
local DAMAGE_LERP_SPEED = 2.5

local prevHasHermes  = false
local prevHasAres    = false
local prevHasApolo   = false
local prevActiveMask = ""
local myCanvas = nil

-- ─── Tamaños de iconos: activo vs inactivo
local MASK_ICON_SIZE = {
    apollo = { active = 75, inactive = 27 },
    hermes = { active = 75, inactive = 27 },
    ares   = { active = 75, inactive = 27 },
}

-- ─── Helpers
local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

-- ─── Márgenes de los grupos de máscara (background + icono juntos)
local MASK_BG_MARGINS = {
    [""] = {
        apollo = {  28,  80, 124,   0 },
        hermes = {  76,  26,  76,  54 },
        ares   = { 124,  80,  28,   0 },
    },
    ["Hermes"] = {
        apollo = {   0,  80, 150,   0 },
        hermes = {  38,  -5,  38,  15 },
        ares   = { 150,  80,   0,   0 },
    },
    ["Ares"] = {
        apollo = {  24,  50, 128,  30 },
        hermes = {  71,  -1,  80,  81 },
        ares   = {  82,  44,   4, -34 },
    },
    ["Apolo"] = {
        apollo = {  -4,  44,  90, -34 },
        hermes = {  71,  -1,  80,  81 },
        ares   = { 115,  45,  36,  35 },
    },
}

-- ─── Mover los grupos y escalar iconos según estado activo/inactivo
local function RefreshMaskBackgrounds(activeMask)
    local key = activeMask or ""
    local margins = MASK_BG_MARGINS[key] or MASK_BG_MARGINS[""]

    local a = margins.apollo
    UI.SetElementMargin("ApolloMaskGroup", a[1], a[2], a[3], a[4])

    local h = margins.hermes
    UI.SetElementMargin("HermesMaskGroup", h[1], h[2], h[3], h[4])

    local r = margins.ares
    UI.SetElementMargin("AresMaskGroup", r[1], r[2], r[3], r[4])
end

local function ApplyMaskIconSizes(activeMask)
    -- Apollo
    local apolloSize = (activeMask == "Apolo") and MASK_ICON_SIZE.apollo.active or MASK_ICON_SIZE.apollo.inactive
    UI.SetElementWidth ("Image_Apolo_Active",   apolloSize)
    UI.SetElementHeight("Image_Apolo_Active",   apolloSize)
    UI.SetElementWidth ("Image_Apolo_Inactive", apolloSize)
    UI.SetElementHeight("Image_Apolo_Inactive", apolloSize)

    -- Hermes
    local hermesSize = (activeMask == "Hermes") and MASK_ICON_SIZE.hermes.active or MASK_ICON_SIZE.hermes.inactive
    UI.SetElementWidth ("Image_Hermes_Active",   hermesSize)
    UI.SetElementHeight("Image_Hermes_Active",   hermesSize)
    UI.SetElementWidth ("Image_Hermes_Inactive", hermesSize)
    UI.SetElementHeight("Image_Hermes_Inactive", hermesSize)

    -- Ares
    local aresSize = (activeMask == "Ares") and MASK_ICON_SIZE.ares.active or MASK_ICON_SIZE.ares.inactive
    UI.SetElementWidth ("Image_Ares_Active",   aresSize)
    UI.SetElementHeight("Image_Ares_Active",   aresSize)
    UI.SetElementWidth ("Image_Ares_Inactive", aresSize)
    UI.SetElementHeight("Image_Ares_Inactive", aresSize)
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
        if dt then staminaPulseTimer = staminaPulseTimer + dt end
        local alpha = 0.75 + 0.25 * math.sin(staminaPulseTimer * 12.0)
        UI.SetElementOpacity("StaminaBarContainer", alpha)
    else
        staminaPulseTimer = 0
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

-- ─── Máscaras: visibilidad + tamaño + posición de grupos
local function RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)

    -- Apollo
    if hasApolo then
        local isActive = (activeMask == "Apolo")
        UI.SetElementVisibility("Image_Apolo_Active",   isActive)
        UI.SetElementVisibility("Image_Apolo_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Apolo_Active",   false)
        UI.SetElementVisibility("Image_Apolo_Inactive", false)
    end

    -- Hermes
    if hasHermes then
        local isActive = (activeMask == "Hermes")
        UI.SetElementVisibility("Image_Hermes_Active",   isActive)
        UI.SetElementVisibility("Image_Hermes_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Hermes_Active",   false)
        UI.SetElementVisibility("Image_Hermes_Inactive", false)
    end

    -- Ares
    if hasAres then
        local isActive = (activeMask == "Ares")
        UI.SetElementVisibility("Image_Ares_Active",   isActive)
        UI.SetElementVisibility("Image_Ares_Inactive", not isActive)
    else
        UI.SetElementVisibility("Image_Ares_Active",   false)
        UI.SetElementVisibility("Image_Ares_Inactive", false)
    end

    -- Tamaños según activa/inactiva
    ApplyMaskIconSizes(activeMask)

    -- Mover grupos (icono centrado dentro automáticamente)
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

    -- Cambio de máscara por D-Pad / teclas de flecha
    if _G.PlayerInstance and not _G._PlayerController_isDead and not _G.PlayerInAnim then
        local targetMask = nil
        if Input.GetGamepadButtonDown("DPadLeft") or Input.GetKeyDown("Left") then
            if _G._UnlockedMasks and (_G._UnlockedMasks.Apollo or _G._UnlockedMasks.Apolo) then targetMask = "Apolo" end
        elseif Input.GetGamepadButtonDown("DPadUp") or Input.GetKeyDown("Up") then
            if _G._UnlockedMasks and _G._UnlockedMasks.Hermes then targetMask = "Hermes" end
        elseif Input.GetGamepadButtonDown("DPadRight") or Input.GetKeyDown("Right") then
            if _G._UnlockedMasks and _G._UnlockedMasks.Ares then targetMask = "Ares" end
        elseif Input.GetGamepadButtonDown("DPadDown") or Input.GetKeyDown("Down") then
            targetMask = "NoMask"
        end

        if targetMask and _G.PlayerInstance.EquipMask then
            local current = _G._PlayerController_currentMask or ""
            local check = (targetMask == "NoMask") and "" or targetMask
            if current ~= check then
                _G.PlayerInstance:EquipMask(targetMask)
            end
        end
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

    -- Máscaras (solo actualizamos si algo cambió)
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

    -- Icono de guardado
    if saveIconTimer > 0 then
        saveIconTimer = saveIconTimer - dt
        if saveIconTimer <= 0 then
            UI.SetElementVisibility("SaveIconContainer", false)
        end
    end
end