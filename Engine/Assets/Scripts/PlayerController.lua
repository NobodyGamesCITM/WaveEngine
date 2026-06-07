--Player Controller Script

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local attackCol
local chargeCole
local heavyCol
local attackTimer = 0
local attackCooldown = 0
local rollCooldown = 0
local stepTimer = 0.5
local winBossCinematic = false 
local enterPortalCinematic = false
local exitPortalCinematic = false
local wakeUpCinematic = false
local playedEpicBGM = false
local playedSwordPrep = false
local playedUnsheathe = false
local playedFinishHim = false
local playedSwordSwing = false
local playedFinalNote = false

local playedStep1 = false
local playedStep2 = false
local playedStep3 = false
local playedStep4 = false
local playedStep5 = false
local playedStep6 = false




-- Hit vignette
local hitVigTimer      = 0.0
local accumulatedAlpha = 0.0
local HIT_VIG_FADE_IN  = 0.1
local HIT_VIG_HOLD     = 0.15
local HIT_VIG_FADE_OUT = 1.5
local HIT_VIG_ALPHA_STEP = 0.25

--audiosources
local attackSource 
local voiceSource
local hitSource
local itemSource
local hpSource
local mGo 
local musicComp
--local equipSource
local changeSource
local swordMat = nil
local surfaces = {"Grass", "Water", "Dirt", "Stone", "Bones", "Sand", "Wood"}

_PlayerController_lastAttack         = ""
_impactFrameTimer                    = 0
_G._PlayerController_currentMask     = ""
_PlayerController_isDrowning         = false
_G._PlayerController_isDead          = false  
_G.PlayerInstance                    = nil
_G._MaskCount = 0
_G._PlayerController_drownDeath = false
_G._BossIntroCinematic = false

local INPUT_SCALE = 10
local HERMES_GRACE_TIME      = 0.2
local ATTACK_BUFFER = 0.5
local hurtTimer = 0.0
local HURT_DURATION = 0.5
local heavyAttackMoveSpeed = 7.0

local iFramesTimer    = 0.0
local IFRAME_DURATION = 1.0

-- MASKS
local Mask = {
    NONE   = "NoMask",
    APOLLO = "Apolo",
    HERMES = "Hermes",
    ARES   = "Ares"
}

-- STATES
local State = {
    IDLE         = "Idle",
    WALK         = "Walk",
    RUNNING      = "Running",
    ROLL         = "Roll",
    CHARGING     = "Charging",
    ATTACK_LIGHT = "AttackLight",
    ATTACK_HEAVY = "AttackHeavy",
    SHOOTING     = "Shooting",
    DEAD         = "Dead"
}

local Player = {
    currentState    = nil,
    currentMask     = nil,
    lastDirX        = 0,
    lastDirZ        = 1,
    lastAngle       = 0,
    godMode         = false,
    inPuzzleArea    = false,
    rb              = nil,
    sprintHeld      = false,
	smokePS         = nil,
	bubblesPS         = nil,
	hermesRunPS         = nil,
	thinBloodPs         = nil,
	wideBloodPs         = nil,
	aresPs         = nil,
	apoloPs         = nil,
	hermesPs         = nil,
	hermesAttackPs         = nil,
	aresAttackPs         = nil,
	apoloAttackPs         = nil,
	trailPs         = nil,
    aresLight         = nil,
	apoloLight         = nil,
	hermesLight         = nil,
    attackDelay     = 0.1,
    -- Audio
    stepSFX 		= nil,
    voiceSFX 		= nil,
    swordSFX 		= nil,
    
    changeMaskSFX   = nil,
    itemSFX     = nil,
    hitSFX          = nil,
	currentSurface = "",
    lastGroundSurface = "",
    foundSurface    = false,
    
    -- Hermes mask
    respawnPos       = nil,
    isDrowning       = false,
    hermesGraceTimer = 0.2,
    hermesDeathRespawn = false,
    hermesDeathTimer   = 0.0,
    hermesPendingUnequip = false,
    hermesRespawnCooldown = 0,
    hermesWaterWalkCost = 10.0,
    baseSpeed = 0.0,
    isGrounded = false,

    attackBuffer = false,
    attackBufferPending = false,
    attackNum = 0,

    staminaLock = false,

    maskAnimDuration = 0.3,
    maskAnimTimer = 0.0,

    healAnimTimer = 0.0,
    healAnimDuration = 1.0,
    healPending = false,

    AnimTimer = 0.0,
    isGetMaskAnim     = false,
    isPortalEnterAnim   = false,
    isPortalExitAnim    = false,
    pendingObtainMask = nil,
    getMaskEvent1Done = false,
    getMaskEvent2Done = false,
    getMaskIdleTransitionDone = false,
    currentOrbitAnim = nil,
    rawDirX = 0,
    rawDirZ = 1,
}

local playerParticles = {Player.apoloPs, Player.apoloAttackPs, Player.hermesPs, Player.hermesAttackPs,  Player.hermesAttackPs, Player.aresPs, Player.aresAttackPs, Player.trailPs}

public = {
    speed               = 15.0,
    rollDuration        = 1.0,
    sprintMultiplier    = 1.5,
    rollSpeed           = 15.0,
    chargeSpeed         = 30.0,
    stamina             = 100.0,
    health              = 100.0,
    speedIncrease       = 10.0,
    speedHermesBonus    = 7.0,
    staminaCost      = 80.0,
    staminaRecover   = 25.0,   
    rollStaminaCost     = 25,
    heavyStaminaCost    = 25,
    usingStamina        = false,
    tiredMultiplier     = 0.7,
    hpLossCost       = 30.0,  
    hpRecover        = 30.0,  
    attackDuration      = 0.4,
    chargeDuration      = 0.3,
    shootDuration       = 0.5,
    attackCooldown      = 0.4,
    comboCooldown       = 0.9,
    rollCooldownMax     = 0.5,
    knockbackForce      = 14.0,
    hitShakeDuration    = 0.3,
    hitShakeMagnitude   = 6.0,
    ROTATION_SPEED      = 780,
    hermesWaterMax      = 2.0,
    flySpeed            = 20.0,
    bulletPrefab = "Prefabs/Bullet.prefab",
    bulletBarrel   = 1.5,
    bulletSpawnY   = 1.0,
    bulletScale    = 1.0,
    interact            = false,
    giveApoloMask       = false,
    giveHermesMask      = false,
    giveAresMask        = false,
    attackImpulseForce  = 6.0,
    attackImpulseWindow = 0.15,
    heavyDuration       = 0.7,
    heavyAttackDelay    = 0.35,
    heavyUpImpulse      = 2.0,
    attackBufferDuration = 0.4,
    canMove             = true,
    berserkActive       = false,
}

local function GetAnimName(base)
    if Player.currentMask == Mask.HERMES then
        return "Hermes" .. base
    end
    return base
end

function TriggerDrinkAnimation(self, isInternalHeal)
    if Player.healAnimTimer > 0 or Player.maskAnimTimer > 0 or Player.currentState == State.DEAD or Player.AnimTimer > 0  then
        return false
    end
    -- Hit vignette
    if postProcess then
        local totalDuration = HIT_VIG_FADE_IN + HIT_VIG_HOLD + HIT_VIG_FADE_OUT
        hitVigTimer = totalDuration
    end
    
    ChangeState(self, State.IDLE)
    if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

    local anim = self.gameObject:GetComponent("Animation")
    if anim then 
        pcall(function() anim:Play("Idle", 0.0) end)
        pcall(function() anim:Play("Drink", 0.4) end)  
        if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_PotionDrink") end
    end
    
    Player.healAnimTimer = Player.healAnimDuration
    Player.healPending = isInternalHeal
    Player.maskAnimTimer = 0
    self.public.canMove = false
    return true
end

function _G.TriggerCameraShake(duration, magnitude, freq)
    local camObj = GameObject.Find("MainCamera")
    if camObj then
        local cineCam = camObj:GetComponent("CinematicCamera")
        if cineCam then
            cineCam:Shake(duration or 0.3, magnitude or 6.0, freq or 25.0)
        end
    end
end

_G.SetPlayerAnimTimer = function(duration)
    Player.AnimTimer = duration
end

_G.StartPortalEnterAnim = function()
    Player.isPortalEnterAnim = true
end

_G.StartPortalExitAnim = function()
    Player.isPortalExitAnim = true
end

local function normalizeInput(x, z)
    local len = sqrt(x*x + z*z)
    if len > INPUT_SCALE then
        local inv = INPUT_SCALE / len
        return x * inv, z * inv
    end
    return x, z
end

local function GetMovementInput(self)
    if self.public.canMove == false then
        return 0, 0, 0
    end

    local inputX, inputZ = 0, 0

    if Input.HasGamepad() then
        local gpX, gpZ = Input.GetLeftStick()
        inputX = gpX
        inputZ = -gpZ
    end
    
    if Input.GetKey("W") then inputZ = inputZ + 1 end
    if Input.GetKey("S") then inputZ = inputZ - 1 end
    if Input.GetKey("A") then inputX = inputX - 1 end
    if Input.GetKey("D") then inputX = inputX + 1 end

    local inputLen = math.sqrt(inputX*inputX + inputZ*inputZ)
    if inputLen > 1.0 then
        inputX = inputX / inputLen
        inputZ = inputZ / inputLen
        inputLen = 1.0
    end

    if inputLen < 0.01 then
        return 0, 0, 0
    end

    local camObj = GameObject.Find("MainCamera")
    if camObj then
        local camFwd = camObj.transform.worldForward
        local camRight = camObj.transform.worldRight
        
        camFwd.x = -camFwd.x
        camFwd.y = -camFwd.y
        camFwd.z = -camFwd.z
        
        camFwd.y = 0
        camRight.y = 0
        
        local lenFwd = math.sqrt(camFwd.x*camFwd.x + camFwd.z*camFwd.z)
        if lenFwd > 0.001 then
            camFwd.x = camFwd.x / lenFwd
            camFwd.z = camFwd.z / lenFwd
        else
            camFwd = {x=0, y=0, z=1}
        end
        
        local lenRight = math.sqrt(camRight.x*camRight.x + camRight.z*camRight.z)
        if lenRight > 0.001 then
            camRight.x = camRight.x / lenRight
            camRight.z = camRight.z / lenRight
        else
            camRight = {x=1, y=0, z=0}
        end
        
        local moveX = (camRight.x * inputX) + (camFwd.x * inputZ)
        local moveZ = (camRight.z * inputX) + (camFwd.z * inputZ)
        
        local finalLen = math.sqrt(moveX*moveX + moveZ*moveZ)
        if finalLen > 0.001 then
            moveX = (moveX / finalLen) * inputLen * INPUT_SCALE
            moveZ = (moveZ / finalLen) * inputLen * INPUT_SCALE
        end
        
        return moveX, moveZ, inputLen * INPUT_SCALE
    end
    
    return inputX * INPUT_SCALE, -inputZ * INPUT_SCALE, inputLen * INPUT_SCALE
end

local function GetAttackInput(self)
    if attackCooldown > 0 and attackBuffer == false then return 0 end
    if Input.GetKeyDown("E") or Input.GetGamepadButtonDown("X") then return 1 end
    if Input.GetKeyDown("Q") or Input.GetGamepadButtonDown("Y") then return 2 end
    return 0
end

local function GetLockOnDir(self)
    if not _G.TargetLockManager_IsLocked then return nil, nil end
    local target = _G.TargetLockManager_CurrentTarget
    if not target then return nil, nil end
    
    local pPos = self.transform.worldPosition
    local tPos = target.transform.worldPosition 
    
    local dx = tPos.x - pPos.x
    local dz = tPos.z - pPos.z
    local len = math.sqrt(dx*dx + dz*dz)
    if len < 0.001 then return nil, nil end
    return dx / len, dz / len
end

local function SnapToLockOn(self)
    local lockDirX, lockDirZ = GetLockOnDir(self)
    if not lockDirX then return false end
    Player.lastDirX  = lockDirX
    Player.lastDirZ  = lockDirZ
    Player.lastAngle = atan2(lockDirX, lockDirZ) * (180.0 / pi)
    if Player.rb then Player.rb:SetRotation(0, Player.lastAngle, 0) end
    return true
end

local function ApplyMovementAndRotation(self, dt, moveX, moveZ, speedOverride)
    local speed = speedOverride or Player.currentSpeed
    local faceDirX = moveX / INPUT_SCALE
    local faceDirZ = moveZ / INPUT_SCALE
    local velY = 0
    
    if Player.rb then
        velY = math.min(0, Player.rb:GetLinearVelocity().y)
    end

    local lockDirX, lockDirZ = GetLockOnDir(self)
    if lockDirX then
        Player.lastDirX  = lockDirX
        Player.lastDirZ  = lockDirZ
        Player.lastAngle = atan2(lockDirX, lockDirZ) * (180.0 / pi)
        if Player.rb then Player.rb:SetRotation(0, Player.lastAngle, 0) end
    elseif abs(faceDirX) > 0.01 or abs(faceDirZ) > 0.01 then
        local targetAngle = atan2(faceDirX, faceDirZ) * (180.0 / pi)
        Player.lastAngle = targetAngle
        if Player.rb then Player.rb:SetRotation(0, Player.lastAngle, 0) end
    end

    if not Player.rb then
        Player.rb = self.gameObject:GetComponent("Rigidbody")
    end

    if Player.rb then
        Player.rb:SetLinearVelocity(faceDirX * speed, velY, faceDirZ * speed)
    end
