local HEALTH_BAR_MAX_WIDTH  = 334.0
local STAMINA_BAR_MAX_WIDTH = 251.0

local currentDisplayHealth  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0

local ALL_MASK_TYPES_ORDER = { "Hermes", "Apolo", "Ares" } -- Define a fixed order for cycling and display
local MASK_NAMES = { "Hermes", "Ares", "Apolo" }

local obtainedOrder = {}

-- Cache del estado anterior
local prevHasHermes  = false
local prevHasAres    = false
local prevHasApolo   = false
local prevActiveMask = ""

-- ─── Mission globals
_G.TotalStatuesToDestroy = _G.TotalStatuesToDestroy or 0
_G.MissionVarName        = _G.MissionVarName        or "keysCollected"

local lastDisplayedCount = -1
local lastDisplayedTotal = -1

-- Mission panel animation state
local missionVisible     = false
local missionHideTimer   = 0.0
local MISSION_HIDE_DELAY = 3.0  

-- ─── Helpers
local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
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
local function RefreshPotionUI(potions, berserkPotions)
    for i = 1, 4 do
        UI.SetElementVisibility("Potion" .. i,     i <= potions)
        UI.SetElementVisibility("UsedPotion" .. i, i > potions)
    end
    for i = 1, 4 do
        local slotIndex = i + 4
        UI.SetElementVisibility("Potion" .. slotIndex,     i <= (berserkPotions or 0))
        UI.SetElementVisibility("UsedPotion" .. slotIndex, i > (berserkPotions or 0))
    end
end

-- ─── Máscaras
local function RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)
    local hasMap = { Hermes = hasHermes, Ares = hasAres, Apolo = hasApolo }

    obtainedOrder = {}
    for _, maskType in ipairs(ALL_MASK_TYPES_ORDER) do
        if hasMap[maskType] then
            table.insert(obtainedOrder, maskType)
        end
    end

    if #obtainedOrder == 0 then
        for _, prefix in ipairs({ "Active", "Left", "Right" }) do
            for _, maskName in ipairs(MASK_NAMES) do
                UI.SetElementVisibility(prefix .. "_" .. maskName, false)
            end
        end
        return
    end

    local activeSlotMask = nil
    if activeMask ~= "" then

        for _, m in ipairs(obtainedOrder) do
            if m == activeMask then
                activeSlotMask = activeMask
                break
            end
        end
    end

    if not activeSlotMask then
        activeSlotMask = obtainedOrder[1]
    end

    local sideSlots = {}
    for _, m in ipairs(obtainedOrder) do
        if m ~= activeSlotMask then
            table.insert(sideSlots, m)
        end
    end

    local slotAssign = {
        Active = activeSlotMask,
        Left   = sideSlots[1] or nil,
        Right  = sideSlots[2] or nil,
    }

    for _, prefix in ipairs({ "Active", "Left", "Right" }) do
        local assigned = slotAssign[prefix]
        for _, maskName in ipairs(MASK_NAMES) do
            UI.SetElementVisibility(prefix .. "_" .. maskName, assigned == maskName)
        end
    end
end

-- ─── Mission / Collectibles
local function RefreshMissionUI()
    local currentSceneName = ""
    if _G.GlobalMenuManagerInstance and _G.GlobalMenuManagerInstance.public and _G.GlobalMenuManagerInstance.public.currentScene then
        currentSceneName = _G.GlobalMenuManagerInstance.public.currentScene.value
    end

    if currentSceneName ~= "Level1.scene" then
        UI.SetElementVisibility("MissionGrid", false)
        return
    end
    local varName      = _G.MissionVarName or "keysCollected"
    local currentCount = _G[varName] or 0
    local total        = _G.TotalStatuesToDestroy or 0

    local countInt = math.floor(currentCount)
    local totalInt = math.floor(total)

    UI.SetElementText("MissionText", "Estatuas Destruidas " .. countInt .. "/" .. totalInt)
    
    UI.SetElementVisibility("MissionGrid", true)

    if totalInt > 0 then
        if countInt ~= lastDisplayedCount then

            if lastDisplayedCount ~= -1 then
                UI.PlayStoryboard("MissionExpand")
                UI.PlayStoryboard("MissionCountBump")

                missionVisible     = true
                missionHideTimer   = MISSION_HIDE_DELAY
            end
        end
        lastDisplayedCount = countInt
        lastDisplayedTotal = totalInt
    end
end
_G.HUD_RefreshStatuesDestroyed = RefreshMissionUI

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
    local berserkPotions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.berserkCount or 0

    RefreshPotionUI(potions, berserkPotions)

    -- Reset mask state for a full refresh
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
    lastDisplayedCount = -1
    lastDisplayedTotal = -1
    missionVisible     = false
    missionHideTimer   = 0.0
    
    RefreshMissionUI()
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
    local berserkPotions = (_G.PotionSystem and _G.PotionSystem.public)
                    and _G.PotionSystem.public.berserkCount or 0
    RefreshPotionUI(potions, berserkPotions)

    -- Misión
    RefreshMissionUI()

    -- Máscaras
    local hasHermes  = (_G._MaskState_Hermes == true)
    local hasAres    = (_G._MaskState_Ares   == true)
    local hasApolo   = (_G._MaskState_Apolo  == true)
    local activeMask = _G._PlayerController_currentMask or ""

    -- Solo refrescar si hay cambios
    if hasHermes ~= prevHasHermes or hasAres ~= prevHasAres
       or hasApolo ~= prevHasApolo or activeMask ~= prevActiveMask then
        RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)
        prevHasHermes  = hasHermes
        prevHasAres    = hasAres
        prevHasApolo   = hasApolo
        prevActiveMask = activeMask
    end

    if missionVisible and missionHideTimer > 0 then
        missionHideTimer = missionHideTimer - dt
        if missionHideTimer <= 0 then
            missionHideTimer = 0
            missionVisible   = false
            UI.PlayStoryboard("MissionCollapse")
        end
    end
end