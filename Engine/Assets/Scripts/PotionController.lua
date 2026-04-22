-- PotionController.lua
_G.PotionSystem = nil

local POTION_HEAL_TOTAL   = 30.0
local POTION_HEAL_RATE    = 30.0
local POTION_COOLDOWN_MAX = 0.5
local BERSERK_DURATION    = 10.0

local potionHealing       = false
local potionHealRemaining = 0.0
local potionCooldown      = 0.0
local berserkActiveTimer  = 0.0

public = {
    potionCount = 2,
    berserkCount = 2
}

function Start(self)
    _G.PotionSystem = self
    self.public.potionCount = 2
    self.public.berserkCount = 2
end

function ResetPotions(self)
    self.public.potionCount = 2
    self.public.berserkCount = 2
    potionHealing = false
    potionHealRemaining = 0.0
    potionCooldown = 0.0
    berserkActiveTimer = 0.0
end

function Update(self, dt)
    if potionCooldown > 0 then
        potionCooldown = potionCooldown - dt
    end

    -- Input para usar poción
    if (Input.GetKeyDown("3") or Input.GetGamepadButtonDown("DPadDown")) and potionCooldown <= 0 then
        if self.public.potionCount > 0 and _G.PlayerInstance and _G.PlayerInstance.public.health < 100 and not potionHealing then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.potionCount = self.public.potionCount - 1
                potionHealing = true
                potionHealRemaining = POTION_HEAL_TOTAL
                potionCooldown = POTION_COOLDOWN_MAX
                Engine.Log("[PotionSystem] Pocion usada. Restantes: " .. self.public.potionCount)
            end
        end
    end

    -- Input para usar poción Berserk (Flecha Izquierda mando / Tecla 4 teclado)
    if (Input.GetGamepadButtonDown("DPadLeft") or Input.GetKeyDown("4")) and potionCooldown <= 0 then
        if self.public.berserkCount > 0 and berserkActiveTimer <= 0 and _G.PlayerInstance then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.berserkCount = self.public.berserkCount - 1
                berserkActiveTimer = BERSERK_DURATION
                potionCooldown = POTION_COOLDOWN_MAX
                _G.PlayerInstance.public.berserkActive = true
                _G.PlayerInstance.public.stamina = 100.0 -- Recarga la stamina al máximo inmediatamente
                Engine.Log("[PotionSystem] Pocion Berserk usada. Restantes: " .. self.public.berserkCount)
            end
        end
    end

    -- Lógica de duración de Berserk
    if berserkActiveTimer > 0 then
        berserkActiveTimer = berserkActiveTimer - dt
        if berserkActiveTimer <= 0 and _G.PlayerInstance then
            _G.PlayerInstance.public.berserkActive = false
            Engine.Log("[PotionSystem] Berserk terminado.")
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