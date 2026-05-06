local BOSS_BAR_MAX_WIDTH = 418

local canvasComponent = nil

-- Fade state
local currentOpacity = 0.0
local targetOpacity  = 0.0
local FADE_SPEED     = 3.0

-- Lerp igual que el HUD del jugador
local function Lerp(a, b, t)
    return a + (b - a) * math.min(1, t)
end

local currentDisplayWidth = BOSS_BAR_MAX_WIDTH

public = {
    xamlPath    = "UI/BossBar.xaml",
    barMaxWidth = 418.0,
    fadeSpeed   = FADE_SPEED,
    lerpSpeed   = 10.0,
}

_G.BossBar_SetVisibility = _G.BossBar_SetVisibility or function() end
_G.BossBar_RefreshHealth = _G.BossBar_RefreshHealth or function() end


local targetWidth = BOSS_BAR_MAX_WIDTH  -- el ancho hacia el que lerpeamos

local function ApplyOpacity()
    if not canvasComponent then return end
    canvasComponent:SetOpacity(currentOpacity)
end

local function SetVisible(isVisible)
    targetOpacity = isVisible and 1.0 or 0.0
end

local function RefreshBar(currentHp, maxHp)
    if not maxHp or maxHp <= 0 then return end
    local clampedHp     = math.max(0, math.min(maxHp, currentHp))
    local healthPercent = clampedHp / maxHp
    targetWidth = healthPercent * BOSS_BAR_MAX_WIDTH
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

    BOSS_BAR_MAX_WIDTH    = self.public.barMaxWidth or 418.0
    FADE_SPEED            = self.public.fadeSpeed   or 3.0
    currentDisplayWidth   = BOSS_BAR_MAX_WIDTH
    targetWidth           = BOSS_BAR_MAX_WIDTH

    _G.BossBar_SetVisibility = function(isVisible) SetVisible(isVisible) end
    _G.BossBar_RefreshHealth = function(currentHp, maxHp) RefreshBar(currentHp, maxHp) end

    currentOpacity = 0.0
    targetOpacity  = 0.0
    ApplyOpacity()
    UI.SetElementWidth("BossBarFill", BOSS_BAR_MAX_WIDTH)

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

    if math.abs(currentDisplayWidth - targetWidth) > 0.1 then
        currentDisplayWidth = Lerp(currentDisplayWidth, targetWidth, dt * (self.public.lerpSpeed or 10.0))
        UI.SetElementWidth("BossBarFill", currentDisplayWidth)
    end
end