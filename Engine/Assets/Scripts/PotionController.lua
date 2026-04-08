-- PotionController.lua
_G.PotionSystem = nil

local POTION_HEAL_TOTAL   = 30.0
local POTION_HEAL_RATE    = 30.0
local POTION_COOLDOWN_MAX = 0.5

local potionHealing       = false
local potionHealRemaining = 0.0
local potionCooldown      = 0.0

public = {
    potionCount = 2
}

function Start(self)
    _G.PotionSystem = self
    self.public.potionCount = 2
end

function ResetPotions(self)
    self.public.potionCount = 2
    potionHealing = false
    potionHealRemaining = 0.0
    potionCooldown = 0.0
end

function Update(self, dt)
    if potionCooldown > 0 then
        potionCooldown = potionCooldown - dt
    end

    -- Input para usar poción
    if Input.GetKey("3") or Inout.GetGamepadButton("DPadDown") and potionCooldown <= 0 then
        if self.public.potionCount > 0 and _G.PlayerInstance and _G.PlayerInstance.public.health < 100 and not potionHealing then
            self.public.potionCount = self.public.potionCount - 1
            potionHealing = true
            potionHealRemaining = POTION_HEAL_TOTAL
            potionCooldown = POTION_COOLDOWN_MAX
            Engine.Log("[PotionSystem] Pocion usada. Restantes: " .. self.public.potionCount)
        end
    end

    -- Lógica de curación progresiva
    if potionHealing and _G.PlayerInstance then
        local healThisTick = POTION_HEAL_RATE * dt
        local currentHP = _G.PlayerInstance.public.health
        local actualHeal = math.min(healThisTick, potionHealRemaining)
        local maxHeal = math.min(actualHeal, 100.0 - currentHP)

        _G.PlayerInstance.public.health = currentHP + maxHeal
        potionHealRemaining = potionHealRemaining - actualHeal

        if potionHealRemaining <= 0 or _G.PlayerInstance.public.health >= 100.0 then
            potionHealing = false
            potionHealRemaining = 0.0
        end
    end
end