-- BossBarController.lua
--
-- This script manages the BossBar.xaml UI.
-- Attach this script to a Canvas GameObject in your scene.

-- Define the maximum width of the health bar fill in pixels.
-- This value might need adjustment based on the actual UI scaling and asset size in BossBar.xaml.
local BOSS_BAR_MAX_WIDTH = 500.0

local canvasComponent = nil
local bossName = "Aquiles" -- Default boss name, can be overridden by public.bossName

public = {
    xamlPath = "UI/BossBar.xaml", -- Path to the XAML file
    bossName = "Aquiles",         -- Name of the boss to display on the bar
    barMaxWidth = BOSS_BAR_MAX_WIDTH, -- Max width for the health fill (can be adjusted in inspector)
}

-- Global functions that other scripts (like EnemyBossAquiles2.lua) will call.
-- Initialized to dummy functions to prevent errors if this script loads later.
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

    -- Expose the control functions globally
    _G.BossBar_SetVisibility = function(isVisible)
        self:SetVisibility(isVisible)
    end
    _G.BossBar_RefreshHealth = function(currentHp, maxHp)
        self:RefreshHealth(currentHp, maxHp)
    end

    -- Set initial state
    self:SetVisibility(false) -- Start hidden
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