end

local function UpdateFlyingGodMode(self, dt)
    local moveX, moveZ, _ = GetMovementInput(self)
    local velY = 0

    if Input.GetKey("E") then
        velY =  self.public.flySpeed
    elseif Input.GetKey("Q") then
        velY = -self.public.flySpeed
    end

    local faceDirX = moveX / INPUT_SCALE
    local faceDirZ = moveZ / INPUT_SCALE

    local faceDirLen = sqrt(faceDirX * faceDirX + faceDirZ * faceDirZ)
    if faceDirLen > 0.01 then
        Player.lastDirX = faceDirX / faceDirLen
        Player.lastDirZ = faceDirZ / faceDirLen

        local targetAngle = atan2(faceDirX, faceDirZ) * (180.0 / pi)
        Player.lastAngle = targetAngle
        Player.rb:SetRotation(0, Player.lastAngle, 0)
    end

    local hSpeed = Player.currentSpeed
    if Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5 then
        hSpeed = hSpeed + self.public.speedIncrease
    end

    if Player.rb then
        Player.rb:SetLinearVelocity(faceDirX * hSpeed, velY, faceDirZ * hSpeed)
    end
end

-- STATE MACHINE
local States = {}

local function ChangeState(self, newState, force)
    if not force and Player.currentState == newState then return end
    if not force and newState ~= State.DEAD then
        if newState == State.RUNNING and staminaLock == true then return end
        if Player.maskAnimTimer > 0 then return end
        if Player.healAnimTimer > 0 then return end
        if Player.AnimTimer > 0 then return end
    end

    if Player.currentState and States[Player.currentState].Exit then
        States[Player.currentState].Exit(self)
    end
    
    Player.currentState = newState
    if newState ~= State.IDLE and newState ~= State.RUNNING 
    and newState ~= State.WALK and newState ~= State.ATTACK_LIGHT then
        attackBuffer = false
    end   

    if States[newState].Enter then
        States[newState].Enter(self)
    end
end

_G.SetPlayerStateIdle = function(playerSelf)
    ChangeState(playerSelf, State.IDLE, true)
end

function _G.TriggerDrinkAnimation(self, isInternalHeal)
    if not self or Player.healAnimTimer > 0 or Player.maskAnimTimer > 0 or Player.currentState == State.DEAD or Player.AnimTimer > 0 then
        return false
    end

    ChangeState(self, State.IDLE)
    if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

    local anim = self.gameObject:GetComponent("Animation")
    if anim then 
        pcall(function() anim:Play("Idle", 0.0) end)
        pcall(function() anim:Play("Drink", 0.4) end) 
        if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_PotionDrink") end
    end
    
    Player.healAnimTimer = Player.healAnimDuration
    Player.healPending = isInternalHeal
    Player.maskAnimTimer = 0 
    self.public.canMove = false
    return true
end

local function ApplyMaskVisual(self, newMask)
    if not maskApolo or not maskApolo.transform or 
       not maskAres or not maskAres.transform or 
       not maskHermes or not maskHermes.transform then 
        FindMasks(self) 
    end
    
    if newMask == Mask.APOLLO then
        if maskAres   then maskAres:SetActive(false)  end
        if maskApolo  then maskApolo:SetActive(true)   end
        if maskHermes then maskHermes:SetActive(false) end
    elseif newMask == Mask.HERMES then
        if maskAres   then maskAres:SetActive(false)  end
        if maskApolo  then maskApolo:SetActive(false)  end
        if maskHermes then maskHermes:SetActive(true)  end
    elseif newMask == Mask.ARES then
        if maskAres   then maskAres:SetActive(true)   end
        if maskApolo  then maskApolo:SetActive(false)  end
        if maskHermes then maskHermes:SetActive(false) end
    elseif newMask == Mask.NONE then
        if maskAres   then maskAres:SetActive(false)  end
        if maskApolo  then maskApolo:SetActive(false)  end
        if maskHermes then maskHermes:SetActive(false) end
    end
end


local function EquipMask(self, newMask, skipSword)
    if not self.gameObject or not self.gameObject.transform then return end

    if Player.currentMask == Mask.HERMES and Player.isDrowning and newMask ~= Mask.HERMES then
        ApplyMaskVisual(self, newMask)
        self.public.health = 0
        _G._PlayerController_isDead = true
        _G._PlayerController_drownDeath = true
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        ChangeState(self, State.DEAD)
        UpdateSwordMaterial()
        return
    end
    if Player.maskAnimTimer > 0 then return end

    if not maskApolo or not maskApolo.transform or 
       not maskAres or not maskAres.transform or 
       not maskHermes or not maskHermes.transform then
        FindMasks(self)
    end
    
    ApplyMaskVisual(self, newMask)

    if Player.currentMask == newMask or Player.currentState == State.DEAD then return end
    if Player.currentMask == Mask.HERMES then
        Player.hermesGraceTimer   = 0
    end

    local oldMask = Player.currentMask
    Player.currentMask = newMask

    if newMask == Mask.APOLLO then _G._MaskState_Apolo  = true
    elseif newMask == Mask.HERMES then _G._MaskState_Hermes = true
    elseif newMask == Mask.ARES   then _G._MaskState_Ares   = true
    end

    if Player.currentMask ~= Mask.NONE and Player.currentMask ~= oldMask then 
        Audio.SetSwitch("Player_Mask", tostring(Player.currentMask), Player.changeMaskSFX)
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch") end
    end

    if newMask == Mask.HERMES then
        _G._PlayerController_currentMask = "Hermes"
    elseif newMask == Mask.APOLLO then
        _G._PlayerController_currentMask = "Apolo"
    elseif newMask == Mask.ARES then
        _G._PlayerController_currentMask = "Ares"
    else
        _G._PlayerController_currentMask = ""
    end
    if not skipSword then UpdateSwordMaterial() end
end

States[State.DEAD] = {
    Enter  = function(self)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

        -- Resetear bloqueos de animación y movimiento al morir
        Player.healAnimTimer = 0
        Player.healPending = false
        Player.maskAnimTimer = 0
        Player.AnimTimer = 0
        self.public.canMove = true

        _G._PlayerController_isDead = true
        _G._PlayerController_deathAnimDone = false  
        Player.deathAnimTimer = 1.5                  
        if Player.voiceSFX then Player.voiceSFX:SelectPlayAudioEvent("SFX_PlayerDeath") end
        local anim = self.gameObject:GetComponent("Animation")
        if anim and Player.isDrowning then
            pcall(function() anim:Play("Drown", 0.5) end)
            if Player.currentMask == Mask.HERMES then
                pcall(function() anim:SetSpeed("Drown", 1.0) end)
            else
                pcall(function() anim:SetSpeed("Drown", 0.4) end)
            end
        else 
            pcall(function() anim:Play("Die", 0.5) end)
        end
    end,
    Update = function(self, dt)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

        if not _G._PlayerController_deathAnimDone then
            local realDt = Time.GetRealDeltaTime()
            Player.deathAnimTimer = (Player.deathAnimTimer or 1.5) - realDt
            if Player.deathAnimTimer <= 0 then
                _G._PlayerController_deathAnimDone = true
            end
        end

        if Input.GetKeyDown("1") then
            self.public.health  = 100
            self.public.stamina = 100
            local p = lastCheckpoint
            self.transform:SetPosition(p.x, p.y, p.z)
            _G._PlayerController_isDead = false
            _G._PlayerController_deathAnimDone = false
            ChangeState(self, State.IDLE)
        end

        if Player.hermesDeathRespawn then
            Player.hermesDeathTimer = Player.hermesDeathTimer - dt
            if Player.hermesDeathTimer <= 0 then
                Player.hermesDeathRespawn = false    
                Player.hermesGraceTimer = 0
                local rp = Player.respawnPos
                self.transform:SetPosition(rp.x, rp.y, rp.z)
                if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
                if Player.hermesPendingUnequip then
                    _G._PlayerController_currentMask = ""
                    Player.hermesPendingUnequip = false    
                end
                Player.hermesRespawnCooldown = 0.5
                _G._PlayerController_isDead = false
                _G._PlayerController_deathAnimDone = false

                local anim = self.gameObject:GetComponent("Animation")
                if anim then 
                    pcall(function() anim:Play(GetAnimName("Idle"), 0.0) end)
                end
            end
        end

        if Player.hermesRespawnCooldown > 0 then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play(GetAnimName("Idle"), 0.0) end)
            end
            Player.hermesRespawnCooldown = Player.hermesRespawnCooldown - dt
            if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
            if Player.hermesRespawnCooldown <= 0 then
                ChangeState(self, State.IDLE)
                self.public.stamina = 70.0
                staminaLock = false
                if Player.isDrowning then
                    Player.hermesGraceTimer = 1.0
                end
            end
        end
    end
}

States[State.IDLE] = {
    Enter = function(self)
        Player.currentOrbitAnim = nil
        _PlayerController_lastAttack = ""
        if attackBufferPending then 
            ChangeState(self, State.ATTACK_LIGHT)
            attackBufferPending = false
            return
        end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play(GetAnimName("Idle"), 0.5) end)
        end
    end,
    
    Update = function(self, dt)
        SnapToLockOn(self)
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, math.min(0, velocity.y), 0)
        end

        local moveX, moveZ, inputLen = GetMovementInput(self)
        if inputLen > 0.1 then
            if Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5 then
                ChangeState(self, State.RUNNING)
            else
                ChangeState(self, State.WALK)
            end
        end

        if GetAttackInput(self) == 1 then
            ChangeState(self, State.ATTACK_LIGHT)
            return
        end
        if GetAttackInput(self) == 2 and self.public.stamina >= self.public.heavyStaminaCost then
            if Player.currentMask == Mask.ARES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.ATTACK_HEAVY)
                return
            end
        end
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end
    end
}

States[State.WALK] = {
    Enter = function(self)
        Player.currentOrbitAnim = nil
        self.public.usingStamina = false
        if not _G.TargetLockManager_IsLocked then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                local walkAnim = GetAnimName("Walk")
                local hasWalk = pcall(function() anim:Play(walkAnim, 0.5) end)
                if hasWalk then
                    pcall(function() anim:SetSpeed(walkAnim, 1) end)
                else
                    pcall(function() anim:Play(GetAnimName("Idle"), 0.5) end)
                end
            end
        end
    end,
    
    Update = function(self, dt)
        if Player.isDrowning and Player.currentMask == Mask.HERMES and not Player.inPuzzleArea then
            self.public.stamina = math.max(0, self.public.stamina - (Player.hermesWaterWalkCost * dt))
        end

        local sprintInput = Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5
        if sprintInput and not Player.sprintHeld and self.public.stamina > 10 then
            ChangeState(self, State.RUNNING)
        end
        local moveX, moveZ, inputLen = GetMovementInput(self)

        if inputLen > 0.01 then
            Player.rawDirX = moveX / inputLen
            Player.rawDirZ = moveZ / inputLen
        end
        
        if inputLen > 0.01 then
            Player.lastDirX = moveX / inputLen
            Player.lastDirZ = moveZ / inputLen
        end

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end
        
        if GetAttackInput(self) == 1 then
            ChangeState(self, State.ATTACK_LIGHT)
            return
        end
        if GetAttackInput(self) == 2 and self.public.stamina >= self.public.heavyStaminaCost then
            if Player.currentMask == Mask.ARES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.ATTACK_HEAVY)
                return
            end
        end
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end

        
        if Player.stepSFX then
            stepTimer = stepTimer + dt
            
            if stepTimer >= (0.5 / self.public.sprintMultiplier) and Player.currentMask ~= Mask.HERMES then
                stepTimer = 0
                Audio.SetSwitch("Player_Speed", "Walk", Player.stepSFX)
                Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps")
            end

        end
        

        if _G.TargetLockManager_IsLocked and _G.TargetLockManager_CurrentTarget then
            local tPos = _G.TargetLockManager_CurrentTarget.transform.position
            local pPos = self.transform.worldPosition
            local dx = tPos.x - pPos.x
            local dz = tPos.z - pPos.z
            local len = math.sqrt(dx*dx + dz*dz)
            if len > 0.001 then
                local eDirX = dx / len
                local eDirZ = dz / len
                local mLen = math.sqrt(moveX*moveX + moveZ*moveZ)
                if mLen > 0.01 then
                    local mX = moveX / mLen
                    local mZ = moveZ / mLen
                    local fwdDot   =  mX * eDirX + mZ * eDirZ
                    local rightDot =  mX * eDirZ - mZ * eDirX
                    local newAnim
                    if math.abs(fwdDot) >= math.abs(rightDot) then
                        if fwdDot >= 0 then newAnim = "OrbitFwd"
                        else                newAnim = "OrbitBack" end
                    else
                        if rightDot >= 0 then newAnim = "OrbitRight"
                        else                  newAnim = "OrbitLeft" end
                    end
                    if newAnim ~= Player.currentOrbitAnim then
                        Player.currentOrbitAnim = newAnim
                        local anim = self.gameObject:GetComponent("Animation")
                        if anim then
                            if newAnim == "OrbitFwd"   then pcall(function() anim:Play(GetAnimName("OrbitFwd"),   0.2) end) end
                            if newAnim == "OrbitBack"  then pcall(function() anim:Play(GetAnimName("OrbitBack"),  0.2) end) end
                            if newAnim == "OrbitLeft"  then pcall(function() anim:Play(GetAnimName("OrbitLeft"),  0.2) end) end
                            if newAnim == "OrbitRight" then pcall(function() anim:Play(GetAnimName("OrbitRight"), 0.2) end) end
                        end                    
                    end
                end
            end
        else
            if Player.currentOrbitAnim ~= nil then
                Player.currentOrbitAnim = nil
                local anim = self.gameObject:GetComponent("Animation")
                if anim then pcall(function() anim:Play(GetAnimName("Walk"), 0.2) end) end
            end
        end
        
        ApplyMovementAndRotation(self, dt, moveX, moveZ, Player.baseSpeed)
    end,

    Exit = function(self)
        Player.currentOrbitAnim = nil
    end,
}

