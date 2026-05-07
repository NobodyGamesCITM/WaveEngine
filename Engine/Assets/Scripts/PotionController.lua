_G.PotionSystem = nil

-- CONFIGURACIÓN GENERAL
local POTION_HEAL_TOTAL   = 30.0
local POTION_HEAL_RATE    = 30.0
local POTION_COOLDOWN_MAX = 0.5
local BERSERK_DURATION    = 10.0

local FADE_TIME           = 0.2    
local MAX_ALPHA           = 160/255
local BASE_PULSE_FREQ     = 0.6  
local END_PULSE_FREQ      = 1.5  

local HEAL_FADE_IN        = 0.4   
local HEAL_HOLD           = 0.8    
local HEAL_FADE_OUT       = 0.8    
local HEAL_TOTAL_TIME     = HEAL_FADE_IN + HEAL_HOLD + HEAL_FADE_OUT

local HEAL_PULSE_FREQ     = 0.7   
local HEAL_ALPHA_MIN      = 0.15  
local HEAL_ALPHA_MAX      = 0.45  
local HEAL_SMOOTHNESS     = 0.75  

-- VARIABLES DE ESTADO
local potionHealing       = false
local potionHealRemaining = 0.0
local potionCooldown      = 0.0
local berserkActiveTimer  = 0.0
local berserkWasActive    = false
local berserkPulseTimer   = 0.0

local healVigTimer        = 0.0
local healWasActive       = false
local healElapsed         = 0.0

local postProcess = nil

public = {
    potionCount = 2,
    berserkCount = 2
}

-- FUNCIONES MATEMÁTICAS
local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

function Start(self)
    _G.PotionSystem = self
    self.public.potionCount = 2
    self.public.berserkCount = 2

    local camObj = GameObject.Find("MainCamera")
    if camObj then
        postProcess = camObj:GetComponent("PostProcessing")
    end
end

function ResetPotions(self)
    self.public.potionCount  = 2
    self.public.berserkCount = 2
    potionHealing       = false
    potionHealRemaining = 0.0
    potionCooldown      = 0.0
    berserkActiveTimer  = 0.0
    berserkPulseTimer   = 0.0
    berserkWasActive    = false
    healVigTimer        = 0.0
    healElapsed         = 0.0
    healWasActive       = false

    if postProcess then
        postProcess:SetVignetteEnabled(false)
        postProcess:SetRadialBlurEnabled(false)
        postProcess:SetChromaticAberrationEnabled(false)
    end
end

local function UpdateBerserkVignette(dt)
    if not postProcess then return end
    local isActive = berserkActiveTimer > 0
    if isActive then
        local totalTime = BERSERK_DURATION
        local elapsed   = totalTime - berserkActiveTimer
        local progress  = elapsed / totalTime 
        berserkPulseTimer = berserkPulseTimer + dt

        local fadeAlpha = 1.0
        if elapsed < FADE_TIME then fadeAlpha = elapsed / FADE_TIME
        elseif berserkActiveTimer < FADE_TIME then fadeAlpha = berserkActiveTimer / FADE_TIME end

        local freq = BASE_PULSE_FREQ
        if progress > 0.7 then
            local accel = (progress - 0.7) / 0.3
            freq = BASE_PULSE_FREQ + (accel * (END_PULSE_FREQ - BASE_PULSE_FREQ))
        end
        
        local pulseFactor = (math.sin(berserkPulseTimer * freq * math.pi * 2.0) + 1.0) * 0.5
        local targetAlpha = (0.2 + (pulseFactor * (MAX_ALPHA - 0.2))) * fadeAlpha

        local hitActive = (_G.PlayerInstance and _G._hitVigActive) or false
        if not hitActive then
            postProcess:SetVignetteEnabled(true)
            postProcess:SetVignetteIntensity(0.0)
            postProcess:SetVignetteSmoothness(0.65)
            postProcess:SetVignetteColor(0.0, 0.8, 0.8, targetAlpha)
        end

        postProcess:SetRadialBlurEnabled(true)
        postProcess:SetRadialBlurIntensity(0.30 * fadeAlpha)
        postProcess:SetChromaticAberrationEnabled(true)
        postProcess:SetChromaticAberrationIntensity(2.25 * fadeAlpha)
        berserkWasActive = true
    elseif berserkWasActive then
        postProcess:SetVignetteEnabled(false)
        postProcess:SetRadialBlurEnabled(false)
        postProcess:SetChromaticAberrationEnabled(false)
        berserkWasActive = false
    end
