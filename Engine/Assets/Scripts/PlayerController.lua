-- PlayerController.lua

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local attackCol
local chargeCol
local heavyCol
local attackTimer = 0
local attackCooldown = 0
local rollCooldown = 0
local stepTimer = 0.5

--audiosources
local attackSource 
local voiceSource
local hitSource
local itemSource
--local equipSource
local changeSource
local swordMat = nil
local surfaces = {"Grass", "Water", "Dirt", "Stone", "Bones"}

_PlayerController_triggerCameraShake = false
_PlayerController_lastAttack         = ""
_impactFrameTimer                    = 0
_PlayerController_currentMask        = ""
_PlayerController_isDrowning         = false
_G._PlayerController_isDead          = false  
_G.PlayerInstance                    = nil
_G._MaskCount = 0

local INPUT_SCALE = 10
local HERMES_GRACE_TIME      = 0.2
local ATTACK_BUFFER = 0.5

-- MASKS
local Mask = {
    NONE   = "NoMask",
    APOLLO = "None",
    HERMES = "None",
    ARES   = "None"
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
    rb              = nil,
    sprintHeld      = false,
	smokePS         = nil,
	bubblesPS         = nil,
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
    baseSpeed = 0.0,
    isGrounded = false,

    attackBuffer = false,
    attackBufferPending = false,
    attackNum = 0,

    staminaLock = false,

    maskAnimDuration = 1.0,
    maskAnimTimer = 0.0,

    healAnimTimer = 0.0,
    healAnimDuration = 1.0,
    healPending = false,

    AnimTimer = 0.0,
    isGetMaskAnim     = false,
    pendingObtainMask = nil,
    getMaskEvent1Done = false,
    getMaskEvent2Done = false,
    getMaskIdleTransitionDone = false,
    currentOrbitAnim = nil,
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
    staminaRecover   = 50.0,   
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
    triggerCameraShake  = false,
    attackBufferDuration = 0.4,
    canMove             = true,
    berserkActive       = false,
}

function TriggerDrinkAnimation(self, isInternalHeal)
    if Player.healAnimTimer > 0 or Player.maskAnimTimer > 0 or Player.currentState == State.DEAD or Player.AnimTimer > 0  then
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
    Player.maskAnimTimer = 0 -- Reset mask timer just in case
    self.public.canMove = false
    return true
end

function _G.TriggerCameraShake(duration, magnitude, freq)
    local camObj = GameObject.Find("MainCamera")
    if camObj then
        Engine.Log("Entra camera")
        local cineCam = camObj:GetComponent("CinematicCamera")
        if cineCam then
            -- Valores por defecto si no se pasan parámetros
            cineCam:Shake(duration or 0.3, magnitude or 6.0, freq or 25.0)
        end
    end
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

    if _G.interact == true then _G.interact = false end

    if self.public.interact == true then self.public.interact = false end
    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        Engine.Log("interact try")
        self.public.interact = true
        _G.interact = true
    end

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
    
    -- Fallback if cannot find object "MainCamera"
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
    local tPos = target.transform.position
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
    if newState == State.RUNNING and staminaLock == true then return end
    if Player.maskAnimTimer > 0 then return end
    if Player.healAnimTimer > 0 then return end
    if Player.AnimTimer > 0 then return end
    
    Engine.Log("[Player] CHANGING STATE: " .. tostring(newState))
    
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
    Engine.Log("[Player] Iniciando animacion de beber...")
    return true
end