States[State.RUNNING] = {
    Enter = function(self)
        Player.currentOrbitAnim = nil
        if not _G.TargetLockManager_IsLocked then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                local runAnim = GetAnimName("Running")
                pcall(function() anim:Play(runAnim, 0.5) end)
                pcall(function() anim:SetSpeed(runAnim, 2.0) end)
            end
        end

        self.public.usingStamina = true
        Player.currentSpeed = Player.baseSpeed + self.public.speedIncrease
        
        if Player.currentMask == Mask.HERMES then
            Player.currentSpeed = Player.currentSpeed + self.public.speedHermesBonus
        end	

        

        if Player.isDrowning and Player.currentMask == Mask.HERMES then
            if Player.bubblesPS then Player.bubblesPS:Play() end
        elseif Player.currentMask ~= Mask.HERMES and Player.smokePS then Player.smokePS:Play() end
        if Player.hermesRunPS and Player.currentMask == Mask.HERMES then Player.hermesRunPS:Play() end
    end,
    Exit = function(self)
        Player.currentOrbitAnim = nil
        Player.currentSpeed = Player.baseSpeed
        self.public.usingStamina = false
		if Player.smokePS then Player.smokePS:Stop() end
		if Player.bubblesPS then Player.bubblesPS:Stop() end
		if Player.hermesRunPS then Player.hermesRunPS:Stop() end
    end,
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput(self)

        if inputLen > 0.01 then
            Player.rawDirX = moveX / inputLen
            Player.rawDirZ = moveZ / inputLen
        end

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end

        if not Input.GetKey("LeftShift") and not (Input.GetGamepadAxis("LT") > 0.5) then
            ChangeState(self, State.WALK)
            return
        end

        if inputLen > 0.01 then
            Player.lastDirX = moveX / inputLen
            Player.lastDirZ = moveZ / inputLen
        end

        if GetAttackInput(self) == 1 then
            ChangeState(self, State.ATTACK_LIGHT)
            return
        end
        if GetAttackInput(self) == 2 and self.public.stamina >= self.public.heavyStaminaCost then
            if Player.currentMask == Mask.ARES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.ATTACK_HEAVY)
                return
            end
        end
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end

        if Player.currentMask == Mask.HERMES and Player.isDrowning and not Player.inPuzzleArea then
            self.public.stamina = math.max(0, self.public.stamina - (self.public.staminaCost * dt))
        end


        if self.public.stamina <= 0 then
            ChangeState(self, State.WALK)
            return
        end

        if Player.stepSFX then
            stepTimer = stepTimer + dt
            
            if stepTimer >= (0.25/self.public.sprintMultiplier) and Player.currentMask ~= Mask.HERMES then
                stepTimer = 0
                Audio.SetSwitch("Player_Speed", "Run", Player.stepSFX)
                Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps")
            end

        end

        if _G.TargetLockManager_IsLocked and _G.TargetLockManager_CurrentTarget then
            local tPos = _G.TargetLockManager_CurrentTarget.transform.position
            local pPos = self.transform.worldPosition
            local dx = tPos.x - pPos.x
            local dz = tPos.z - pPos.z
            local len = math.sqrt(dx*dx + dz*dz)
            if len > 0.001 then
                local eDirX = dx / len
                local eDirZ = dz / len
                local mLen = math.sqrt(moveX*moveX + moveZ*moveZ)
                if mLen > 0.01 then
                    local mX = moveX / mLen
                    local mZ = moveZ / mLen
                    local fwdDot   =  mX * eDirX + mZ * eDirZ
                    local rightDot =  mX * eDirZ - mZ * eDirX
                    local newAnim
                    if math.abs(fwdDot) >= math.abs(rightDot) then
                        if fwdDot >= 0 then newAnim = "OrbitFwd"
                        else                newAnim = "OrbitBack" end
                    else
                        if rightDot >= 0 then newAnim = "OrbitRight"
                        else                  newAnim = "OrbitLeft" end
                    end
                    if newAnim ~= Player.currentOrbitAnim then
                        Player.currentOrbitAnim = newAnim
                        local anim = self.gameObject:GetComponent("Animation")
                        if anim then
                            if newAnim == "OrbitFwd"   then pcall(function() anim:Play(GetAnimName("OrbitFwd"),   0.2) end) pcall(function() anim:SetSpeed(GetAnimName("OrbitFwd"),   2.0) end) end
                            if newAnim == "OrbitBack"  then pcall(function() anim:Play(GetAnimName("OrbitBack"),  0.2) end) pcall(function() anim:SetSpeed(GetAnimName("OrbitBack"),  2.0) end) end
                            if newAnim == "OrbitLeft"  then pcall(function() anim:Play(GetAnimName("OrbitLeft"),  0.2) end) pcall(function() anim:SetSpeed(GetAnimName("OrbitLeft"),  2.0) end) end
                            if newAnim == "OrbitRight" then pcall(function() anim:Play(GetAnimName("OrbitRight"), 0.2) end) pcall(function() anim:SetSpeed(GetAnimName("OrbitRight"), 2.0) end) end
                        end                    
                    end
                end
            end
        else
            if Player.currentOrbitAnim ~= nil then
                Player.currentOrbitAnim = nil
                local anim = self.gameObject:GetComponent("Animation")
                if anim then
                    local runAnim = GetAnimName("Running")
                    pcall(function() anim:Play(runAnim, 0.2) end)
                    pcall(function() anim:SetSpeed(runAnim, 2.0) end)
                end
            end
        end

        ApplyMovementAndRotation(self, dt, moveX, moveZ, Player.currentSpeed)
    end
}

States[State.ROLL] = {
    timer = 0,
    particlesPlayed = false, 
    Enter = function(self)
        if not Player.godMode and not self.public.berserkActive and not Player.inPuzzleArea then
            self.public.stamina = self.public.stamina - self.public.rollStaminaCost
        end
        States[State.ROLL].timer = self.public.rollDuration
        States[State.ROLL].particlesPlayed = false 

        if Player.rb then
            local angle = atan2(Player.rawDirX, Player.rawDirZ) * (180.0 / pi)
            Player.rb:SetRotation(0, angle, 0)
        end

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Roll", 0) end)
        end
        if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerRoll") end 
        if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_SkeletonDodge") end 
    end,
    Exit = function(self)
        rollCooldown = self.public.rollCooldownMax
        if Player.smokePS then Player.smokePS:Stop() end
		if Player.bubblesPS then Player.bubblesPS:Stop() end
    end,
    Update = function(self, dt)
        States[State.ROLL].timer = States[State.ROLL].timer - dt

        if States[State.ROLL].timer <= 0 then
            rollCooldown = self.public.rollCooldownMax
            ChangeState(self, State.IDLE)
            return
        end

        if not States[State.ROLL].particlesPlayed and States[State.ROLL].timer <= self.public.rollDuration * 0.5 then
            States[State.ROLL].particlesPlayed = true
            if Player.isDrowning and Player.currentMask == Mask.HERMES then
                if Player.bubblesPS then Player.bubblesPS:Play() end
            elseif Player.smokePS then Player.smokePS:Play() end
        end

        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(Player.rawDirX * self.public.rollSpeed, velocity.y, Player.rawDirZ * self.public.rollSpeed)
            local angle = atan2(Player.rawDirX, Player.rawDirZ) * (180.0 / pi)
            Player.rb:SetRotation(0, angle, 0)
        end
    end
}

States[State.CHARGING] = {
    Enter = function(self)
        SnapToLockOn(self)
        if not Player.godMode and not self.public.berserkActive and not Player.inPuzzleArea then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        if Input.HasGamepad() then Input.RumbleGamepad(0.7, 0.2, 250) end

        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Ares", 0.5) end
        if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_PlayerShot") end
        attackTimer = 0
        chargeCol = self.gameObject:GetComponent("Sphere Collider")
        if chargeCol then 
            chargeCol:Enable() 
            _PlayerController_lastAttack = "charge"
        end
        if Player.currentMask == Mask.ARES then
            if Player.aresAttackPs then
                Player.aresAttackPs:Play()
            end
        end

        ActivateTrail(self)
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt
        if attackTimer >= self.public.chargeDuration then
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end

        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(Player.lastDirX * self.public.chargeSpeed, velocity.y, Player.lastDirZ * self.public.chargeSpeed)
        end
    end,
    Exit = function(self)
        if chargeCol then chargeCol:Disable() end
        _PlayerController_lastAttack = ""
        if Player.aresAttackPs then
            Player.aresAttackPs:Stop()
        end
        if Player.trailPs then Player.trailPs:Stop() end
    end
}

States[State.SHOOTING] = {
    Enter = function(self)
        SnapToLockOn(self)
        _PlayerController_lastAttack = ""
        if not Player.godMode and not self.public.berserkActive and not Player.inPuzzleArea then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        if Input.HasGamepad() then Input.RumbleGamepad(0.7, 0.2, 250) end

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            anim:Play("Apolo", 0.3) 
            if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_AresCharge") end
        end
        attackTimer = 0

        local worldPos = self.transform.worldPosition
        local radians  = math.rad(Player.lastAngle)
        local fwdX     = math.sin(radians)
        local fwdZ     = math.cos(radians)

        if Player.currentMask == Mask.APOLLO then
            if Player.apoloAttackPs then
                Player.apoloAttackPs:Play()
            end
        end

        ActivateTrail(self)

        _G.nextBulletData = {
            x     = worldPos.x + fwdX * self.public.bulletBarrel,
            y     = worldPos.y + self.public.bulletSpawnY,
            z     = worldPos.z + fwdZ * self.public.bulletBarrel,
            dirX  = fwdX,
            dirZ  = fwdZ,
            angle = Player.lastAngle,
            scale = self.public.bulletScale,
        }
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt
        if attackTimer >= self.public.shootDuration then
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, velocity.y, 0)
        end
    end,
    Exit = function(self)
        _PlayerController_lastAttack = ""
        if Player.apoloAttackPs then
            Player.apoloAttackPs:Stop()
        end
        if Player.trailPs then Player.trailPs:Stop() end
    end
}

