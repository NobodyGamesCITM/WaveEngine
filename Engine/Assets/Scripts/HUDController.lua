local HEALTH_BAR_MAX_WIDTH  = 334.0
local STAMINA_BAR_MAX_WIDTH = 251.0

local currentDisplayHealth  = 100.0
local currentDisplayStamina = 100.0
local LERP_SPEED = 10.0

local ALL_MASK_TYPES_ORDER = { "Hermes", "Apolo", "Ares" }
local MASK_NAMES = { "Hermes", "Ares", "Apolo" }

local obtainedOrder = {}

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

local myCanvas = nil

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
        UI.SetElementVisibility("Berserk" .. i,         slotVisible and i <= (berserkPotions or 0))
        UI.SetElementVisibility("UsedBerserk" .. i,     slotVisible and i > (berserkPotions or 0))
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

    if not activeSlotMask and activeMask ~= "" then
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
    local currentLevel = _G.CurrentLevel or ""

    if currentLevel ~= "Level1" then
        UI.SetElementVisibility("MissionGrid", false)
        return
    end

    local varName      = _G.MissionVarName or "keysCollected"
    local currentCount = _G[varName] or 0
    local total        = _G.TotalStatuesToDestroy or 3

    local countInt = math.floor(currentCount)
    local totalInt = math.floor(total)

    if totalInt <= 0 then
        UI.SetElementVisibility("MissionGrid", false)
        return
    end

    UI.SetElementVisibility("MissionGrid", true)

    UI.SetElementText("MissionText", tostring(countInt) .. "/" .. tostring(totalInt))

    if countInt ~= lastDisplayedCount then
        if lastDisplayedCount ~= -1 then
            if myCanvas then
                myCanvas:PlayStoryboard("MissionExpand")
                myCanvas:PlayStoryboard("MissionCountBump")
            end
            missionVisible   = true
            missionHideTimer = MISSION_HIDE_DELAY
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

    local hasHermes = (_G._MaskState_Hermes == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Hermes == true)
    local hasAres   = (_G._MaskState_Ares   == true) or (_G._UnlockedMasks and _G._UnlockedMasks.Ares == true)
    local hasApolo  = (_G._MaskState_Apolo  == true) or (_G._UnlockedMasks and (_G._UnlockedMasks.Apolo == true or _G._UnlockedMasks.Apollo == true))

    local activeMask = _G._PlayerController_currentMask or ""

    RefreshMaskUI(hasHermes, hasAres, hasApolo, activeMask)

    prevHasHermes  = hasHermes
    prevHasAres    = hasAres
    prevHasApolo   = hasApolo
    prevActiveMask = activeMask

    UI.SetElementVisibility("MissionGrid", false)
    lastDisplayedCount = -1
    lastDisplayedTotal = -1
end
_G.ForceRefreshHUD = ForceRefreshHUD

function Start(self)
    myCanvas = self.gameObject:GetComponent("Canvas")
    ForceRefreshHUD()
    missionVisible   = false
    missionHideTimer = 0.0
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

    if missionVisible and missionHideTimer > 0 then
        missionHideTimer = missionHideTimer - dt
        if missionHideTimer <= 0 then
            missionHideTimer = 0
            missionVisible   = false
            if myCanvas then myCanvas:PlayStoryboard("MissionCollapse") end
        end
    end
end
