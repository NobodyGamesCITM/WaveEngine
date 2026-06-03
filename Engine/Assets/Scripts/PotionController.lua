_G.PotionSystem = nil

-- CONFIGURACIÓN GENERAL
local POTION_HEAL_TOTAL   = 30.0
local POTION_HEAL_RATE    = 30.0
local POTION_COOLDOWN_MAX = 0.5
local BERSERK_DURATION    = 10.0

local FADE_TIME           = 0.2    
local MAX_ALPHA           = 100/255
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

local LOW_HEALTH_THRESHOLD        = 25.0 
local LOW_HEALTH_PULSE_FREQ       = 0.8 
local LOW_HEALTH_ALPHA_MIN_BASE   = 0.20
local LOW_HEALTH_ALPHA_MAX_BASE   = 0.45
local LOW_HEALTH_SMOOTHNESS       = 0.90 
local LOW_HEALTH_INTENSITY        = 0.35 
local LOW_HEALTH_COLOR_R          = 1.0
local LOW_HEALTH_COLOR_G          = 0.0
local LOW_HEALTH_COLOR_B          = 0.0
local LOW_HEALTH_SETTLE_DURATION  = 5.0

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
local currentHealColor    = {0.0, 0.7, 0.1}

local lowHealthSettleTimer    = 0.0
local lowHealthPulseTimer     = 0.0
local prevPlayerHealth        = 100.0
local berserkVignetteData   = { active = false, color = {0,0,0,0}, intensity = 0, smoothness = 0 }
local healVignetteData      = { active = false, color = {0,0,0,0}, intensity = 0, smoothness = 0 }
local lowHealthVignetteData = { active = false, color = {0,0,0,0}, intensity = 0, smoothness = 0 }

local postProcess = nil
local potionSFX = nil

function _G.TriggerHealVignette()
    healVigTimer = HEAL_TOTAL_TIME
    healElapsed  = 0.0
    currentHealColor = {0.0, 0.7, 0.1} 
end

function _G.TriggerBlueVignette()
    healVigTimer = HEAL_TOTAL_TIME
    healElapsed  = 0.0
    currentHealColor = {0.0, 0.5, 1.0} 
end

public = {
    potionCount = 0,
    berserkCount = 0,
    maxPotions = 0,
    maxBerserk = 0
}

local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

function Start(self)
    _G.PotionSystem = self

    if _G._MidRunTransition then
        self.public.potionCount  = _G._SavedPotionCount or 0
        self.public.berserkCount = _G._SavedBerserkCount or 0
        self.public.maxPotions   = _G._SavedMaxPotions or 0
        self.public.maxBerserk   = _G._SavedMaxBerserk or 0
    else
        self.public.potionCount  = 0
        self.public.berserkCount = 0
        self.public.maxPotions   = 0
        self.public.maxBerserk   = 0
    end

    _G._berserkVigActive = false
    _G._healVigActive    = false

    local camObj = GameObject.Find("MainCamera")
    if camObj then
        postProcess = camObj:GetComponent("PostProcessing")
    end

    local potionSource = GameObject.FindInChildren(self.gameObject, "ItemSource")

    if potionSource then 
        potionSFX = potionSource:GetComponent("Audio Source")
    end
end

function ResetPotions(self)
    self.public.potionCount  = 0
    self.public.berserkCount = 0
    potionHealing       = false
    potionHealRemaining = 0.0
    potionCooldown      = 0.0
    berserkActiveTimer  = 0.0
    berserkPulseTimer   = 0.0
    berserkWasActive    = false
    healVigTimer        = 0.0
    healElapsed         = 0.0
    healWasActive       = false
    lowHealthPulseTimer = 0.0
    lowHealthSettleTimer = 0.0
    prevPlayerHealth    = 100.0
    _G._berserkVigActive = false
    _G._healVigActive    = false

    if postProcess then
        postProcess:SetVignetteEnabled(false)
    end
end