States[State.ATTACK_HEAVY] = {
    colliderActive = false,
    Enter = function(self)
        SnapToLockOn(self)
        if not Player.godMode and not self.public.berserkActive and not Player.inPuzzleArea then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        if Input.HasGamepad() then Input.RumbleGamepad(0.7, 0.2, 250) end

        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Hermes", 0.0) end
        if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_HermesSpin") end
        attackTimer = 0
        States[State.ATTACK_HEAVY].colliderActive = false
        heavyCol = self.gameObject:GetComponent("Capsule Collider")
        if heavyCol then heavyCol:Disable() end
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, math.min(0, velocity.y), 0)
        end

        if Player.currentMask == Mask.HERMES then
            if Player.hermesAttackPs then
                Player.hermesAttackPs:Play()
            end
        end

        ActivateTrail(self)
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt

        if not States[State.ATTACK_HEAVY].colliderActive then
            if attackTimer >= self.public.heavyAttackDelay then
                States[State.ATTACK_HEAVY].colliderActive = true
                _PlayerController_lastAttack = "heavy"
                if heavyCol then heavyCol:Enable() end
                if Player.rb then
                    Player.rb:SetLinearVelocity(0, self.public.heavyUpImpulse, 0)
                end
            end
        end

        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            local moveX, moveZ, inputLen = GetMovementInput(self)
            if inputLen > 0.01 then
                local dirX = moveX / inputLen
                local dirZ = moveZ / inputLen
                Player.rb:SetLinearVelocity(dirX * heavyAttackMoveSpeed, velocity.y, dirZ * heavyAttackMoveSpeed)
            else
                Player.rb:SetLinearVelocity(0, velocity.y, 0)
            end
        end

        if attackTimer >= self.public.heavyDuration then
            if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_PlayerAttack") end
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        if heavyCol then heavyCol:Disable() end
        States[State.ATTACK_HEAVY].colliderActive = false
        _PlayerController_lastAttack = ""

        if Player.hermesAttackPs then
            Player.hermesAttackPs:Stop()
        end

        if Player.trailPs then Player.trailPs:Stop() end
    end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
        SnapToLockOn(self)
        attackTimer = 0
        attackCol = self.gameObject:GetComponent("Box Collider")
        if attackCol then attackCol:Disable() end
        if Input.HasGamepad() then Input.RumbleGamepad(0.5, 0.5, 200) end

        if attackBuffer == true then
            if attackNum ~= 3 then
                attackNum = attackNum + 1
            end
            attackBuffer = false
        else
            attackNum = 1
        end

        if Player.currentMask == Mask.HERMES then
            if Player.hermesAttackPs then
                Player.hermesAttackPs:Play()
            end
        end
        if Player.currentMask == Mask.APOLLO then
            if Player.apoloAttackPs then
                Player.apoloAttackPs:Play()
            end
        end
        if Player.currentMask == Mask.ARES then
            if Player.aresAttackPs then
                Player.aresAttackPs:Play()
            end
        end

        ActivateTrail(self)

        local anim = self.gameObject:GetComponent("Animation")
        if anim and attackNum == 1 then anim:Play(GetAnimName("Attack1"), 0.0) end
        if anim and attackNum == 2 then anim:Play(GetAnimName("Attack2"), 0.0) end
        if anim and attackNum == 3 then anim:Play(GetAnimName("Attack3"), 0.0) end
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt

        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            attackBuffer = false
            attackBufferPending = false
            attackCooldown = 0
            local moveX, moveZ, inputLen = GetMovementInput(self)
            if inputLen > 0.01 then
                Player.lastDirX = moveX / inputLen
                Player.lastDirZ = moveZ / inputLen
                Player.lastAngle = math.atan(moveX / inputLen, moveZ / inputLen) * (180.0 / math.pi)
                if Player.rb then Player.rb:SetRotation(0, Player.lastAngle, 0) end
            end
            ChangeState(self, State.ROLL)
            return
        end

        if attackTimer >= Player.attackDelay and attackCol then
            _PlayerController_lastAttack = "light"
            attackCol:Enable()

            if Player.rb then
                local velocity = Player.rb:GetLinearVelocity()
                local radians = math.rad(Player.lastAngle)
                local fwdX = math.sin(radians)
                local fwdZ = math.cos(radians)
                
                if attackNum == 3 then
                    Player.rb:SetLinearVelocity(fwdX * self.public.attackImpulseForce, 0, fwdZ * self.public.attackImpulseForce)
                else
                    Player.rb:SetLinearVelocity(fwdX * self.public.attackImpulseForce * 0.3, 0, fwdZ * self.public.attackImpulseForce * 0.3)
                end
            end

        elseif Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, velocity.y, 0)
        end 

        if attackTimer >= (self.public.attackDuration * 0.5) and attackBuffer == false and attackNum ~= 3 then
            attackBuffer = true
        end

        if GetAttackInput(self) == 1 and attackBuffer == true then
            attackBufferPending = true
        end

        if attackTimer >= self.public.attackDuration then
            if Player.swordSFX then
                if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_PlayerAttack") end
            end
            if attackNum == 3 then
                attackCooldown = self.public.comboCooldown
            else
                attackCooldown = self.public.attackCooldown
            end
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        if attackCol then attackCol:Disable() end
        _PlayerController_lastAttack = ""

        if Player.hermesAttackPs then
            Player.hermesAttackPs:Stop()
        end
        if Player.apoloAttackPs then
            Player.apoloAttackPs:Stop()
        end
        if Player.aresAttackPs then
            Player.aresAttackPs:Stop()
        end
        if Player.trailPs then 
            Player.trailPs:Stop() 
        end
    end
}

local function TakeDamage(self, amount, attackerPos)
    if Player.currentState == State.DEAD then return end
    if Player.currentState == State.ROLL then return end
    if Player.godMode then return end
    if Player.AnimTimer > 0 then return end
    if iFramesTimer > 0 then return end

    local anim = self.gameObject:GetComponent("Animation")
    if anim and Player.AnimTimer == 0 then
        anim:Play("Idle", 0.0)
        anim:Play("Hurt", 0.0)
        hurtTimer = HURT_DURATION
        iFramesTimer = IFRAME_DURATION
    end

    if Player.thinBloodPs then Player.thinBloodPs:Play() end
    if Player.wideBloodPs then Player.wideBloodPs:Play() end

    self.public.health = math.max(0, self.public.health - amount)

    _G.TriggerCameraShake(0.2, 0.8, 8.0)
    if Input.HasGamepad() then Input.RumbleGamepad(1.0, 0.2, 150) end

    -- Activar hit vignette roja acumulada
    if postProcess then
        accumulatedAlpha = math.min(1.0, accumulatedAlpha + HIT_VIG_ALPHA_STEP)
        local totalDuration = HIT_VIG_FADE_IN + HIT_VIG_HOLD + HIT_VIG_FADE_OUT
        hitVigTimer = totalDuration
    end

    if self.public.health > 0 and Player.rb and attackerPos then
        if Player.hitSFX then Player.hitSFX:SelectPlayAudioEvent("SFX_PlayerHit") end
        local playerPos = self.transform.worldPosition
        local dx = playerPos.x - attackerPos.x
        local dz = playerPos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        Player.rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if Player.healAnimTimer > 0 then
        Player.healAnimTimer = 0
        Player.healPending = false
        self.public.canMove = true
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play(GetAnimName("Idle"), 0.5) end)
        end
    end

    if self.public.health <= 0 then
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.17
        ChangeState(self, State.DEAD, true)
    end
end

local function RefreshAudioSources(self)
    --Engine.Log("[Player] RefreshAudioSources: Refreshing audio component references")
    local go = self.gameObject
    
    local stepGo   = GameObject.FindInChildren(go, "StepSource") or GameObject.FindInChildren(go, "SFX_FootSteps")
    local swordGo  = GameObject.FindInChildren(go, "SwordSource") or GameObject.FindInChildren(go, "SFX_Sword")
    local voiceGo  = GameObject.FindInChildren(go, "VoiceSource") or GameObject.FindInChildren(go, "SFX_Voice")
    local hitGo    = GameObject.FindInChildren(go, "HitSource") or GameObject.FindInChildren(go, "SFX_Hit")
    local maskGo   = GameObject.FindInChildren(go, "MaskSource") or GameObject.FindInChildren(go, "SFX_Mask")
    local itemGo   = GameObject.FindInChildren(go, "ItemSource") or GameObject.FindInChildren(go, "SFX_Item")
    local heartGo     = GameObject.FindInChildren(go, "HeartSource")
    
    local rootSource = go:GetComponent("Audio Source")
    if not rootSource then
        --Engine.Log("[Player] WARNING: No root Audio Source found on Player object!")
    end

    Player.stepSFX       = (stepGo and stepGo:GetComponent("Audio Source")) or rootSource
    Player.swordSFX      = (swordGo and swordGo:GetComponent("Audio Source")) or rootSource
    Player.voiceSFX      = (voiceGo and voiceGo:GetComponent("Audio Source")) or rootSource
    Player.hitSFX        = (hitGo and hitGo:GetComponent("Audio Source")) or rootSource
    Player.changeMaskSFX = (maskGo and maskGo:GetComponent("Audio Source")) or rootSource
    Player.itemSFX   = (itemGo and itemGo:GetComponent("Audio Source")) or rootSource
    Player.heartSFX = (heartGo and heartGo:GetComponent("Audio Source")) or rootSource
    
    --Engine.Log("[Player] Audio Source Mapping Status:")
    --Engine.Log(" - StepSFX: " .. (stepGo and "CHILD FOUND" or "ROOT DEFAULT"))
    --Engine.Log(" - SwordSFX: " .. (swordGo and "CHILD FOUND" or "ROOT DEFAULT"))
    --Engine.Log(" - VoiceSFX: " .. (voiceGo and "CHILD FOUND" or "ROOT DEFAULT"))
    --Engine.Log(" - ItemSFX: " ..(itemGo and "CHILD FOUND" or "ROOT DEFAULT"))
    --Engine.Log(" - MaskSFX: " ..(maskGo and "CHILD FOUND" or "ROOT DEFAULT"))
end

local FindMasks
local InitParticles

function Start(self)
    Engine.Log("[Player] Start() called - Initializing player")

    attackCol    = nil
    chargeCol    = nil
    heavyCol     = nil
    attackTimer  = 0
    attackCooldown = 0
    rollCooldown = 0
    stepTimer    = 0.5
    _G._PlayerController_drownDeath = false
    
    Player.currentState    = nil
    Player.currentMask     = nil
    Player.rb              = nil
    Player.smokePS         = nil
    Player.stepSFX         = nil
    Player.voiceSFX        = nil
    Player.swordSFX        = nil
    --Player.pickMaskSFX     = nil
    Player.changeMaskSFX   = nil
    Player.itemSFX     = nil
    Player.hitSFX          = nil
    Player.heartSFX        = nil
    _G.PlayerInstance = self

    --force stats
    rollCooldown   = 0
    attackCooldown = 0
    impulseDone    = false
    attackTimer    = 0
    stepTimer      = 0
    attackBuffer   = false
    attackBufferPending = false
    attackNum      = 0
    _G.PlayerInAnim = false
    Game.SetTimeScale(1.0)

    _G._PlayerController_isDead = false
    _G.PlayWinBossCinematic     = false

    self.public.staminaCost    = 20.0   
    self.public.staminaRecover = 25.0

    local spawnPos  = self.transform.worldPosition
    
    Player.spawnPos = spawnPos
    Player.respawnPos = spawnPos
    lastCheckpoint = spawnPos
    Player.baseSpeed = self.public.speed
    Player.currentSpeed = self.public.speed
    
    _impactFrameTimer = 0
    attackBuffer = false
    ATTACK_BUFFER = self.public.attackBufferDuration
    attackNum = 0
    attackBufferPending = false

    self.public.stamina = 100
    self.public.health  = 100
    --self.public.health  = 100000

    self.stepTimer = 0

    RefreshAudioSources(self) 

    Player.currentSurface = "Dirt"

    attackCooldown = 0
    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then attackCol:Disable() end 

    chargeCol = self.gameObject:GetComponent("Sphere Collider")
    if chargeCol then chargeCol:Disable() end 

    heavyCol = self.gameObject:GetComponent("Capsule Collider")
    if heavyCol then heavyCol:Disable() end

    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil

    Player.rb = self.gameObject:GetComponent("Rigidbody")
    if not Player.rb then
        Engine.Log("[Player] No rigidbody found")
    end
    
    Player.isDrowning       = false
    Player.hermesGraceTimer = 0
    _G._PlayerController_currentMask = ""
	
    local smokeObj = GameObject.FindInChildren(self.gameObject, "SmokeTrail")
    if smokeObj then
        Player.smokePS = smokeObj:GetComponent("ParticleSystem")
        if Player.smokePS then
            Player.smokePS:Stop()
        end
    end

    local bubblesObj = GameObject.FindInChildren(self.gameObject, "WaterTrail")
    if bubblesObj then
        Player.bubblesPS = bubblesObj:GetComponent("ParticleSystem")
        if Player.bubblesPS then
            Player.bubblesPS:Stop()
        end
    end

    local bloodThinObj = GameObject.FindInChildren(self.gameObject, "BloodDrops01")
    if bloodThinObj then
        Player.thinBloodPs = bloodThinObj:GetComponent("ParticleSystem")
        if Player.thinBloodPs then
            Player.thinBloodPs:Stop()
        end
    end

    local bloodWideObj = GameObject.FindInChildren(self.gameObject, "BloodDrops02")
    if bloodWideObj then
        Player.wideBloodPs = bloodWideObj:GetComponent("ParticleSystem")
        if Player.wideBloodPs then
            Player.wideBloodPs:Stop()
        end
    end

    local hermesRunObj = GameObject.FindInChildren(self.gameObject, "HermesTrail")
    if hermesRunObj then
        Player.hermesRunPS = hermesRunObj:GetComponent("ParticleSystem")
        if Player.hermesRunPS then
            Player.hermesRunPS:Stop()
        end
    end

    _G.SetPlayerCanMove = function(value)
        self.public.canMove = value
    end

    _G._PlayerController_isDead = false


    giveApoloMask       = false
    giveHermesMask      = false
    giveAresMask        = false

    _G._MaskState_Hermes = false
    _G._MaskState_Apolo  = false
    _G._MaskState_Ares   = false

    FindMasks(self)
    InitParticles(self)
    EquipMask(self, Mask.NONE)
    Player.currentMask = Mask.NONE

    Audio.SetSwitch("Player_Mask", tostring(Player.currentMask), Player.changeMaskSFX)

    if Player.rb then
        Player.rb:SetLinearVelocity(0, 0, 0)
    end

    Player.maskAnimTimer = 0.0
    Player.currentState = State.IDLE
    ChangeState(self, State.IDLE, true)

    self.EquipMask = EquipMask
    self.MaskScroll = MaskScroll

    -- Hit vignette init
    hitVigTimer = 0.0
    accumulatedAlpha = 0.0
    local camObj = GameObject.Find("MainCamera")
    if camObj then
        postProcess = camObj:GetComponent("PostProcessing")
    end
    if postProcess then
        postProcess:SetVignetteEnabled(false)
    end