local function EquipMask(self, newMask, skipSword)
    if Player.maskAnimTimer > 0 then return end

    if not maskApolo or not maskAres or not maskHermes then
        FindMasks(self)
    end
    
    if newMask == Mask.APOLLO then 
        --masks
        if maskAres then maskAres:SetActive(false)end
        if maskApolo then maskApolo:SetActive(true)end
        if maskHermes then maskHermes:SetActive(false)end
    elseif newMask == Mask.HERMES then 
        --masks
        if maskAres then maskAres:SetActive(false)end
        if maskApolo then maskApolo:SetActive(false)end
        if maskHermes then maskHermes:SetActive(true)end
    elseif newMask == Mask.ARES then 
        --masks
        if maskAres then maskAres:SetActive(true) end
        if maskApolo then maskApolo:SetActive(false) end
        if maskHermes then maskHermes:SetActive(false) end
    elseif newMask == Mask.NONE then 
        --masks
        if maskAres then maskAres:SetActive(false) end
        if maskApolo then maskApolo:SetActive(false) end
        if maskHermes then maskHermes:SetActive(false) end
    end

    if Player.currentMask == newMask or Player.currentState == State.DEAD then return end
    if Player.currentMask == Mask.HERMES and Player.isDrowning and Player.isGrounded == false then
        Engine.Log("[Player] Hermes quitado sobre el agua")
        Player.currentMask = newMask
        Player.hermesPendingUnequip = true
        Player.hermesDeathRespawn = true
        Player.hermesDeathTimer   = 2.0
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        ChangeState(self, State.DEAD)

        UpdateSwordMaterial()
        return
    end
    if Player.currentMask == Mask.HERMES then
        Player.hermesGraceTimer   = 0
    end

    if newMask == Mask.NONE then
        Engine.Log("[Player] Unequipping mask")
        
    else
        Engine.Log("[Player] EQUIPPING MASK: " .. tostring(newMask))
      
    end
    Engine.Log("Change to "..tostring(newMask))
    Player.currentMask = newMask

    if newMask == Mask.APOLLO then _G._MaskState_Apolo  = true
    elseif newMask == Mask.HERMES then _G._MaskState_Hermes = true
    elseif newMask == Mask.ARES   then _G._MaskState_Ares   = true
    end

    if Player.currentMask ~= Mask.NONE then 
        Audio.SetSwitch("Player_Mask", tostring(Player.currentMask), Player.changeMaskSFX)
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskSwitch") end
    end

   

    -- Exponer al HUD: usar cadena limpia ("Hermes"/"Ares"/"Apolo"/"" para ninguna)
    if newMask == Mask.HERMES then
        _PlayerController_currentMask = "Hermes"
    elseif newMask == Mask.APOLLO then
        _PlayerController_currentMask = "Apolo"
    elseif newMask == Mask.ARES then
        _PlayerController_currentMask = "Ares"
    else
        _PlayerController_currentMask = ""
    end
    if not skipSword then UpdateSwordMaterial() end
end