end

local function UpdateHealVignette(dt)
    if not postProcess then return end

    local hitActive     = (_G.PlayerInstance and _G._hitVigActive) or false
    local berserkActive = berserkActiveTimer > 0

    if healVigTimer > 0 then
        healVigTimer  = healVigTimer - dt
        healElapsed   = healElapsed + dt

        local envelope = 0.0
        if healElapsed < HEAL_FADE_IN then
            envelope = smoothstep(healElapsed / HEAL_FADE_IN)
        elseif healElapsed < HEAL_FADE_IN + HEAL_HOLD then
            envelope = 1.0
        else
            local t = (healElapsed - HEAL_FADE_IN - HEAL_HOLD) / HEAL_FADE_OUT
            envelope = 1.0 - smoothstep(t)
        end

        local pulse = (math.sin(healElapsed * HEAL_PULSE_FREQ * math.pi * 2.0) + 1.0) * 0.5

        local finalAlpha = (HEAL_ALPHA_MIN + (HEAL_ALPHA_MAX - HEAL_ALPHA_MIN) * pulse) * envelope

        if not hitActive and not berserkActive then
            postProcess:SetVignetteEnabled(true)
            postProcess:SetVignetteIntensity(0.25) 
            postProcess:SetVignetteSmoothness(HEAL_SMOOTHNESS)
            postProcess:SetVignetteColor(0.0, 0.7, 0.1, finalAlpha)
        end

        healWasActive = true
    elseif healWasActive then
        if not hitActive and not berserkActive then
            postProcess:SetVignetteEnabled(false)
        end
        healWasActive = false
        healElapsed   = 0.0
    end
end

function Update(self, dt)
    if potionCooldown > 0 then potionCooldown = potionCooldown - dt end

    -- Input Curación
    if (Input.GetKeyDown("3") or Input.GetGamepadButtonDown("DPadDown")) and potionCooldown <= 0 then
        if self.public.potionCount > 0 and _G.PlayerInstance and _G.PlayerInstance.public.health < 100 and not potionHealing then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.potionCount  = self.public.potionCount - 1
                potionHealing            = true
                potionHealRemaining      = POTION_HEAL_TOTAL
                potionCooldown           = POTION_COOLDOWN_MAX
                healVigTimer             = HEAL_TOTAL_TIME
                healElapsed              = 0.0
            end
        end
    end

    -- Input Berserk
    if (Input.GetGamepadButtonDown("DPadLeft") or Input.GetKeyDown("4")) and potionCooldown <= 0 then
        if self.public.berserkCount > 0 and berserkActiveTimer <= 0 and _G.PlayerInstance then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.berserkCount = self.public.berserkCount - 1
                berserkActiveTimer = BERSERK_DURATION
                berserkPulseTimer = 0.0
                potionCooldown = POTION_COOLDOWN_MAX
                _G.PlayerInstance.public.berserkActive = true
                _G.PlayerInstance.public.stamina = 100.0
            end
        end
    end

    if berserkActiveTimer > 0 then
        berserkActiveTimer = berserkActiveTimer - dt
        if berserkActiveTimer <= 0 then
            berserkActiveTimer = 0
            if _G.PlayerInstance then _G.PlayerInstance.public.berserkActive = false end
        end
    end

    UpdateBerserkVignette(dt)
    UpdateHealVignette(dt)

    -- Lógica de curación
    if potionHealing and _G.PlayerInstance then
        local healThisTick = POTION_HEAL_RATE * dt
        local currentHP    = _G.PlayerInstance.public.health
        local actualHeal   = math.min(healThisTick, potionHealRemaining)
        local maxHeal      = math.min(actualHeal, 100.0 - currentHP)

        _G.PlayerInstance.public.health = currentHP + maxHeal
        potionHealRemaining = potionHealRemaining - actualHeal

        if potionHealRemaining <= 0 or _G.PlayerInstance.public.health >= 100.0 then
            potionHealing = false
            potionHealRemaining = 0.0
        end
    end
end