end

FindMasks = function(self)
    maskApolo = GameObject.FindInChildren(self.gameObject,"MaskApolo")
    maskHermes = GameObject.FindInChildren(self.gameObject,"MaskHermes")
    maskAres = GameObject.FindInChildren(self.gameObject,"MaskAres")

    if maskApolo then maskApolo:SetActive(false) end
    if maskHermes then maskHermes:SetActive(false) end
    if maskAres then maskAres:SetActive(false) end
end

InitParticles = function(self)

    if not self.gameObject or not self.gameObject.transform then return end

    vfxApolo        = GameObject.FindInChildren(self.gameObject, "VFXapolo")
    swordApolo      = GameObject.FindInChildren(self.gameObject, "Xiphos_Apolo")
    vfxApoloAttack  = GameObject.FindInChildren(self.gameObject, "VFXapoloAttack")
    vfxHermes       = GameObject.FindInChildren(self.gameObject, "VFXhermes")
    swordHermes     = GameObject.FindInChildren(self.gameObject, "Xiphos_Hermes")
    vfxHermesAttack = GameObject.FindInChildren(self.gameObject, "VFXhermesAttack")
    vfxAres         = GameObject.FindInChildren(self.gameObject, "VFXares")
    swordAres       = GameObject.FindInChildren(self.gameObject, "Xiphos_Ares")
    vfxAresAttack   = GameObject.FindInChildren(self.gameObject, "VFXaresAttack")
    vfxTrail        = GameObject.FindInChildren(self.gameObject, "VFXtrail")

    Player.apoloPs       = nil
    Player.apoloAttackPs = nil
    Player.hermesPs      = nil
    Player.hermesAttackPs= nil
    Player.aresPs        = nil
    Player.aresAttackPs  = nil
    Player.trailPs       = nil
    Player.apoloLight    = nil
    Player.hermesLight   = nil
    Player.aresLight     = nil

    if vfxApolo then
        Player.apoloPs    = vfxApolo:GetComponent("ParticleSystem")
        Player.apoloLight = vfxApolo:GetComponent("Light")
        if Player.apoloPs    then Player.apoloPs:Stop() end
        if Player.apoloLight then Player.apoloLight:SetEnabled(false) end
        vfxApolo:SetActive(false)
    end
    if vfxHermes then
        Player.hermesPs    = vfxHermes:GetComponent("ParticleSystem")
        Player.hermesLight = vfxHermes:GetComponent("Light")
        if Player.hermesPs    then Player.hermesPs:Stop() end
        if Player.hermesLight then Player.hermesLight:SetEnabled(false) end
        vfxHermes:SetActive(false)
    end
    if vfxAres then
        Player.aresPs    = vfxAres:GetComponent("ParticleSystem")
        Player.aresLight = vfxAres:GetComponent("Light")
        if Player.aresPs    then Player.aresPs:Stop() end
        if Player.aresLight then Player.aresLight:SetEnabled(false) end
        vfxAres:SetActive(false)
    end
    if vfxApoloAttack then
        Player.apoloAttackPs = vfxApoloAttack:GetComponent("ParticleSystem")
        if Player.apoloAttackPs then Player.apoloAttackPs:Stop() end
    end
    if vfxHermesAttack then
        Player.hermesAttackPs = vfxHermesAttack:GetComponent("ParticleSystem")
        if Player.hermesAttackPs then Player.hermesAttackPs:Stop() end
    end
    if vfxAresAttack then
        Player.aresAttackPs = vfxAresAttack:GetComponent("ParticleSystem")
        if Player.aresAttackPs then Player.aresAttackPs:Stop() end
    end
    if vfxTrail then
        Player.trailPs = vfxTrail:GetComponent("ParticleSystem")
        if Player.trailPs then Player.trailPs:Stop() end
    end

    local smokeObj = GameObject.FindInChildren(self.gameObject, "SmokeTrail")
    if smokeObj then
        Player.smokePS = smokeObj:GetComponent("ParticleSystem")
        if Player.smokePS then Player.smokePS:Stop() end
    end
    local bubblesObj = GameObject.FindInChildren(self.gameObject, "WaterTrail")
    if bubblesObj then
        Player.bubblesPS = bubblesObj:GetComponent("ParticleSystem")
        if Player.bubblesPS then Player.bubblesPS:Stop() end
    end

    swordGameObject = GameObject.FindInChildren(self.gameObject, "Xiphos")
    swordMat = nil
    if swordGameObject then
        swordMat = swordGameObject:GetComponent("Material")
    end
    UpdateSwordMaterial()

    Player.bullet = nil
    Player.bulletReady = false
end

function UpdateHitVignette(dt)
    if not postProcess then return end
    if hitVigTimer <= 0 then 
        accumulatedAlpha = 0.0
        _G._hitVigActive = false
        return 
    end

    _G._hitVigActive = true
    local totalDuration = HIT_VIG_FADE_IN + HIT_VIG_HOLD + HIT_VIG_FADE_OUT
    local elapsed = totalDuration - hitVigTimer
    local alpha = 0.0

    if elapsed < HIT_VIG_FADE_IN then
        alpha = (elapsed / HIT_VIG_FADE_IN) * accumulatedAlpha
    elseif elapsed < HIT_VIG_FADE_IN + HIT_VIG_HOLD then
        alpha = accumulatedAlpha
    else
        local fadeElapsed = elapsed - HIT_VIG_FADE_IN - HIT_VIG_HOLD
        alpha = (1.0 - (fadeElapsed / HIT_VIG_FADE_OUT)) * accumulatedAlpha
    end

    alpha = math.max(0.0, alpha)

    hitVigTimer = hitVigTimer - dt

    if hitVigTimer <= 0 then
        hitVigTimer = 0
        accumulatedAlpha = 0.0
        _G._hitVigActive = false
        return 
    end

    postProcess:SetVignetteEnabled(true)
    postProcess:SetVignetteSmoothness(0.6)
    postProcess:SetVignetteColor(1.0, 0.0, 0.0, alpha)
end

