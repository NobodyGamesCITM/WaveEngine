local HEALTH_BAR_MAX_WIDTH  = 334.0
local STAMINA_BAR_MAX_WIDTH = 251.0

local currentDisplayHealth  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0

local MASK_NAMES = { "Hermes", "Ares", "Apolo" }

local obtainedOrder = {}

-- Cache del estado anterior
local prevHasHermes  = false
local prevHasAres    = false
local prevHasApolo   = false
local prevActiveMask = ""

-- ─── Helpers

local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

local function alreadyTracked(name)
    for _, v in ipairs(obtainedOrder) do
        if v == name then return true end
    end
    return false
end

-- ─── Barras

local function RefreshHealthBar(targetHealth, dt)
    currentDisplayHealth = dt
        and Lerp(currentDisplayHealth, targetHealth, dt * LERP_SPEED)
        or  targetHealth
    local clamped = math.max(0, math.min(100, currentDisplayHealth))
    UI.SetElementWidth("HealthBarContainer", (clamped / 100.0) * HEALTH_BAR_MAX_WIDTH)
end

local function RefreshStaminaBar(targetStamina, dt)
    currentDisplayStamina = dt
        and Lerp(currentDisplayStamina, targetStamina, dt * LERP_SPEED)
        or  targetStamina
    local clamped = math.max(0, math.min(100, currentDisplayStamina))
    UI.SetElementWidth("StaminaBarContainer", (clamped / 100.0) * STAMINA_BAR_MAX_WIDTH)
end

-- ─── Pociones
local function RefreshPotionUI(potions)
    for i = 1, 4 do
        UI.SetElementVisibility("Potion" .. i,     i <= potions)
        UI.SetElementVisibility("UsedPotion" .. i, i > potions)
    end
end

local function RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)
    local hasMap = { Hermes = hasHermes, Ares = hasAres, Apolo = hasApolo }

    -- Registrar máscaras nuevas en orden de llegada
    for _, name in ipairs(MASK_NAMES) do
        if hasMap[name] and not alreadyTracked(name) then
            table.insert(obtainedOrder, name)
        end
    end

    -- Construir lista de slots laterales
    local sideSlots = {}
    for _, name in ipairs(obtainedOrder) do
        if name ~= activeMask then
            table.insert(sideSlots, name)
        end
    end

    -- Asignación final de cada slot
    local slotAssign = {
        Active = (activeMask ~= "" and activeMask or nil),
        Left   = sideSlots[1],
        Right  = sideSlots[2],
    }

    -- Actualizar visibilidad
    for _, prefix in ipairs({ "Active", "Left", "Right" }) do
        local assigned = slotAssign[prefix]
        for _, maskName in ipairs(MASK_NAMES) do
            UI.SetElementVisibility(prefix .. "_" .. maskName, assigned == maskName)
        end
    end
end

-- ─── API pública

function ForceRefreshHUD()
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
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

    local potions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.potionCount or 0
    RefreshPotionUI(potions)

    -- Reset completo del estado de máscaras
    obtainedOrder  = {}
    prevHasHermes  = false
    prevHasAres    = false
    prevHasApolo   = false
    prevActiveMask = ""
    RefreshMaskUI(false, false, false, "")
end
_G.ForceRefreshHUD = ForceRefreshHUD

function Start(self)
    ForceRefreshHUD()
end

function Update(self, dt)
    -- Barras
    if _G.PlayerInstance and _G.PlayerInstance.public then
        local p = _G.PlayerInstance.public
        RefreshHealthBar(p.health, dt)
        RefreshStaminaBar(p.stamina, dt)
    end

    -- Pociones
    local potions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.potionCount or 0
    RefreshPotionUI(potions)

    -- Máscaras
    local hasHermes  = (_G._MaskState_Hermes == true)
    local hasAres    = (_G._MaskState_Ares   == true)
    local hasApolo   = (_G._MaskState_Apolo  == true)
    local activeMask = _G._PlayerController_currentMask or ""

    if hasHermes ~= prevHasHermes or hasAres ~= prevHasAres
       or hasApolo ~= prevHasApolo or activeMask ~= prevActiveMask then
        RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)
        prevHasHermes  = hasHermes
        prevHasAres    = hasAres
        prevHasApolo   = hasApolo
        prevActiveMask = activeMask
    end
end