local function UpdateBerserkVignette(dt)
    if not postProcess then return end
    berserkVignetteData.active = false
    _G._berserkVigActive = false

    local isActive = berserkActiveTimer > 0
    if isActive then
        local totalTime = BERSERK_DURATION
        local elapsed   = totalTime - berserkActiveTimer
        local progress  = elapsed / totalTime
        berserkPulseTimer = berserkPulseTimer + dt

        local fadeAlpha = 1.0
        if elapsed < FADE_TIME then
            fadeAlpha = elapsed / FADE_TIME
        elseif berserkActiveTimer < FADE_TIME then
            fadeAlpha = berserkActiveTimer / FADE_TIME
        end

        local freq = BASE_PULSE_FREQ
        if progress > 0.7 then
            local accel = (progress - 0.7) / 0.3
            freq = BASE_PULSE_FREQ + (accel * (END_PULSE_FREQ - BASE_PULSE_FREQ))
        end

        local pulseFactor = (math.sin(berserkPulseTimer * freq * math.pi * 2.0) + 1.0) * 0.5
        local targetAlpha = (0.2 + (pulseFactor * (MAX_ALPHA - 0.2))) * fadeAlpha

        berserkVignetteData.active    = true
        _G._berserkVigActive          = true
        berserkVignetteData.color     = {0.0, 0.8, 0.8, targetAlpha}
        berserkVignetteData.intensity  = 0.32
        berserkVignetteData.smoothness = 0.75

        postProcess:SetRadialBlurEnabled(true)
        postProcess:SetRadialBlurIntensity(0.30 * fadeAlpha)
        postProcess:SetCAEnabled(true)
        postProcess:SetCAIntensity(2.25 * fadeAlpha)
        berserkWasActive = true

        if not Audio.IsEventPlaying("UI_BerserkerPulse") then
            if potionSFX then potionSFX:SelectPlayAudioEvent("UI_BerserkerPulse") end
        end

    elseif berserkWasActive then
        postProcess:SetRadialBlurEnabled(false)
        postProcess:SetCAEnabled(false)
        berserkWasActive = false

        if potionSFX then potionSFX:SelectPlayAudioEvent("UI_BerserkerLow") end
    end
end

local function UpdateHealVignette(dt)
    healVignetteData.active = false
    _G._healVigActive = false

    if healVigTimer > 0 then
        healVigTimer = healVigTimer - dt
        healElapsed  = healElapsed + dt

        local envelope = 0.0
        if healElapsed < HEAL_FADE_IN then
            envelope = smoothstep(healElapsed / HEAL_FADE_IN)
        elseif healElapsed < HEAL_FADE_IN + HEAL_HOLD then
            envelope = 1.0
        else
            local t = (healElapsed - HEAL_FADE_IN - HEAL_HOLD) / HEAL_FADE_OUT
            envelope = 1.0 - smoothstep(t)
        end
        local pulseFactor = (math.sin(healElapsed * HEAL_PULSE_FREQ * math.pi * 2.0) + 1.0) * 0.5
        local finalAlpha = (HEAL_ALPHA_MIN + (HEAL_ALPHA_MAX - HEAL_ALPHA_MIN) * pulseFactor) * envelope

        healVignetteData.active    = true
        _G._healVigActive          = true
        healVignetteData.color     = {currentHealColor[1], currentHealColor[2], currentHealColor[3], finalAlpha}
        healVignetteData.intensity  = 0.25
        healVignetteData.smoothness = HEAL_SMOOTHNESS
        healWasActive = true
    elseif healWasActive then
        healWasActive = false
        healElapsed   = 0.0
    end
end

local function UpdateLowHealthVignette(dt)
    lowHealthVignetteData.active = false
    local playerHealth = (_G.PlayerInstance and _G.PlayerInstance.public and _G.PlayerInstance.public.health) or 100.0

    if playerHealth <= LOW_HEALTH_THRESHOLD and playerHealth > 0 then
        if (prevPlayerHealth - playerHealth) > 0.5 then
            lowHealthSettleTimer = 0.0
        end

        lowHealthPulseTimer = lowHealthPulseTimer + dt
        lowHealthSettleTimer = lowHealthSettleTimer + dt
        local settle = math.min(1.0, lowHealthSettleTimer / LOW_HEALTH_SETTLE_DURATION)
        
        local currentFreq = LOW_HEALTH_PULSE_FREQ * (1.2 - settle * 0.4)
        local pulseFactor = (math.sin(lowHealthPulseTimer * currentFreq * math.pi * 2.0) + 1.0) * 0.5

        local health_norm     = math.max(0, playerHealth / LOW_HEALTH_THRESHOLD)
        local intensity_scale = (0.5 + (1.0 - health_norm) * 0.5) * (1.0 - settle * 0.4)

        local finalAlpha = (LOW_HEALTH_ALPHA_MIN_BASE + (LOW_HEALTH_ALPHA_MAX_BASE - LOW_HEALTH_ALPHA_MIN_BASE) * pulseFactor) * intensity_scale

        lowHealthVignetteData.active    = true
        lowHealthVignetteData.color     = {LOW_HEALTH_COLOR_R, LOW_HEALTH_COLOR_G, LOW_HEALTH_COLOR_B, finalAlpha}
        lowHealthVignetteData.intensity  = LOW_HEALTH_INTENSITY * (1.0 - settle * 0.2)
        lowHealthVignetteData.smoothness = LOW_HEALTH_SMOOTHNESS
    else
        lowHealthPulseTimer = 0.0
        lowHealthSettleTimer = 0.0
    end
    prevPlayerHealth = playerHealth