function Update(self, dt)

    if not Player.bulletReady then
        Player.bulletReady = true
        _G.nextBulletData = { x=0, y=-1000, z=0, dirX=0, dirZ=1, angle=0, scale=self.public.bulletScale or 1.0 }
        Player.bullet = Prefab.Instantiate(self.public.bulletPrefab)
    end

    if _G.interact == true then _G.interact = false end
    if self.public.interact == true then self.public.interact = false end

    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        self.public.interact = true
        _G.interact = true
    end

    if attackCooldown > 0 then
        attackCooldown = attackCooldown - dt
    end
    if rollCooldown > 0 then
        rollCooldown = rollCooldown - dt
    end

    if _G._PlayerController_introAnim then
        if _G.LoadedFromSave then
            _G._PlayerController_introAnim = false
            wakeUpCinematic = false
            Engine.Log("[Player] Cinemática de intro cancelada por carga de partida.")
            Audio.SetMusicState("Level1")
            Engine.Log("[Player] Switched to Level1 BGM")
        else
            Player.AnimTimer = 20.0
            local anim = self.gameObject:GetComponent("Animation")
            if anim then
                pcall(function() anim:Play("WakeUp", 0.0) end)
            end
            _G._PlayerController_introAnim = false
            if _G.PlayWakeUpCinematic then 
                _G.PlayWakeUpCinematic() 
            end
            wakeUpCinematic = true
            --Audio.SetMusicState("Level1_Intro")
            --Engine.Log("[Player] Switched to Level1_Intro BGM")
        end
    end


    if _PlayerController_pendingDamage and _PlayerController_pendingDamage > 0 then
        if Player.AnimTimer > 0 then
            _PlayerController_pendingDamage    = 0
            _PlayerController_pendingDamagePos = nil
        else
        TakeDamage(self, _PlayerController_pendingDamage, _PlayerController_pendingDamagePos)
        _PlayerController_pendingDamage    = 0
        _PlayerController_pendingDamagePos = nil
        end
    end
    

    if not Player.currentState then
        Player.currentState = nil
        ChangeState(self, State.IDLE, true)
    end
    
    if self.public.stamina < 0.5 then 
        staminaLock = true
    end
    if self.public.stamina == 100 and staminaLock == true then
        staminaLock = false
    end

    if not maskApolo or not maskAres or not maskHermes then
        Engine.Log("Masks not found, retrieving from hierarchy...")
        FindMasks(self)
    end

    if Player.rb then
        local vel = Player.rb:GetLinearVelocity()
        local actualSpeed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
        Audio.SetRTPCValue("Player_Speed", actualSpeed)
    end

    if Player.stepSFX and Player.voiceSFX then
        if Player.currentMask == Mask.HERMES then
            if Player.currentState ~= State.DEAD then
                if not Audio.IsEventPlaying("SFX_HermesWind") then 
                    Player.stepSFX:SelectPlayAudioEvent("SFX_HermesWind")
                    --Engine.Log("[PLAYER] Playing Wind Hover SFX") 
                end
            end

            if Player.currentState == State.WALK or Player.currentState == State.RUNNING then 
            
                if not Audio.IsEventPlaying("SFX_HermesFlare") then 
                    Player.voiceSFX:SelectPlayAudioEvent("SFX_HermesFlare")
                    --Engine.Log("[PLAYER] Playing Hover SFX") 
                end
            else
                Player.voiceSFX:SelectStopAudioEvent("SFX_HermesFlare") 
            end
        end

        if Player.currentMask ~= Mask.HERMES then
            Player.stepSFX:SelectStopAudioEvent("SFX_HermesWind") 
            Player.voiceSFX:SelectStopAudioEvent("SFX_HermesFlare") 
            
        end
    end

    --heartbeat sound
    if Player.heartSFX then 
        if Player.currentState ~= State.DEAD then
            Audio.SetRTPCValue("Player_Health", self.public.health)
            if not Audio.IsEventPlaying("SFX_HeartBeat") then
                Player.heartSFX:SelectPlayAudioEvent("SFX_HeartBeat")
            end
        else
            Player.heartSFX:StopAudioEvent()
        end
    end
        

    

    local sceneLoaderCount = _G._SceneLoaderCounter or 0
    if not Player.lastSceneCounter or Player.lastSceneCounter ~= sceneLoaderCount then
        Player.lastSceneCounter = sceneLoaderCount
        Engine.Log("[Player] New Scene Detected (Counter: " .. tostring(sceneLoaderCount) .. ") - Resetting persistent state")
        
        Game.Resume()
        Game.SetTimeScale(1.0)
        
        
        Player.rb = self.gameObject:GetComponent("Rigidbody")

        self.gameObject:SetTag("PersistentPlayer")
        local dummyPlayer = GameObject.Find("Player")
     
        if dummyPlayer and dummyPlayer.tag ~= "PersistentPlayer" and dummyPlayer ~= self.gameObject then
            Engine.Log("[Player] Destroying dummy player from scene to prevent AudioListener conflicts")
            GameObject.Destroy(dummyPlayer)
        end
        self.gameObject:SetTag("Player")

        Player.restoreListenerFrames = 2
        
        Player.masterAudioTimer = 5.0
        Audio.SetGlobalVolume(100.0)
        mGo = GameObject.Find("MusicSource")
        if mGo then
            musicComp = mGo:GetComponent("Audio Source")
            if musicComp then musicComp:SetSourceVolume(100.0) end
        end
        
        RefreshAudioSources(self)
        InitParticles(self)
        FindMasks(self)

        if _G.IsLoadingSaveGame and _G.SaveManager then
            Engine.Log("[Player] CARGANDO PARTIDA: Aplicando datos guardados...")
            _G.SaveManager.ApplyLoadedData(self.gameObject)
            _G.IsLoadingSaveGame = false
            
            _G._PlayerController_introAnim = false 
            wakeUpCinematic = false
            
            if _G._UnlockedMasks.Apollo then Mask.APOLLO = "Apolo" end
            if _G._UnlockedMasks.Hermes then Mask.HERMES = "Hermes" end
            if _G._UnlockedMasks.Ares   then Mask.ARES   = "Ares" end

            local loadedMask = Mask.NONE
            if _G._PlayerController_currentMask == "Apolo" then loadedMask = Mask.APOLLO
            elseif _G._PlayerController_currentMask == "Hermes" then loadedMask = Mask.HERMES
            elseif _G._PlayerController_currentMask == "Ares" then loadedMask = Mask.ARES end
            
            Player.currentMask = nil
            FindMasks(self)
            EquipMask(self, loadedMask)
            UpdateSwordMaterial()
            
        else
            Engine.Log("[Player] NUEVA PARTIDA / TRANSICIÓN: Configurando estado por defecto...")
            local spawn = GameObject.Find("SpawnPoint")
            if spawn then
                pcall(function()
                    local p = spawn.transform.position
                    self.transform:SetPosition(p.x, p.y, p.z)
                end)
            end

            local maskToRestore = Mask.NONE
            if _G._MidRunTransition then
                _G._MidRunTransition = false
                _G._UnlockedMasks = _G._UnlockedMasks or {}
                if _G._UnlockedMasks.Apollo  then Mask.APOLLO = "Apolo";  _G._MaskState_Apolo  = true end
                if _G._UnlockedMasks.Hermes  then Mask.HERMES = "Hermes"; _G._MaskState_Hermes = true end
                if _G._UnlockedMasks.Ares    then Mask.ARES   = "Ares";   _G._MaskState_Ares   = true end

                if _G._SavedCurrentMask == "Apolo" then maskToRestore = Mask.APOLLO
                elseif _G._SavedCurrentMask == "Hermes" then maskToRestore = Mask.HERMES
                elseif _G._SavedCurrentMask == "Ares" then maskToRestore = Mask.ARES
                end
            else
                _G._UnlockedMasks    = {}
                _G._MaskState_Apolo  = false
                _G._MaskState_Hermes = false
                _G._MaskState_Ares   = false
            end

            Player.currentMask = nil
            EquipMask(self, maskToRestore)
            UpdateSwordMaterial()
        end

        self.public.staminaCost    = 20.0   
        self.public.staminaRecover = 25.0 
        Player.baseSpeed = self.public.speed
        Player.currentSpeed = self.public.speed

        hitVigTimer = 0.0
        accumulatedAlpha = 0.0
        if postProcess then postProcess:SetVignetteEnabled(false) end
        
        local camObj = GameObject.Find("MainCamera")
        if camObj then
            postProcess = camObj:GetComponent("PostProcessing")
        end
        
        Player.firstFrameCheck = true
        Player.forceResumeFrames = 10
    end

    if Player.masterAudioTimer and Player.masterAudioTimer > 0 then
        Player.masterAudioTimer = Player.masterAudioTimer - dt
        Audio.SetGlobalVolume(100.0)
    end

    if Player.restoreListenerFrames then
        Player.restoreListenerFrames = Player.restoreListenerFrames - 1
        if Player.restoreListenerFrames <= 0 then
            local listenerObj = GameObject.Find("Listener")
            if listenerObj then
                local lComp = listenerObj:GetComponent("Audio Listener")
                if lComp and lComp.SetAsDefaultListener then
                    lComp:SetAsDefaultListener()
                end
            end
            Player.restoreListenerFrames = nil
        end
    end

    if Player.forceResumeFrames and Player.forceResumeFrames > 0 then
        Player.forceResumeFrames = Player.forceResumeFrames - 1
        if Player.forceResumeFrames == 0 then
            if not _G.GlobalMenuManagerInstance then
                local uiObj = GameObject.Find("MenuManager") or GameObject.Find("Canvas")
                if uiObj then
                    local canvas = uiObj:GetComponent("Canvas")
                    if canvas and canvas:GetCurrentXAML() == "MainMenu.xaml" then
                        canvas:LoadXAML("HUD.xaml")
                        _G.CurrentXAML = "HUD.xaml"
                    end
                end
                Game.Resume()
                Game.SetTimeScale(1.0)
                Engine.Log("[Player] FIX: Resume forzado por ausencia de MenuManager")
            end
        end
    end

    if Player.maskAnimTimer > 0 then
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        Player.maskAnimTimer = Player.maskAnimTimer - dt
        if Player.maskAnimTimer <= 0 then
            Player.maskAnimTimer = 0
            self.public.canMove = true
            ChangeState(self, State.IDLE)
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                local ok, err = pcall(function() anim:Play(GetAnimName("Idle"), 0.3) end)
                    if not ok then
                    Engine.Log("[Player] anim:Play failed: " .. tostring(err))
                end
                --pcall(function() anim:Play(GetAnimName("Idle"), 0.05) end)
            end
            ChangeState(self, State.IDLE, true)
        end
    end

    if hurtTimer > 0 then
        hurtTimer = hurtTimer - dt
        if hurtTimer <= 0 then
            hurtTimer = 0
            local anim = self.gameObject:GetComponent("Animation")
            if anim then
                if Player.currentState == State.RUNNING then
                    anim:Play(GetAnimName("Running"), 0.2)
                elseif Player.currentState == State.WALK then
                    anim:Play(GetAnimName("Walk"), 0.2)
                elseif Player.currentState == State.IDLE then
                    anim:Play(GetAnimName("Idle"), 0.2)
                end
            end
        end
    end

    if iFramesTimer > 0 then
        iFramesTimer = iFramesTimer - dt
        if iFramesTimer <= 0 then iFramesTimer = 0 end
    end

    if Player.AnimTimer > 0 then
        _G.PlayerInAnim = true
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        Player.AnimTimer = Player.AnimTimer - dt

        if _G._BossIntroCinematic then
            if Player.rb then Player.rb:SetRotation(-180, 0, -180) end
        end
        
        if wakeUpCinematic then
            
           
            if Player.AnimTimer <= 18.0 and Player.AnimTimer >= 17.9 and not Audio.IsEventPlaying("SFX_SandStir") then
                if Player.stepSFX then 
                    --Audio.SetSFXVolume(50.0)
                    Player.stepSFX:SelectPlayAudioEvent("SFX_SandStir") 
                    --Engine.Log("[WAKE UP] Played Sand Stir!")
                    --Audio.SetSFXVolume(100.0)
                end
            
            end

            -- step 2
            if Player.AnimTimer <= 10.5 and Player.AnimTimer >= 10.3 and not Audio.IsEventPlaying("SFX_SandStep1") then
                if Player.stepSFX then 
                
                    Player.stepSFX:SelectPlayAudioEvent("SFX_SandStep1")
                    --Engine.Log("[WAKE UP] Played Step 1!")
                end
            end

            -- sword on sand
            if Player.AnimTimer <= 9.8 and Player.AnimTimer >= 9.6 and not Audio.IsEventPlaying("SFX_SwordSandStab") then
                if Player.swordSFX then 
                    Player.swordSFX:SelectPlayAudioEvent("SFX_SwordSandStab") 
                    --Engine.Log("[WAKE UP] Played Sand Stab!")
                end
            end

            -- sword retrieval
            if Player.AnimTimer <= 6.5 and Player.AnimTimer >= 6.3 and not Audio.IsEventPlaying("SFX_SwordSandUnStab") then
                if Player.swordSFX then 
                    Audio.SetSFXVolume(70.0)
                    Player.swordSFX:SelectPlayAudioEvent("SFX_SwordSandUnStab") 
                    --Engine.Log("[WAKE UP] Played Unstab!")
                    Audio.SetSFXVolume(100.0)
                end
            end

            -- step 3
            if Player.AnimTimer <= 5.4 and Player.AnimTimer >= 5.2 and not Audio.IsEventPlaying("SFX_SandStep2") then
                if Player.stepSFX then 
                    Player.stepSFX:SelectPlayAudioEvent("SFX_SandStep2") 
                -- Engine.Log("[WAKE UP] Played Step 2!")
                end
            end

            -- zoom out
            if Player.AnimTimer <= 5.0 and Player.AnimTimer >= 4.8 and not Audio.IsEventPlaying("SFX_ZoomOut") then
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_ZoomOut") 
                    --Engine.Log("[WAKE UP] Played Zoom Out!")
                end
            end

            -- step 4
            if Player.AnimTimer <= 4.4 and Player.AnimTimer >= 4.3 then
                if not Audio.IsEventPlaying("SFX_SandStep3") then
                    if Player.stepSFX then 
                        Player.stepSFX:SelectPlayAudioEvent("SFX_SandStep3") 
                        --Engine.Log("[WAKE UP] Played Step 3!")
                    end
                else 
                    --Engine.Log("[WAKE UP] CinematicSandSteps already playing!") 
                end
            else 
                --Engine.Log("[WAKE UP] Something's up with the PlayerTimer")
            end


            

            

            if Player.AnimTimer < 0 then 
                wakeUpCinematic = false
                Audio.SetMusicState("Level1")
                --Engine.Log("[Player] Switched to Level1 BGM")
                Player.AnimTimer = 0
            end

        end

        if enterPortalCinematic then 
            timer = 20.0

            if not anim then
                 enterPortalCinematic = false 
                 return 
            end 

            if anim then
                if not anim:IsPlayingAnimation("PortalEnter") then
                     enterPortalCinematic = false 
                    return 
                end
            end

            Audio.SetMusicVolume(10)


            --Steps SFX have to be fired too close to each other so another audiosource (heartsource) will be used to alternate 
            --step 1
            if Player.AnimTimer <= 19.32 and not playedStep1 then
            
                if not Player.heartSFX:IsPlaying("SFX_CinematicStoneSteps") then 
                    if Player.heartSFX then 
                        Player.heartSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps")
                        Engine.Log("Played Step 1") 
                        playedStep1 = true
                    else
                        --Engine.Log("Unable to retrieve heartSFX Audio Source Component")
                    end
                else
                    --Engine.Log("SFX_PlayerFootSteps already playing from heartSFX")
                end
            end

            --step 2
            if Player.stepSFX then
                if Player.AnimTimer <= 19.21 and not playedStep2 then 
                    Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") 
                    Engine.Log("Played Step 2")
                    playedStep2 = true
                end
            end
            

            --step 3
            if Player.heartSFX then 
                if Player.AnimTimer <= 18.33 and not playedStep3 then
                    Player.heartSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps")
                    Engine.Log("Played Step 3")
                    playedStep3 = true
                end
            end

            --step 4
            if Player.stepSFX then 
                if Player.AnimTimer <= 17.625 and not playedStep4 then
                    Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps")
                    Engine.Log("Played Step 4")
                    playedStep4 = true
                end
            end

            --start ghost screams
            if Player.AnimTimer <= 16.8 and Player.AnimTimer >= 16.6 and not Audio.IsEventPlaying("SFX_EP_Ghosts") then

                --playing right in the player's ears BUT THIS SOUND HAS PANNING hehe :3
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_EP_Ghosts")
                    Engine.Log("Played Ghost Screams") 
                end

            end

            --step 5
            if Player.AnimTimer <= 16.66 and not playedStep5 then
                if Player.heartSFX then 
                    Player.heartSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps")
                    Engine.Log("Played Step 5") 
                    playedStep5 = true
                end
            end

            -- DARK ENERGY
            if Player.AnimTimer <= 13.8 and Player.AnimTimer >= 13.7 and not Audio.IsEventPlaying("SFX_EP_DarkEnergy") then
                if Player.heartSFX then 
                    Player.heartSFX:SelectPlayAudioEvent("SFX_EP_DarkEnergy")
                    Engine.Log("Played Dark Energy")  
                end
            end

            --step 6
            if Player.stepSFX then 
                if Player.AnimTimer <= 11.625 and not playedStep6 then
                    Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") 
                    Engine.Log("Played Step 6")  
                    playedStep6 = true
                end
            end
            
            if Player.AnimTimer <= 11.21 and Player.AnimTimer >= 11.1 and not Audio.IsEventPlaying("SFX_EP_TeleScared") then
                if Player.voiceSFX then 
                    Audio.SetSwitch("Player_Voice", "Scared", Player.voiceSFX)
                    Player.voiceSFX:SelectPlayAudioEvent("SFX_EP_TeleScared")
                    Engine.Log("Played TeleScared")  
                end
            end

            -- riser
            if Player.AnimTimer <= 9.87 and Player.AnimTimer >= 9.7 and not Audio.IsEventPlaying("SFX_EP_PortalRiser") then
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_EP_PortalRiser") 
                     Engine.Log("Played Portal Riser")  
                end
            end

            if Player.AnimTimer <= 0 then
                enterPortalCinematic = false
                playedStep1 = false
                playedStep2 = false
                playedStep3 = false
                playedStep4 = false
                playedStep5 = false
                playedStep6 = false
                Player.AnimTimer = 0
                Engine.Log("Ended Enter Portal Cinematic")
                Audio.SetMusicVolume(0)
                
            end


        end

        if exitPortalCinematic  then
            timer = 18.0

            if not anim then
                exitPortalCinematic = false 
                return 
            end 

            if anim then
                if not anim:IsPlayingAnimation("PortalExit") then
                    exitPortalCinematic = false 
                    return 
                end
            end
            
            --breath in-out
            if Player.AnimTimer <= 17.8 and Player.AnimTimer >= 17.6 and not Audio.IsEventPlaying("SFX_EL_Panting") then 
                if Player.voiceSFX then 
                    Player.voiceSFX:SelectPlayAudioEvent("SFX_EL_Panting") 
                    Engine.Log("Played Panting SFX")
                end
                
            end
            
            --whispering ghost
            if Player.AnimTimer <= 17.8 and Player.AnimTimer >= 17.6 and not Audio.IsEventPlaying("SFX_EL_GWhispers") then 
                if Player.heartSFX then 
                    Player.heartSFX:SelectPlayAudioEvent("SFX_EL_GWhispers")
                    Engine.Log("Played Whispering Ghosts SFX") 
                end
            end

            --themin ghost
            if Player.voiceSFX then
                if Player.AnimTimer <= 17.8 and Player.AnimTimer >= 17.6 and not Player.voiceSFX:IsPlaying("SFX_EL_GThemin") then 
                    Player.voiceSFX:SelectPlayAudioEvent("SFX_EL_GThemin") 
                    Engine.Log("Played Themin Ghosts") 
                end
            end

            --screaming ghost
            if Player.voiceSFX then
                if Player.AnimTimer <= 12.2 and Player.AnimTimer >= 12.1 and not Player.voiceSFX:IsPlaying("SFX_EL_GScream") then 
                    if Player.voiceSFX then 
                        Player.voiceSFX:SelectPlayAudioEvent("SFX_EL_GScream") 
                        Engine.Log("Played Screaming Ghosts") 
                    end
                end
            end


            --cam pan whoosh
            if Player.AnimTimer <= 16.2 and Player.AnimTimer >= 16.1 and not Audio.IsEventPlaying("SFX_EL_CamWhoosh") then 
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_EL_CamWhoosh")
                    Engine.Log("Played Camera Pan Whoosh SFX")  
                end
            end

            --sword up
            if Player.AnimTimer <= 6.4 and Player.AnimTimer >= 6.3 and not Audio.IsEventPlaying("SFX_EL_SwordUp") then 
                if Player.swordSFX then
                    Engine.Log("Played Sword Up SFX") 
                    Player.swordSFX:SelectPlayAudioEvent("SFX_EL_SwordUp") 
                end
            end

            --sword down
            if Player.AnimTimer <= 6.125 and Player.AnimTimer >= 6.0 and not Audio.IsEventPlaying("SFX_EL_SwordDown") then 
                if Player.swordSFX then 
                    Player.swordSFX:SelectPlayAudioEvent("SFX_EL_SwordDown")
                    Engine.Log("Played Sword Down SFX") 
                end
            end

            --cam zoom out
            if Player.AnimTimer <= 4.54 and Player.AnimTimer >= 4.4 and not Audio.IsEventPlaying("SFX_EL_ZoomOut") then 
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_EL_ZoomOut")
                    Engine.Log("Played Camera Zoom Out SFX") 
                end
            end
            
            if Player.AnimTimer <= 0 then
                exitPortalCinematic = false
                Player.AnimTimer = 0
            end

        end

        if winBossCinematic then

            if not anim then
                winBossCinematic = false 
                return 
            end 

            if anim then
                if not anim:IsPlayingAnimation("WinBoss") then
                    winBossCinematic = false 
                    return 
               end
            end

            self.transform:SetPosition(131.348, -1.259, -650.359)
            if Player.rb then Player.rb:SetRotation(-180, 90, -180) end

            

            if musicComp and Audio.IsEventPlaying("MUS_BGM") then 
                --Engine.Log("Stopped MUS_BGM")
                musicComp:StopAudioEvent() --WIP, should fade gradually
            end

            --Engine.Log("[PLAYER] Playing Final Blow Cinematic")

            --Engine.Log("Remaining Anim Time: " ..tostring(Player.AnimTimer))


            if Player.AnimTimer <= 21.8 and Player.AnimTimer >= 21.7 and not playedEpicBGM then
                if Player.voiceSFX then 
                    Player.voiceSFX:SelectPlayAudioEvent("MUS_FinalBlow")
                    playedEpicBGM = true
                end
            end

            if Player.AnimTimer <= 15.16 and Player.AnimTimer >= 15.00 and not playedSwordPrep then
                if Player.itemSFX then 
                    Player.itemSFX:SelectPlayAudioEvent("SFX_SwordPrep") 
                    --Engine.Log("[PLAYER] Playing SwordPrep")
                    playedSwordPrep = true
                end
                 
            end

            --Step 1
            if Player.AnimTimer <= 14.95 and Player.AnimTimer >= 14.8 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
                --Engine.Log("[PLAYER] Playing Cinematic FootSteps") 
            end
            --Step 2
            if Player.AnimTimer <= 14.3 and Player.AnimTimer >= 14.2 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end

            --Unsheathe + riser
            if Player.AnimTimer <= 13.8 and Player.AnimTimer >= 13.7 and not playedUnsheathe then
                if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_Unsheathe") end 
                --Engine.Log("[PLAYER] Playing Cinematic Unsheathe") 
                playedUnsheathe = true
            end

            --Step 3
            if Player.AnimTimer <= 13.4 and Player.AnimTimer >= 13.3 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end
            --Step 4
            if Player.AnimTimer <= 12.6 and Player.AnimTimer >= 12.5 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end

            -- big sword slash + flesh rip
            if Player.AnimTimer <= 9.9 and Player.AnimTimer >= 9.8 and not playedFinishHim then
                if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_FinishHim") end
                playedFinishHim = true
            end

            --Step 5
            if Player.AnimTimer <= 8.01 and Player.AnimTimer >= 7.85 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end

            --Step 6 (meant to overlap --> will send to different audiosource)
            if Player.AnimTimer <= 7.825 and Player.AnimTimer >= 7.5 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then 
                if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end
            
            --Step 7
            if Player.AnimTimer <= 7.0 and Player.AnimTimer >= 6.8 and not Audio.IsEventPlaying("SFX_CinematicStoneSteps") then
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_CinematicStoneSteps") end
            end

            --Step 8
            if Player.AnimTimer <= 6.125 and Player.AnimTimer >= 5.5 and not playedSwordSwing then
                if Player.swordSFX then Player.swordSFX:SelectPlayAudioEvent("SFX_GM_Sword1") end
                playedSwordSwing = true
            end

            if Player.AnimTimer <= 4.0 and Player.AnimTimer >= 3.5 and not playedFinalNote then
                if Player.voiceSFX then Player.voiceSFX:SelectPlayAudioEvent("MUS_FinalNote") end
                playedFinalNote = true
            end
            
            
            --end of cinematic
            if Player.AnimTimer <= 0 then
                winBossCinematic = false
                Audio.SetMusicState("AfterBoss")
                Player.AnimTimer = 0
                if musicComp then musicComp:SelectPlayAudioEvent("MUS_BGM") end
                playedEpicBGM = false
                playedFinalNote = false
                playedFinishHim = false
                playedSwordSwing = false
                playedUnsheathe = false
                playedSwordPrep = false
            end
        end 
        
        if Player.isGetMaskAnim and Player.pendingObtainMask then
            if Player.pendingObtainMask == Mask.HERMES then 
                self.transform:SetPosition(-68.549, 2.357, -323.0) 
                if Player.rb then Player.rb:SetRotation(180, 0, 180) end
            end
            if Player.pendingObtainMask == Mask.APOLLO then 
                self.transform:SetPosition(203.921, 35.586, -178.304) 
                if Player.rb then Player.rb:SetRotation(0, 88.814, 0) end
            end
            if Player.pendingObtainMask == Mask.ARES then
                self.transform:SetPosition(77.0, 8.898, -108.0) 
                if Player.rb then Player.rb:SetRotation(-180, 0, -180) end
            end
        end

        if Player.isPortalEnterAnim then
            self.transform:SetPosition(97.633, -0.811, -178.289)
            if Player.rb then Player.rb:SetRotation(0, 63.986, 0) end

            enterPortalCinematic = true
            
        end

        if Player.isPortalExitAnim then
            if Player.rb then Player.rb:SetRotation(180, 90, 180) end
            exitPortalCinematic = true
        end

        if Player.isGetMaskAnim and Player.AnimTimer <= 27.25 and Player.AnimTimer >= 27.0 and not Audio.IsEventPlaying("SFX_GM_KnockBack") then 
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_KnockBack") end
        end

        if Player.isGetMaskAnim and Player.AnimTimer <= 24.0 and Player.AnimTimer >= 23.9 and not Audio.IsEventPlaying("SFX_GM_MaskFly") then 
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_MaskFly") end
        end

        if Player.isGetMaskAnim and not Player.getMaskEvent1Done and Player.AnimTimer <= 20.0 then
            Player.getMaskEvent1Done = true
            if Player.pendingObtainMask then
                EquipMask(self, Player.pendingObtainMask, true)
                if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_MaskOn") end
            end
        end

        if Player.isGetMaskAnim and Player.AnimTimer <= 16.1 and Player.AnimTimer >= 16.0 and not Audio.IsEventPlaying("SFX_GM_FallDown") then 
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_FallDown") end
        end

        if Player.isGetMaskAnim and Player.AnimTimer <= 10.0 and Player.AnimTimer >= 9.9 and not Audio.IsEventPlaying("SFX_GM_Sword1") then 
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_Sword1") end
        end

        if Player.isGetMaskAnim and Player.AnimTimer <= 8.5 and Player.AnimTimer >= 8.0 and not Audio.IsEventPlaying("SFX_GM_Sword2") then 
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GM_Sword2") end
        end

        if Player.isGetMaskAnim and not Player.getMaskEvent2Done and Player.AnimTimer <= 7.7 then
            Player.getMaskEvent2Done = true
            UpdateSwordMaterial()
        end

        if Player.AnimTimer <= 1.8 and not Player.getMaskIdleTransitionDone then
            Player.getMaskIdleTransitionDone = true
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play(GetAnimName("Idle"), 1.5) end)
            end
        end

        if Player.AnimTimer <= 0 then
            _G.PlayerInAnim = false
            Player.AnimTimer = 0
            self.public.canMove = true
            if exitPortalCinematic then
                exitPortalCinematic = false
            end

            if Player.isPortalExitAnim then
                Player.lastDirX  = 0
                Player.lastDirZ  = 1
                Player.lastAngle = 0
                if Player.rb then Player.rb:SetRotation(0, 180, 0) end
            end

            ChangeState(self, State.IDLE)
            ChangeState(self, State.IDLE, true)

            if _G.ShowMaskObtained and Player.pendingObtainMask then
                _G.ShowMaskObtained(Player.pendingObtainMask:lower())
            end

            if _G.ShowControlsHint and Player.pendingObtainMask then
                if Player.pendingObtainMask == Mask.APOLLO then
                    _G.ShowControlsHint("apolo_puzzle")
                    _G.ShowControlsHint("apolo_puzzleDisparo")
                end
            end

            Player.isGetMaskAnim = false
            Player.pendingObtainMask = nil
            Player.isPortalEnterAnim = false
            Player.isPortalExitAnim  = false

            if WinBoss then WinBoss = false end

            if Player.pendingMaskInfoDialog then
                Player.pendingMaskInfoDialog = false
                _G._MaskInfoShown = true
                if _G.TriggerSequence then
                    _G.TriggerSequence("maskInfo")
                end
            end
        end
    end

    if attackBuffer == true and Player.currentState ~= State.ATTACK_LIGHT then
        self.public.attackBufferDuration = self.public.attackBufferDuration - dt
        if self.public.attackBufferDuration < 0 then
            self.public.attackBufferDuration = ATTACK_BUFFER
            attackBuffer = false
        end
    end

    if Player.godMode then
        UpdateFlyingGodMode(self, dt)
    elseif Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)

        if (Player.currentState == State.IDLE or Player.currentState == State.WALK) and self.public.stamina < 100 then
            if not (Player.isDrowning and Player.currentMask == Mask.HERMES) then
                self.public.stamina = math.min(100, self.public.stamina + (self.public.staminaRecover * dt))
            end
        end
    end

    if Input.GetKeyDown("7") and not Player.godMode then
        self.public.health = math.max(0, self.public.health - self.public.hpLossCost)
    end

    if Input.GetKeyDown("G") then
        Player.godMode = not Player.godMode
        if Player.rb then
            Player.rb:SetUseGravity(not Player.godMode)
            if not Player.godMode then
                Player.rb:SetLinearVelocity(0, 0, 0)
                ChangeState(self, State.IDLE)
            end
        end
    end

    if Player.healAnimTimer > 0 then
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        Player.healAnimTimer = Player.healAnimTimer - dt
        if Player.healAnimTimer <= 0 then
            Player.healAnimTimer = 0
            if Player.healPending then
                Player.healPending = false
                self.public.health = math.min(100, self.public.health + self.public.hpRecover)
            end
            self.public.canMove = true

            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play(GetAnimName("Idle"), 0.5) end)
            end
        end
    end

    if not (Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5) then
        Player.sprintHeld = false
    end

    if Input.GetKeyDown("F1") then 
        giveApoloMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then 

            if Player.currentMask ~= Mask.APOLLO then
                Audio.SetSwitch("Player_Mask", "Apolo", Player.changeMaskSFX)
                Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch")
            end
        end
    
    end

    if Input.GetKeyDown("F2") then 
        giveHermesMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then 
            if Player.currentMask ~= Mask.HERMES then
                Audio.SetSwitch("Player_Mask", "Hermes", Player.changeMaskSFX)
                Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch")
            end
        end
    end

    if Input.GetKeyDown("F3") then 
        giveAresMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then 
            if Player.currentMask ~= Mask.ARES then
                Audio.SetSwitch("Player_Mask", "Ares", Player.changeMaskSFX)
                Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch")
            end
        end
    end

    if Input.GetKeyDown("M") then
        local p = lastCheckpoint
        self.transform:SetPosition(p.x, p.y, p.z)
    end

    ObtainMask(self)

    if Player.isDrowning and Player.currentMask == Mask.HERMES and Player.currentState ~= State.DEAD and Player.isGrounded == false then
        if self.public.stamina <= 0 then
            Player.hermesDeathRespawn = true
            Player.hermesDeathTimer   = 2.3
            if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
            ChangeState(self, State.DEAD)
        end
    end

    if _impactFrameTimer > 0 then
        _impactFrameTimer = _impactFrameTimer - dt
        if _impactFrameTimer <= 0 then
            _impactFrameTimer = 0
            Game.SetTimeScale(1.0)

            if _G._AquilesDefeated and Player.currentState ~= State.DEAD then
                _G._AquilesDefeated = false
                if States[Player.currentState] and States[Player.currentState].Exit then
                    States[Player.currentState].Exit(self)
                end
                Player.currentState = State.IDLE
                if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
                self.public.canMove = false
                self.transform:SetPosition(131.348, -6.661, -650.359)
                if Player.rb then Player.rb:SetRotation(-180, 90, -180) end
                Player.AnimTimer = 22.0
                local anim = self.gameObject:GetComponent("Animation")
                if anim then
                    pcall(function() anim:Play("WinBoss", 0.0) end)
                end
                if _G.PlayWinBossCinematic then
                    _G.PlayWinBossCinematic()
                end
                
                winBossCinematic = true

                --Engine.Log("[[PLAYER] Attempting to fire Win Boss Cinematic!")
            end

        end
    end

    UpdateHitVignette(dt)
