local BOSS_BAR_MAX_WIDTH_HEALTH = 748.0   
local BOSS_BAR_MAX_WIDTH_SHIELD = 674.0  

local canvasComponent = nil

local currentOpacity = 0.0
local targetOpacity  = 0.0
local FADE_SPEED     = 3.0

local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

local currentDisplayHealthWidth = BOSS_BAR_MAX_WIDTH_HEALTH
local currentDisplayShieldWidth = BOSS_BAR_MAX_WIDTH_SHIELD

public = {
    xamlPath    = "UI/BossBar.xaml",
    fadeSpeed   = FADE_SPEED,
    lerpSpeed   = 10.0,
}

_G.BossBar_SetVisibility = _G.BossBar_SetVisibility or function() end
_G.BossBar_RefreshHealth = _G.BossBar_RefreshHealth or function() end
_G.BossBar_RefreshShield = _G.BossBar_RefreshShield or function() end
_G.BossBar_ResetToFull   = _G.BossBar_ResetToFull   or function() end

local targetHealthWidth = BOSS_BAR_MAX_WIDTH_HEALTH
local targetShieldWidth = BOSS_BAR_MAX_WIDTH_SHIELD
local knownMaxHp  = 300

local function ApplyOpacity()
    if not canvasComponent then return end
    canvasComponent:SetOpacity(currentOpacity)
end

local function SetVisible(isVisible)
    targetOpacity = isVisible and 1.0 or 0.0
end

local function RefreshBar(currentHp, maxHp)
    if not maxHp or maxHp <= 0 then return end
    knownMaxHp = maxHp
    local clampedHp     = math.max(0, math.min(maxHp, currentHp))
    local healthPercent = clampedHp / maxHp
    targetHealthWidth   = healthPercent * BOSS_BAR_MAX_WIDTH_HEALTH
end

local function RefreshShieldBar(currentShield, maxShield)
    if not maxShield or maxShield <= 0 then return end
    local clamped     = math.max(0, math.min(maxShield, currentShield))
    local percent     = clamped / maxShield
    targetShieldWidth = percent * BOSS_BAR_MAX_WIDTH_SHIELD
end

local function ResetBarToFull(maxHp)
    if not maxHp or maxHp <= 0 then return end
    knownMaxHp                = maxHp
    targetHealthWidth         = BOSS_BAR_MAX_WIDTH_HEALTH
    targetShieldWidth         = BOSS_BAR_MAX_WIDTH_SHIELD
    currentDisplayHealthWidth = BOSS_BAR_MAX_WIDTH_HEALTH
    currentDisplayShieldWidth = BOSS_BAR_MAX_WIDTH_SHIELD
    UI.SetElementWidth("HealthBar",      BOSS_BAR_MAX_WIDTH_HEALTH)
    UI.SetElementWidth("ShieldBar_Grid", BOSS_BAR_MAX_WIDTH_SHIELD)
end

function Start(self)
    canvasComponent = self.gameObject:GetComponent("Canvas")

    if canvasComponent then
        canvasComponent:LoadXAML(self.public.xamlPath)
        Engine.Log("[BossBarController] Loaded XAML: " .. self.public.xamlPath)
    else
        Engine.Log("[BossBarController] ERROR: No Canvas component found.")
        return
    end

    FADE_SPEED = self.public.fadeSpeed or 3.0

    currentDisplayHealthWidth = BOSS_BAR_MAX_WIDTH_HEALTH
    currentDisplayShieldWidth = BOSS_BAR_MAX_WIDTH_SHIELD
    targetHealthWidth         = BOSS_BAR_MAX_WIDTH_HEALTH
    targetShieldWidth         = BOSS_BAR_MAX_WIDTH_SHIELD

    _G.BossBar_SetVisibility = function(isVisible) SetVisible(isVisible) end
    _G.BossBar_RefreshHealth = function(currentHp, maxHp) RefreshBar(currentHp, maxHp) end
    _G.BossBar_RefreshShield = function(currentShield, maxShield) RefreshShieldBar(currentShield, maxShield) end
    _G.BossBar_ResetToFull   = function(maxHp) ResetBarToFull(maxHp) end

    currentOpacity = 0.0
    targetOpacity  = 0.0
    ApplyOpacity()
    UI.SetElementWidth("HealthBar",      BOSS_BAR_MAX_WIDTH_HEALTH)
    UI.SetElementWidth("ShieldBar_Grid", BOSS_BAR_MAX_WIDTH_SHIELD)

    Engine.Log("[BossBarController] Ready.")
end

function Update(self, dt)
    if not canvasComponent then return end

    if math.abs(currentOpacity - targetOpacity) > 0.001 then
        local dir      = targetOpacity > currentOpacity and 1 or -1
        currentOpacity = currentOpacity + dir * FADE_SPEED * dt
        currentOpacity = math.max(0.0, math.min(1.0, currentOpacity))
        ApplyOpacity()
    end

    if math.abs(currentDisplayHealthWidth - targetHealthWidth) > 0.1 then
        currentDisplayHealthWidth = Lerp(currentDisplayHealthWidth, targetHealthWidth, dt * (self.public.lerpSpeed or 10.0))
        UI.SetElementWidth("HealthBar", currentDisplayHealthWidth)
    end

    if math.abs(currentDisplayShieldWidth - targetShieldWidth) > 0.1 then
        currentDisplayShieldWidth = Lerp(currentDisplayShieldWidth, targetShieldWidth, dt * (self.public.lerpSpeed or 10.0))
        UI.SetElementWidth("ShieldBar_Grid", currentDisplayShieldWidth)
    end
end