States[State.DEAD] = {
    Enter  = function(self)
        Engine.Log("[Player] Player is DEAD")
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        _G._PlayerController_isDead = true 
        if Player.voiceSFX then Player.voiceSFX:SelectPlayAudioEvent("SFX_PlayerDeath") end
        local anim = self.gameObject:GetComponent("Animation")
        if anim and Player.isDrowning then anim:Play("Drown", 0.5)
        else anim:Play("Die", 0.5) end
        
    end,
    Update = function(self, dt)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        if Input.GetKeyDown("1") then
            self.public.health  = 100
            self.public.stamina = 100
            local p = lastCheckpoint
            self.transform:SetPosition(p.x, p.y, p.z)
            _G._PlayerController_isDead = false
            ChangeState(self, State.IDLE)
        end

        if Player.hermesDeathRespawn then
            self.public.stamina = 50.0
            Player.hermesDeathTimer = Player.hermesDeathTimer - dt
            if Player.hermesDeathTimer <= 0 then
                Player.hermesDeathRespawn = false    
                Player.hermesGraceTimer = 0
                local rp = Player.respawnPos
                self.transform:SetPosition(rp.x, rp.y, rp.z)
                if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
                if Player.hermesPendingUnequip then
                    _PlayerController_currentMask = ""
                    Player.hermesPendingUnequip = false    
                end
                Player.hermesRespawnCooldown = 1.5
                _G._PlayerController_isDead = false

                local anim = self.gameObject:GetComponent("Animation")
                if anim then 
                    pcall(function() anim:Play("Idle", 0.0) end)
                end
            end
        end

        if Player.hermesRespawnCooldown > 0 then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play("Idle", 0.0) end)
            end
            Player.hermesRespawnCooldown = Player.hermesRespawnCooldown - dt
            if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
            if Player.hermesRespawnCooldown <= 0 then
                ChangeState(self, State.IDLE)
                self.public.stamina = 50.0
                staminaLock = false
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
            pcall(function() anim:Play("Idle", 0.5) end)
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
                local hasWalk = pcall(function() anim:Play("Walk", 0.5) end)
                if hasWalk then
                    pcall(function() anim:SetSpeed("Walk", 1) end)
                else
                    pcall(function() anim:Play("Idle", 0.5) end)
                end
            end
        end
    end,
    
    Update = function(self, dt)
        local sprintInput = Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5
        if sprintInput and not Player.sprintHeld and self.public.stamina > 10 then
            ChangeState(self, State.RUNNING)
        end
        local moveX, moveZ, inputLen = GetMovementInput(self)
        
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
            if stepTimer >= (0.5 / self.public.sprintMultiplier) then
				stepTimer = 0
                Audio.SetSwitch("Player_Speed", "Walk", Player.stepSFX)
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps") end
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
                        if fwdDot >= 0 then newAnim = "OrbitForward"
                        else                newAnim = "OrbitBack" end
                    else
                        if rightDot >= 0 then newAnim = "OrbitRight"
                        else                  newAnim = "OrbitLeft" end
                    end
                    if newAnim ~= Player.currentOrbitAnim then
                        Player.currentOrbitAnim = newAnim
                        local anim = self.gameObject:GetComponent("Animation")
                        if anim then
                            if newAnim == "OrbitFwd"   then pcall(function() anim:Play("OrbitFwd",   0.2) end) end
                            if newAnim == "OrbitBack"  then pcall(function() anim:Play("OrbitBack",  0.2) end) end
                            if newAnim == "OrbitLeft"  then pcall(function() anim:Play("OrbitLeft",  0.2) end) end
                            if newAnim == "OrbitRight" then pcall(function() anim:Play("OrbitRight", 0.2) end) end
                        end                    
                    end
                end
            end
        else
            Player.currentOrbitAnim = nil
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
                anim:Play("Running", 0.5) 
                anim:SetSpeed("Running", 2.0)
            end
        end

        self.public.usingStamina = true
        Player.currentSpeed = Player.baseSpeed + self.public.speedIncrease
        if Player.currentMask == Mask.HERMES then
            Player.currentSpeed = Player.currentSpeed + self.public.speedHermesBonus
        end	

        if Player.isDrowning and Player.currentMask == Mask.HERMES then
            if Player.bubblesPS then Player.bubblesPS:Play() end
        elseif Player.smokePS then Player.smokePS:Play() end
    end,
    Exit = function(self)
        Player.currentOrbitAnim = nil
        Player.currentSpeed = Player.baseSpeed
        self.public.usingStamina = false
		if Player.smokePS then Player.smokePS:Stop() end
		if Player.bubblesPS then Player.bubblesPS:Stop() end
    end,
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput(self)

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

        if self.public.stamina <= 0 then
            ChangeState(self, State.WALK)
            return
        end

        if not Player.godMode and not self.public.berserkActive then
            -- self.public.stamina = self.public.stamina - (self.public.staminaCost * dt)
        end

        if Player.stepSFX then
            stepTimer = stepTimer + dt
            if stepTimer >= (0.25/self.public.sprintMultiplier) then
				stepTimer = 0
                Audio.SetSwitch("Player_Speed", "Run", Player.stepSFX)
                if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps") end
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
                            if newAnim == "OrbitFwd"   then pcall(function() anim:Play("OrbitFwd",   0.2) end) pcall(function() anim:SetSpeed("OrbitFwd",   2.0) end) end
                            if newAnim == "OrbitBack"  then pcall(function() anim:Play("OrbitBack",  0.2) end) pcall(function() anim:SetSpeed("OrbitBack",  2.0) end) end
                            if newAnim == "OrbitLeft"  then pcall(function() anim:Play("OrbitLeft",  0.2) end) pcall(function() anim:SetSpeed("OrbitLeft",  2.0) end) end
                            if newAnim == "OrbitRight" then pcall(function() anim:Play("OrbitRight", 0.2) end) pcall(function() anim:SetSpeed("OrbitRight", 2.0) end) end
                        end                    
                    end
                end
            end
        else
            Player.currentOrbitAnim = nil
        end

        ApplyMovementAndRotation(self, dt, moveX, moveZ, Player.currentSpeed)
    end
}

States[State.ROLL] = {
    timer = 0,
    Enter = function(self)
        if not Player.godMode and not self.public.berserkActive then
            self.public.stamina = self.public.stamina - self.public.rollStaminaCost
        end
        States[State.ROLL].timer = self.public.rollDuration

        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Roll", 0) end
        if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerRoll") end 
        if Player.stepSFX then Player.stepSFX:SelectPlayAudioEvent("SFX_SkeletonDodge") end 
    end,
    Exit = function(self)
        rollCooldown = self.public.rollCooldownMax
    end,
    Update = function(self, dt)
        States[State.ROLL].timer = States[State.ROLL].timer - dt

        if States[State.ROLL].timer <= 0 then
            rollCooldown = self.public.rollCooldownMax
            ChangeState(self, State.IDLE)
            return
        end

        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(Player.lastDirX * self.public.rollSpeed, velocity.y, Player.lastDirZ * self.public.rollSpeed)
        end
    end
}