end

function MaskScroll(self)
    if Player.maskAnimTimer > 0 then return end
    if Player.currentState == State.DEAD then return end
    if not self.public.canMove then return end

    local newMask = nil
    

    if Input.GetKeyDown("Left") or Input.GetGamepadButtonDown("DPadLeft") then
        newMask = _G._MaskState_Apolo and Mask.APOLLO or nil
    elseif Input.GetKeyDown("Up") or Input.GetGamepadButtonDown("DPadUp") then
        newMask = _G._MaskState_Hermes and Mask.HERMES or nil
    elseif Input.GetKeyDown("Right") or Input.GetGamepadButtonDown("DPadRight") then
        newMask = _G._MaskState_Ares and Mask.ARES or nil
    elseif Input.GetKeyDown("Down") or Input.GetGamepadButtonDown("DPadDown") then
        newMask = Mask.NONE
        if Player.changeMaskSFX and newMask ~= Player.currentMask then 
            Audio.SetSwitch("Player_Mask", "NoMask", Player.changeMaskSFX)
            Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch") 
        end
    end

    if newMask == nil then return end

    if newMask ~= Mask.NONE and newMask == "None" then return end

    local oldMask = Player.currentMask
    EquipMask(self, newMask)

    if Player.currentState ~= State.DEAD then            
        ChangeState(self, State.IDLE, true)
    end
    

    if oldMask ~= Player.currentMask and Player.currentMask ~= Mask.NONE then
        local anim = self.gameObject:GetComponent("Animation")
        if anim then
            anim:Stop("Mask")
            anim:Play("Mask", 0.1)
        end
        Player.maskAnimTimer = Player.maskAnimDuration
        self.public.canMove = false
    end
