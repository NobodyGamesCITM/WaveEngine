local BOSS_BAR_MAX_WIDTH = 500.0

local canvasComponent = nil
local bossName = "Aquiles" 

public = {
    xamlPath = "UI/BossBar.xaml", 
    bossName = "Aquiles",         
    barMaxWidth = BOSS_BAR_MAX_WIDTH, 
}

_G.BossBar_SetVisibility = _G.BossBar_SetVisibility or function() end
_G.BossBar_RefreshHealth = _G.BossBar_RefreshHealth or function() end

function Start(self)
    canvasComponent = self.gameObject:GetComponent("Canvas")

    if canvasComponent then
        canvasComponent:LoadXAML(self.public.xamlPath)
        Engine.Log("[BossBarController] Loaded XAML: " .. self.public.xamlPath)
    else
        Engine.Log("[BossBarController] ERROR: No Canvas component found on this GameObject.")
        return
    end

    _G.BossBar_SetVisibility = function(isVisible)
        self:SetVisibility(isVisible)
    end
    _G.BossBar_RefreshHealth = function(currentHp, maxHp)
        self:RefreshHealth(currentHp, maxHp)
    end

    self:SetVisibility(false) 
    bossName = self.public.bossName
    BOSS_BAR_MAX_WIDTH = self.public.barMaxWidth
    Engine.Log("[BossBarController] Initialized. Boss: " .. bossName .. ", Max Bar Width: " .. BOSS_BAR_MAX_WIDTH)
end

function SetVisibility(self, isVisible)
    if not canvasComponent then return end
    UI.SetElementVisibility("BossBarViewbox", isVisible)
    UI.SetElementVisibility("BossBarInteriorViewbox", isVisible)
    UI.SetElementVisibility("TextViewbox", isVisible)
end

function RefreshHealth(self, currentHp, maxHp)
    if not canvasComponent then return end
    local clampedHp = math.max(0, math.min(maxHp, currentHp))
    local healthPercent = clampedHp / maxHp

    UI.SetElementWidth("InteriorImage", healthPercent * BOSS_BAR_MAX_WIDTH)
    UI.SetElementText("Text", bossName .. " " .. math.floor(clampedHp) .. "/" .. math.floor(maxHp))
end