States[State.CHARGING] = {
    Enter = function(self)
        SnapToLockOn(self)
        if not Player.godMode and not self.public.berserkActive then
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
        if not Player.godMode and not self.public.berserkActive then
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
        Prefab.Instantiate(self.public.bulletPrefab)
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
        if not Player.godMode and not self.public.berserkActive then
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
            Player.rb:SetLinearVelocity(0, velocity.y, 0)
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
        if anim and attackNum == 1 then anim:Play("Attack1", 0.0) end
        if anim and attackNum == 2 then anim:Play("Attack2", 0.0) end
        if anim and attackNum == 3 then anim:Play("Attack3", 0.0) end
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

    local anim = self.gameObject:GetComponent("Animation")
    if anim then
        anim:Play("Idle", 0.0)
        anim:Play("Hit", 0.0)
    end

    self.public.health = math.max(0, self.public.health - amount)
    Engine.Log("[Player] HP left: " .. tostring(self.public.health) .. "/100")

    _PlayerController_triggerCameraShake = true
    if Input.HasGamepad() then Input.RumbleGamepad(1.0, 0.2, 150) end

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
            pcall(function() anim:Play("Idle", 0.5) end)
        end
    end

    if self.public.health <= 0 then
        Engine.Log("[Player] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.17
        ChangeState(self, State.DEAD)
    end
end

local function RefreshAudioSources(self)
    Engine.Log("[Player] RefreshAudioSources: Refreshing audio component references")
    local go = self.gameObject
    
    local stepGo   = GameObject.FindInChildren(go, "StepSource") or GameObject.FindInChildren(go, "SFX_FootSteps")
    local swordGo  = GameObject.FindInChildren(go, "SwordSource") or GameObject.FindInChildren(go, "SFX_Sword")
    local voiceGo  = GameObject.FindInChildren(go, "VoiceSource") or GameObject.FindInChildren(go, "SFX_Voice")
    local hitGo    = GameObject.FindInChildren(go, "HitSource") or GameObject.FindInChildren(go, "SFX_Hit")
    local maskGo   = GameObject.FindInChildren(go, "MaskSource") or GameObject.FindInChildren(go, "SFX_Mask")
    local itemGo   = GameObject.FindInChildren(go, "ItemSource") or GameObject.FindInChildren(go, "SFX_Item")
    
    local rootSource = go:GetComponent("Audio Source")
    if not rootSource then
        Engine.Log("[Player] WARNING: No root Audio Source found on Player object!")
    end

    Player.stepSFX       = (stepGo and stepGo:GetComponent("Audio Source")) or rootSource
    Player.swordSFX      = (swordGo and swordGo:GetComponent("Audio Source")) or rootSource
    Player.voiceSFX      = (voiceGo and voiceGo:GetComponent("Audio Source")) or rootSource
    Player.hitSFX        = (hitGo and hitGo:GetComponent("Audio Source")) or rootSource
    --Player.pickMaskSFX   = (maskGo and maskGo:GetComponent("Audio Source")) or rootSource
    Player.changeMaskSFX = (maskGo and maskGo:GetComponent("Audio Source")) or rootSource
    Player.itemSFX   = (itemGo and itemGo:GetComponent("Audio Source")) or rootSource

    Engine.Log("[Player] Audio Source Mapping Status:")
    Engine.Log(" - StepSFX: " .. (stepGo and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - SwordSFX: " .. (swordGo and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - VoiceSFX: " .. (voiceGo and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - ItemSFX: " ..(itemGO and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - MaskSFX: " ..(maskGO and "CHILD FOUND" or "ROOT DEFAULT"))
end

local FindMasks
local InitParticles

function Start(self)
    Engine.Log("[Player] Start() called - Initializing player")
    
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

    -- FIX: eliminados Game.Resume() y Game.SetTimeScale(1.0) del Start.
    -- El estado de pausa es responsabilidad exclusiva de MenuManager.
    -- Game.SetTimeScale solo se resetea tras cambio de escena (ver Update).
    Game.SetTimeScale(1.0)

    _G._PlayerController_isDead = false

    self.public.staminaCost    = 20.0   
    self.public.staminaRecover = 15.0 

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
    _PlayerController_currentMask = ""
	
    local smokeObj = GameObject.FindInChildren(self.gameObject, "SmokeTrail")
    if smokeObj then
        Player.smokePS = smokeObj:GetComponent("ParticleSystem")
        if Player.smokePS then
            Player.smokePS:Stop()
        end
    else
        Engine.Log("[Player] No SmokeTrail child found in hierarchy")
    end

    local bubblesObj = GameObject.FindInChildren(self.gameObject, "WaterTrail")
    if bubblesObj then
        Player.bubblesPS = bubblesObj:GetComponent("ParticleSystem")
        if Player.bubblesPS then
            Player.bubblesPS:Stop()
        end
    else
        Engine.Log("[Player] No WaterTrail child found in hierarchy")
    end

    _G._PlayerController_isDead = false

    giveApoloMask       = false
    giveHermesMask      = false
    giveAresMask        = false

    Mask.APOLLO = "None"
    Mask.HERMES = "None"
    Mask.ARES   = "None"

    _G._MaskState_Hermes = false
    _G._MaskState_Apolo  = false
    _G._MaskState_Ares   = false

    maskAnimTimer = 0.0

    Player.currentState = State.IDLE
    ChangeState(self, State.IDLE, true)
    EquipMask(self, Mask.NONE)
    Player.currentMask = Mask.NONE

    Audio.SetSwitch("Player_Mask", tostring(Player.currentMask), Player.changeMaskSFX)

    FindMasks(self)
    InitParticles(self)

    if Player.rb then
        Player.rb:SetLinearVelocity(0, 0, 0)
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
end


function Update(self, dt)
    if attackCooldown > 0 then
        attackCooldown = attackCooldown - dt
    end
    if rollCooldown > 0 then
        rollCooldown = rollCooldown - dt
    end

    if _G._PlayerController_introAnim then
        Player.AnimTimer = 20.0
        local anim = self.gameObject:GetComponent("Animation")
        if anim then
            anim:Play("WakeUp", 0.0)
        end
        _G._PlayerController_introAnim = false
        if _G.PlayWakeUpCinematic then 
            _G.PlayWakeUpCinematic() 
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

    local sceneLoaderCount = _G._SceneLoaderCounter or 0
    if not Player.lastSceneCounter or Player.lastSceneCounter ~= sceneLoaderCount then
        Player.lastSceneCounter = sceneLoaderCount
        Engine.Log("[Player] New Scene Detected (Counter: " .. tostring(sceneLoaderCount) .. ") - Resetting persistent state")
        
        -- FIX: Game.Resume() aquí sí es correcto porque es un cambio de escena
        -- real, donde sabemos que el juego debe correr (el MenuManager
        -- se reinicializará y tomará el control del estado de pausa).
        Game.Resume()
        Game.SetTimeScale(1.0)
        
        Player.rb = self.gameObject:GetComponent("Rigidbody")

        self.gameObject:SetTag("PersistentPlayer")
        local dummyPlayer = GameObject.Find("Player")
        if dummyPlayer and dummyPlayer.tag ~= "PersistentPlayer" then
            Engine.Log("[Player] Destroying dummy player from scene to prevent AudioListener conflicts")
            GameObject.Destroy(dummyPlayer)
        end
        self.gameObject:SetTag("Player")

        Player.restoreListenerFrames = 2
        
        local spawn = GameObject.Find("SpawnPoint")
        if spawn then
            pcall(function()
                local p = spawn.transform.position
                self.transform:SetPosition(p.x, p.y, p.z)
                Engine.Log("[Player] Teleported to SpawnPoint successfully")
            end)
        end
        
        Player.masterAudioTimer = 5.0
        Audio.SetGlobalVolume(100.0)
        --Audio.SetMusicVolume(100.0)
        local mGo = GameObject.Find("MusicSource")
        if mGo then
            local musicComp = mGo:GetComponent("Audio Source")
            if musicComp then
                Engine.Log("[Player] Master Audio Fix: Found MusicSource")
                musicComp:SetSourceVolume(100.0)
            else
                Engine.Log("[Player] ERROR: MusicSource found but NO 'Audio Source' component!")
            end
        else
            Engine.Log("[Player] WARNING: No 'MusicSource' object found to restore audio.")
        end
        
        RefreshAudioSources(self)

        InitParticles(self)
        FindMasks(self)
        EquipMask(self, Player.currentMask)

        self.public.staminaCost    = 20.0   
        self.public.staminaRecover = 15.0 
        Player.baseSpeed = self.public.speed
        Player.currentSpeed = self.public.speed
        
        Player.firstFrameCheck = true

        -- FIX: si el UIManager está desactivado el engine puede pausar
        -- automáticamente por tener MainMenu.xaml en el Canvas.
        -- Esperamos unos frames y si no hay MenuManager activo, forzamos Resume.
        Player.forceResumeFrames = 10
    end

    if Player.masterAudioTimer and Player.masterAudioTimer > 0 then
        Player.masterAudioTimer = Player.masterAudioTimer - dt
        Audio.SetGlobalVolume(100.0)
        --Audio.SetMusicVolume(100.0)
    end

    if Player.restoreListenerFrames then
        Player.restoreListenerFrames = Player.restoreListenerFrames - 1
        if Player.restoreListenerFrames <= 0 then
            local listenerObj = GameObject.Find("Listener")
            if listenerObj then
                local lComp = listenerObj:GetComponent("Audio Listener")
                if lComp and lComp.SetAsDefaultListener then
                    lComp:SetAsDefaultListener()
                    Engine.Log("[Player] DELAYED Master Audio Fix: Default Listener Restored!")
                end
            end
            Player.restoreListenerFrames = nil
        end
    end

    -- FIX: resume forzado si no hay MenuManager activo (UIManager desactivado)
    if Player.forceResumeFrames and Player.forceResumeFrames > 0 then
        Player.forceResumeFrames = Player.forceResumeFrames - 1
        if Player.forceResumeFrames == 0 then
            if not _G.GlobalMenuManagerInstance then
                -- Anti-AutoPause: Si el MenuManager está desactivado pero tiene el MainMenu cargado,
                -- el engine pausará el juego. Buscamos el Canvas y lo limpiamos.
                local uiObj = GameObject.Find("MenuManager") or GameObject.Find("Canvas")
                if uiObj then
                    local canvas = uiObj:GetComponent("Canvas")
                    if canvas and canvas:GetCurrentXAML() == "MainMenu.xaml" then
                        Engine.Log("[Player] Anti-AutoPause: Detectado MainMenu en objeto desactivado. Forzando HUD...")
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
            if anim then 
                pcall(function() anim:Play("Idle", 0.5) end)
            end
            ChangeState(self, State.IDLE, true)
        end
    end

    if Player.AnimTimer > 0 then
        _G.PlayerInAnim = true
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        Player.AnimTimer = Player.AnimTimer - dt
        
        --positions
        if Player.isGetMaskAnim and Player.AnimTimer > 33.0 and Player.pendingObtainMask then
            if Player.pendingObtainMask == Mask.HERMES then 
                self.transform:SetPosition(-68.549, 3.280, -318.933) 
                if Player.rb then Player.rb:SetRotation(180, 0, 180) end
            end
            if Player.pendingObtainMask == Mask.APOLLO then 
                self.transform:SetPosition(200.729, 32.377, -168.781) 
                if Player.rb then Player.rb:SetRotation(0, 88.814, 0) end
            end
            if Player.pendingObtainMask == Mask.ARES then
                self.transform:SetPosition(77.979, 8.898, -104.323) 
                if Player.rb then Player.rb:SetRotation(-180, 0, -180) end
            end
        end

        --segundo 9
        if Player.isGetMaskAnim and Player.AnimTimer <= 25.0 and Player.AnimTimer >= 20.0 and not Audio.IsEventPlaying("SFX_GetMask") then
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_GetMask") end 
        end
        --segundo 14
        if Player.isGetMaskAnim and not Player.getMaskEvent1Done and Player.AnimTimer <= 20.0 then
            
            Player.getMaskEvent1Done = true
            if Player.pendingObtainMask then
                EquipMask(self, Player.pendingObtainMask, true)
                --_G.RemoveStatueMask()
                
            end
        end

        --segundo 19
        if Player.isGetMaskAnim and Player.AnimTimer <= 15.0 and Player.AnimTimer >= 10.0 and not Audio.IsEventPlaying("SFX_ShowSword") then
            if Player.itemSFX then Player.itemSFX:SelectPlayAudioEvent("SFX_ShowSword") end 
        end

        --segundo 27
        if Player.isGetMaskAnim and not Player.getMaskEvent2Done and Player.AnimTimer <= 7.7 then
            Player.getMaskEvent2Done = true
            UpdateSwordMaterial()
        end

        if Player.AnimTimer <= 1.8 and not Player.getMaskIdleTransitionDone then
            Player.getMaskIdleTransitionDone = true
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play("Idle", 1.5) end)
            end
        end

        if Player.AnimTimer <= 0 then
            _G.PlayerInAnim = false
            Player.AnimTimer = 0
            Player.isGetMaskAnim = false
            self.public.canMove = true
            ChangeState(self, State.IDLE)
            ChangeState(self, State.IDLE, true)
        end
    end

    if attackBuffer == true and Player.currentState ~= State.ATTACK_LIGHT then
        self.public.attackBufferDuration = self.public.attackBufferDuration - dt
        if self.public.attackBufferDuration < 0 then
            self.public.attackBufferDuration = ATTACK_BUFFER
            attackBuffer = false
        end
    end
        
    if _PlayerController_triggerCameraShake == true then
        self.public.triggerCameraShake = true
        _PlayerController_triggerCameraShake = false
    end

    if Player.godMode then
        UpdateFlyingGodMode(self, dt)
    elseif Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)

        if (Player.currentState == State.IDLE or Player.currentState == State.WALK) and self.public.stamina < 100 then
            self.public.stamina = math.min(100, self.public.stamina + (self.public.staminaRecover * dt))
        end
    end

    if Input.GetKeyDown("7") and not Player.godMode then
        self.public.health = math.max(0, self.public.health - self.public.hpLossCost)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    if Input.GetKeyDown("G") then
        Player.godMode = not Player.godMode
        Engine.Log("[Player] GOD MODE: " .. tostring(Player.godMode))
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
                Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
            end
            self.public.canMove = true

            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play("Idle", 0.5) end)
            end
        end
    end

    if not (Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5) then
        Player.sprintHeld = false
    end

    if Input.GetKeyDown("8") or Input.GetGamepadButtonDown("RB") then 
        MaskScroll(self)
    end

    if Input.GetKeyDown("9") or Input.GetGamepadButtonDown("LB")  then 
        if Player.maskAnimTimer > 0 then return end
        if Player.AnimTimer > 0 then return end
        if Player.currentMask ~= Mask.NONE then 
            if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskChange") end
            EquipMask(self, Mask.NONE) 
        end
    end

    if Input.GetKeyDown("F1") then 
        giveApoloMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_ApoloMask") end
    end

    if Input.GetKeyDown("F2") then 
        giveHermesMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_HermesMask") end
    end

    if Input.GetKeyDown("F3") then 
        giveAresMask = true
        debugMaskGive = true
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_AresMask") end
    end

    if Input.GetKeyDown("M") then
        local p = lastCheckpoint
        self.transform:SetPosition(p.x, p.y, p.z)
    end

    ObtainMask(self)

    if Player.isDrowning and Player.currentMask == Mask.HERMES and Player.currentState ~= State.DEAD then
        if Player.currentState == State.RUNNING then
            Player.hermesGraceTimer = HERMES_GRACE_TIME
        else
            if self.public.stamina <= 0 then
                Player.hermesGraceTimer = 0
            end
            if Player.hermesGraceTimer > 0 then
                Player.hermesGraceTimer = Player.hermesGraceTimer - dt
            else
                Engine.Log("[Player] Out of hermes :( )")
                Player.hermesDeathRespawn = true
                Player.hermesDeathTimer   = 2.3
                if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
                ChangeState(self, State.DEAD)
            end
        end
    end

    if _impactFrameTimer > 0 then
        _impactFrameTimer = _impactFrameTimer - dt
        if _impactFrameTimer <= 0 then
            _impactFrameTimer = 0
            Game.SetTimeScale(1.0)
        end
    end
end

function MaskScroll(self)
    if Player.AnimTimer > 0 then return end
    Engine.Log("old mask: "..tostring(oldMask)..", current mask: "..tostring(Player.currentMask).. ", Player state: "..tostring(Player.currentState))
    oldMask = Player.currentMask

    Engine.Log("Mask Scrolling, maskAnimTimer = "..tostring(Player.maskAnimTimer)..", healAnimTimer = "..tostring(Player.healAnimTimer))

    if Player.maskAnimTimer > 0 then return end
    if Player.healAnimTimer > 0 then return end

    if not Player.currentMask then Player.currentMask = Mask.NONE end

    if Player.currentState == State.DEAD then return end
    if Player.currentMask == Mask.NONE then 
        if Mask.HERMES ~= "None" then EquipMask(self,Mask.HERMES)
        elseif Mask.APOLLO ~= "None" then EquipMask(self,Mask.APOLLO)
        elseif Mask.ARES ~= "None" then EquipMask(self,Mask.ARES) end
    elseif Player.currentMask == Mask.HERMES then 
        if Mask.APOLLO ~= "None" then EquipMask(self,Mask.APOLLO)
        elseif Mask.ARES ~= "None" then EquipMask(self,Mask.ARES)
        elseif Mask.HERMES ~= "None" then EquipMask(self,Mask.HERMES)end
    elseif Player.currentMask == Mask.APOLLO then 
        if Mask.ARES ~= "None" then EquipMask(self,Mask.ARES)
        elseif Mask.HERMES ~= "None" then EquipMask(self,Mask.HERMES)
        elseif Mask.APOLLO ~= "None" then EquipMask(self,Mask.APOLLO)end
    elseif Player.currentMask == Mask.ARES then 
        if Mask.HERMES ~= "None" then EquipMask(self,Mask.HERMES)
        elseif Mask.APOLLO ~= "None" then EquipMask(self,Mask.APOLLO)
        elseif Mask.ARES ~= "None" then EquipMask(self,Mask.ARES) end
    end  

    ChangeState(self, State.IDLE)
    if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end

    if oldMask ~= Player.currentMask then
        local anim = self.gameObject:GetComponent("Animation")
        if anim then
            anim:Play("Idle", 0.0)
            anim:Play("Mask", 0.2) 
        else 
            Engine.Log("Unable to Play Mask animation")
        end
        Player.maskAnimTimer = Player.maskAnimDuration
        self.public.canMove = false
    end
end

function ObtainMask(self)
    local maskObtained = false
    if giveApoloMask and Mask.APOLLO == "None" then
        Mask.APOLLO = "Apolo"
        _G._MaskCount = _G._MaskCount + 1
        Engine.Log("Apolo Mask obtain")
        maskObtained = true
        Player.pendingObtainMask = Mask.APOLLO
    end
    giveApoloMask = false

    if giveHermesMask and Mask.HERMES == "None" then
        Mask.HERMES = "Hermes"
        _G._MaskCount = _G._MaskCount + 1
        Engine.Log("Hermes Mask obtain")
        maskObtained = true
        Player.pendingObtainMask = Mask.HERMES
    end
    giveHermesMask = false

    if giveAresMask and Mask.ARES == "None" then
        Mask.ARES = "Ares"
        _G._MaskCount = _G._MaskCount + 1
        Engine.Log("Ares Mask obtain")
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
            Player.pendingObtainMask = nil
        end
    end
    debugMaskGive = false
end

function ResetPlayer(self)
    Engine.Log("[Player] ResetPlayer llamado")

    self.public.health  = 100
    self.public.stamina = 100
    self.public.berserkActive = false

    attackCooldown = 0
    rollCooldown   = 0

    attackBufferPending = false
    attackNum = 0

    _G._PlayerController_isDead           = false
    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil

    Player.isDrowning            = false
    _PlayerController_isDrowning = false
    Player.hermesGraceTimer      = 0

    InitParticles(self)
    FindMasks(self)
    EquipMask(self, Mask.NONE)

    --Player.currentSurface = "Dirt"

    local p = Player.spawnPos
    if p then
        self.transform:SetPosition(p.x, p.y, p.z)
    end

    if _G.ForceRefreshHUD then
        _G.ForceRefreshHUD()
    end

    ChangeState(self, State.IDLE)
    Engine.Log("[Player] Reset completado")
end

function OnTriggerEnter(self, other)
    -- local matched = false
    -- for i, surface in ipairs(surfaces) do
    --     if other:CompareTag(surface) then 
    --         Player.currentSurface = surface
    --         Player.foundSurface = true
    --     end
    -- end
    -- if not foundSurface then
    --     Player.currentSurface = "Dirt"
    --     foundSurface = true
    -- end
end

function OnTriggerExit(self, other) end

function OnCollisionEnter(self, other)
    if other:CompareTag("Water") and Player.currentMask == Mask.HERMES then
        Player.isDrowning            = true
        Player.hermesGraceTimer      = HERMES_GRACE_TIME
        Engine.Log("[Player] Hermes on water")
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
                end
                Engine.Log("Surface changed to: " .. surface)
            end
        end
    end


    if other:CompareTag("Dirt") or other:CompareTag("Grass") or other:CompareTag("Stone") then
        Player.isGrounded = true
    end
end

function OnCollisionExit(self, other)
    if other:CompareTag("Water") then
        Player.isDrowning            = false
        _PlayerController_isDrowning = false
        Player.hermesGraceTimer      = 0
        Engine.Log("[Player] Player out of water")
        if Player.currentState == State.RUNNING then
            if Player.smokePS then Player.smokePS:Play() end
            if Player.bubblesPS then Player.bubblesPS:Stop() end
        end


        if Player.stepSFX and Player.lastGroundSurface then
            Audio.SetSwitch("Surface_Type", Player.lastGroundSurface, Player.stepSFX)
            Player.currentSurface  = Player.lastGroundSurface
        end
        --Player.previousSurface = "Water"
    end

    if other:CompareTag("Dirt") or other:CompareTag("Grass") or other:CompareTag("Stone") then
        Player.respawnPos = self.transform.worldPosition
        Player.isGrounded = false
    end
end

function UpdateSwordMaterial()
    if not Player.currentMask then return end
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
            Engine.Log("Playing Open Chest")
        end
        
    end

    Player.AnimTimer = 4.0
    self.public.canMove = false
    return true
end