end

function ObtainMask(self)
    local maskObtained = false
    if giveApoloMask and not (_G._UnlockedMasks and _G._UnlockedMasks.Apollo) then
        _G._MaskCount = _G._MaskCount + 1
        _G._UnlockedMasks = _G._UnlockedMasks or {}
        _G._UnlockedMasks.Apollo = true
        maskObtained = true
        Player.pendingObtainMask = Mask.APOLLO
        if _G._MaskCount == 1 and not _G._MaskInfoShown then
            Player.pendingMaskInfoDialog = true
        end
    end
    giveApoloMask = false

    if giveHermesMask and not (_G._UnlockedMasks and _G._UnlockedMasks.Hermes) then
        _G._MaskCount = _G._MaskCount + 1
        _G._UnlockedMasks = _G._UnlockedMasks or {}
        _G._UnlockedMasks.Hermes = true
        maskObtained = true
        Player.pendingObtainMask = Mask.HERMES
        if _G._MaskCount == 1 and not _G._MaskInfoShown then
            Player.pendingMaskInfoDialog = true
        end
    end
    giveHermesMask = false

    if giveAresMask and not (_G._UnlockedMasks and _G._UnlockedMasks.Ares) then
        _G._MaskCount = _G._MaskCount + 1
        _G._UnlockedMasks = _G._UnlockedMasks or {}
        _G._UnlockedMasks.Ares = true
        maskObtained = true
        Player.pendingObtainMask = Mask.ARES
    end
    giveAresMask = false

    if maskObtained and Player.currentState ~= State.DEAD then
        ChangeState(self, State.IDLE)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        if not debugMaskGive then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then
                pcall(function() anim:Play("Idle", 0.0) end)
                pcall(function() anim:Play("GetMask", 0.4) end)
            end
            Player.AnimTimer = 34.0
            self.public.canMove = false
            Player.isGetMaskAnim     = true
            Player.getMaskEvent1Done = false
            Player.getMaskEvent2Done = false
            Player.getMaskIdleTransitionDone = false

            if _G.PlayMaskCinematic then
                _G.PlayMaskCinematic(Player.pendingObtainMask)
            end
        else

            if Player.pendingObtainMask == Mask.APOLLO  then _G._MaskState_Apolo  = true end
            if Player.pendingObtainMask == Mask.HERMES  then _G._MaskState_Hermes = true end
            if Player.pendingObtainMask == Mask.ARES    then _G._MaskState_Ares   = true end

            local maskToEquip = Player.pendingObtainMask

            if _G.ShowMaskObtained then _G.ShowMaskObtained(maskToEquip:lower()) end

            Player.pendingObtainMask = nil
            EquipMask(self, maskToEquip)
        end
    end

   
    debugMaskGive = false
end

function ResetPlayer(self)
    Engine.Log("[Player] ResetPlayer llamado")

    self.public.health  = 100
    self.public.stamina = 100
    self.public.berserkActive = false
    self.public.canMove = true

    Player.healAnimTimer = 0
    Player.maskAnimTimer = 0
    Player.AnimTimer = 0

    attackCooldown = 0
    rollCooldown   = 0

    attackBufferPending = false
    attackNum = 0

    _G._PlayerController_isDead           = false
    _G._PlayerController_drownDeath = false
    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil
    iFramesTimer = 0.0

    accumulatedAlpha = 0.0

    _G.CombatStates = {}
    
    Player.isDrowning            = false
    _PlayerController_isDrowning = false
    Player.hermesGraceTimer      = 0

    local savedMask = Player.currentMask
    InitParticles(self)
    FindMasks(self)

    local p = lastCheckpoint or Player.spawnPos
    if p then
        self.transform:SetPosition(p.x, p.y, p.z)
    end

    if _G.RestorePotions then
        _G.RestorePotions()
    end

    winBossCinematic = false 
    wakeUpCinematic = false

    Player.currentMask = Mask.NONE
    ChangeState(self, State.IDLE)
    EquipMask(self, savedMask or Mask.NONE)
    Engine.Log("[Player] Reset completado")
end

function OnTriggerEnter(self, other)
    if other:CompareTag("PuzzleArea") then
        Player.inPuzzleArea = true
    end
end


function OnTriggerExit(self, other)
    if other:CompareTag("PuzzleArea") then
        Player.inPuzzleArea = false
    end
end

function OnCollisionEnter(self, other)
    if other:CompareTag("Water") and Player.currentMask == Mask.HERMES then
        Player.isDrowning            = true
        Player.hermesGraceTimer      = HERMES_GRACE_TIME
        --Player.currentSurface = "Water"
        if Player.currentState == State.RUNNING then
            if Player.smokePS then Player.smokePS:Stop() end
            if Player.bubblesPS then Player.bubblesPS:Play() end
        end
    end

	for i, surface in ipairs(surfaces) do
        if other:CompareTag(surface) then
            if Player.currentSurface ~= surface then
                Player.currentSurface = surface
                if surface ~= "Water" then
                    Player.lastGroundSurface = surface
                end
                if Player.stepSFX then
                    Audio.SetSwitch("Surface_Type", tostring(surface), Player.stepSFX)
                    --Engine.Log("[PLAYER FOOTSTEPS] Switching to ".. tostring(surface).." by collider")
                end
            end
        end
    end

    if other:CompareTag("Dirt") or other:CompareTag("Grass") or other:CompareTag("Stone") or other:CompareTag("Sand") or other:CompareTag("Wood")  then
        Player.isGrounded = true
    end
end

function OnCollisionExit(self, other)
    if other:CompareTag("Water") then
        Player.isDrowning            = false
        _PlayerController_isDrowning = false
        Player.hermesGraceTimer      = 0
        if Player.currentState == State.RUNNING then
            if Player.smokePS and Player.currentMask ~= Mask.HERMES then Player.smokePS:Play() end
            if Player.bubblesPS then Player.bubblesPS:Stop() end
        end

        if Player.stepSFX and Player.lastGroundSurface then
            Audio.SetSwitch("Surface_Type", Player.lastGroundSurface, Player.stepSFX)
            Player.currentSurface  = Player.lastGroundSurface
        end
        --Player.previousSurface = "Water"
    end

    if other:CompareTag("Dirt") or other:CompareTag("Grass") or other:CompareTag("Stone") or other:CompareTag("Sand") or other:CompareTag("Wood") then
        Player.respawnPos = self.transform.worldPosition
        Player.isGrounded = false
    end
end

function UpdateSwordMaterial()
    if not Player.currentMask then return end

    if swordApolo and not swordApolo.transform then swordApolo = nil end
    if swordHermes and not swordHermes.transform then swordHermes = nil end
    if swordAres and not swordAres.transform then swordAres = nil end
    if swordGameObject and not swordGameObject.transform then swordGameObject = nil end

    if swordApolo      then swordApolo:SetActive(Player.currentMask      == Mask.APOLLO) end
    if swordHermes     then swordHermes:SetActive(Player.currentMask     == Mask.HERMES) end
    if swordAres       then swordAres:SetActive(Player.currentMask       == Mask.ARES)   end
    if swordGameObject then swordGameObject:SetActive(Player.currentMask == Mask.NONE)   end
    
    if Player.aresPs   then
        if Player.currentMask == Mask.ARES   then Player.aresPs:Play()   else Player.aresPs:Stop()   end
    end
    if Player.apoloPs  then
        if Player.currentMask == Mask.APOLLO then Player.apoloPs:Play()  else Player.apoloPs:Stop()  end
    end
    if Player.hermesPs then
        if Player.currentMask == Mask.HERMES then Player.hermesPs:Play() else Player.hermesPs:Stop() end
    end
    if Player.aresLight   then Player.aresLight:SetEnabled(Player.currentMask   == Mask.ARES)   end
    if Player.apoloLight  then Player.apoloLight:SetEnabled(Player.currentMask  == Mask.APOLLO) end
    if Player.hermesLight then Player.hermesLight:SetEnabled(Player.currentMask == Mask.HERMES) end
end

function ActivateTrail()
    if not Player.trailPs then return end

    if Player.currentMask == Mask.HERMES then
        Player.trailPs:SetStartColor(0.4, 0.8, 1.0)
        Player.trailPs:SetEndColor(0.4, 0.8, 1.0, 0.0)
    elseif Player.currentMask == Mask.APOLLO then
        Player.trailPs:SetStartColor(1.0, 0.9, 0.2)
        Player.trailPs:SetEndColor(1.0, 0.9, 0.2, 0.0)
    elseif Player.currentMask == Mask.ARES then
        Player.trailPs:SetStartColor(1.0, 0.15, 0.15)
        Player.trailPs:SetEndColor(1.0, 0.15, 0.15, 0.0)
    else
        Player.trailPs:SetStartColor(1.0, 1.0, 1.0)
        Player.trailPs:SetEndColor(1.0, 1.0, 1.0, 0.0)
    end

    Player.trailPs:Play()
end

function _G.TriggerChestAnimation(self)
    if Player.healAnimTimer > 0 or Player.maskAnimTimer > 0 or Player.AnimTimer > 0
       or Player.currentState == State.DEAD then
        return false
    end

    ChangeState(self, State.IDLE)
    if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

    local anim = self.gameObject:GetComponent("Animation")
    if anim then
        pcall(function() anim:Play("Idle", 0.0) end)
        pcall(function() anim:Play("Open", 0.4) end)
        
        if Player.itemSFX then 
            Player.itemSFX:SelectPlayAudioEvent("SFX_OpenChest") 
        end

    end

    Player.AnimTimer = 4.0
    self.public.canMove = false
    return true
end