end

local function ApplyVignetteEffects()
    if not postProcess then return end

    local hitActive = (_G._hitVigActive) or false
    if hitActive then return end

    if healVignetteData.active then
        postProcess:SetVignetteEnabled(true)
        postProcess:SetVignetteIntensity(healVignetteData.intensity)
        postProcess:SetVignetteSmoothness(healVignetteData.smoothness)
        postProcess:SetVignetteColor(
            healVignetteData.color[1],
            healVignetteData.color[2],
            healVignetteData.color[3],
            healVignetteData.color[4]
        )
        return
    end

    if berserkVignetteData.active then
        postProcess:SetVignetteEnabled(true)
        postProcess:SetVignetteIntensity(berserkVignetteData.intensity)
        postProcess:SetVignetteSmoothness(berserkVignetteData.smoothness)
        postProcess:SetVignetteColor(
            berserkVignetteData.color[1],
            berserkVignetteData.color[2],
            berserkVignetteData.color[3],
            berserkVignetteData.color[4]
        )
        return
    end

    if lowHealthVignetteData.active then
        postProcess:SetVignetteEnabled(true)
        postProcess:SetVignetteIntensity(lowHealthVignetteData.intensity)
        postProcess:SetVignetteSmoothness(lowHealthVignetteData.smoothness)
        postProcess:SetVignetteColor(
            lowHealthVignetteData.color[1],
            lowHealthVignetteData.color[2],
            lowHealthVignetteData.color[3],
            lowHealthVignetteData.color[4]
        )
        return
    end

    postProcess:SetVignetteEnabled(false)
end

function Update(self, dt)
    if potionCooldown > 0 then potionCooldown = potionCooldown - dt end

    -- Input Curacion
    if (Input.GetKeyDown("3") or Input.GetGamepadButtonDown("LB")) and potionCooldown <= 0 then
        if self.public.potionCount > 0 and _G.PlayerInstance and _G.PlayerInstance.public.health < 100 and not potionHealing then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.potionCount  = self.public.potionCount - 1
                potionHealing            = true
                potionHealRemaining      = POTION_HEAL_TOTAL
                potionCooldown           = POTION_COOLDOWN_MAX
                _G.TriggerHealVignette()
            end
        end
    end

    -- Input Berserk
    if (Input.GetGamepadButtonDown("RB") or Input.GetKeyDown("4")) and potionCooldown <= 0 then
        if self.public.berserkCount > 0 and berserkActiveTimer <= 0 and _G.PlayerInstance then
            if _G.TriggerDrinkAnimation and _G.TriggerDrinkAnimation(_G.PlayerInstance, false) then
                self.public.berserkCount = self.public.berserkCount - 1
                berserkActiveTimer = BERSERK_DURATION
                berserkPulseTimer  = 0.0
                potionCooldown     = POTION_COOLDOWN_MAX
                _G.PlayerInstance.public.berserkActive = true
                _G.PlayerInstance.public.stamina       = 100.0
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
    UpdateLowHealthVignette(dt)
    ApplyVignetteEffects()

    -- Logica de curacion
    if potionHealing and _G.PlayerInstance then
        local healThisTick = POTION_HEAL_RATE * dt
        local currentHP    = _G.PlayerInstance.public.health
        local actualHeal   = math.min(healThisTick, potionHealRemaining)
        local maxHeal      = math.min(actualHeal, 100.0 - currentHP)

        _G.PlayerInstance.public.health = currentHP + maxHeal
        potionHealRemaining = potionHealRemaining - actualHeal

        if potionHealRemaining <= 0 or _G.PlayerInstance.public.health >= 100.0 then
            potionHealing       = false
            potionHealRemaining = 0.0
        end
    end
end