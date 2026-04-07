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
local equipSource
local changeSource

_PlayerController_triggerCameraShake = false
_PlayerController_lastAttack         = ""
_impactFrameTimer                    = 0
_PlayerController_currentMask        = "None"
_PlayerController_isDrowning         = false
_G._PlayerController_isDead          = false  
_G.PlayerInstance                    = nil

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
    attackDelay     = 0.1,
    -- Audio
    stepSFX 		= nil,
    voiceSFX 		= nil,
    swordSFX 		= nil,
    pickMaskSFX     = nil,
    changeMaskSFX   = nil,
    itemPickSFX     = nil,
    hitSFX          = nil,
	currentSurface = "",
    foundSurface    = false,
    
    -- Hermes mask
    respawnPos       = nil,
    isDrowning       = false,
    hermesGraceTimer = 0.2,
    hermesDeathRespawn = false,
    hermesDeathTimer   = 0.0,
    hermesPendingUnequip = false,
    baseSpeed = 15.0,
    isGrounded = false,

    attackBuffer = false,
    attackBufferPending = false,
    attackNum = 0,
}

public = {
    speed               = 15.0,
    rollDuration        = 1.0,
    sprintMultiplier    = 1.5,
    rollSpeed           = 15.0,
    chargeSpeed         = 30.0,
    stamina             = 100.0,
    health              = 100.0,
    speedIncrease       = 10.0,
    speedHermesBonus    = 15.0,
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
}


local function normalizeInput(x, z)
    local len = sqrt(x*x + z*z)
    if len > INPUT_SCALE then
        local inv = INPUT_SCALE / len
        return x * inv, z * inv
    end
    return x, z
end

local function GetMovementInput(self)
    local moveX, moveZ = 0, 0
    
    if self.public.canMove == false then
        return 0, 0, 0
    end

    if Input.HasGamepad() then
        local gpX, gpZ = Input.GetLeftStick()
        moveX = gpX * INPUT_SCALE
        moveZ = gpZ * INPUT_SCALE
    end
    if Input.GetKey("W") then moveZ = moveZ - INPUT_SCALE end
    if Input.GetKey("S") then moveZ = moveZ + INPUT_SCALE end
    if Input.GetKey("A") then moveX = moveX - INPUT_SCALE end
    if Input.GetKey("D") then moveX = moveX + INPUT_SCALE end

    if _G.interact == true then _G.interact = false end

    if self.public.interact == true then self.public.interact = false end
    if Input.GetKeyDown("F")  or Input.GetGamepadButton("A") then
        Engine.Log("interact try")
        self.public.interact = true
        _G.interact = true
    end
    
    moveX, moveZ = normalizeInput(moveX, moveZ)
    local inputLen = sqrt(moveX*moveX + moveZ*moveZ)
    
    return moveX, moveZ, inputLen
end

local function GetAttackInput(self)
    if attackCooldown > 0 and attackBuffer == false then return 0 end
    if Input.GetKeyDown("E") or Input.GetGamepadButton("X") then return 1 end
    if Input.GetKeyDown("Q") or Input.GetGamepadButton("Y") then return 2 end
    return 0
end

local function ApplyMovementAndRotation(self, dt, moveX, moveZ, speedOverride)
    local speed = speedOverride or self.public.speed
    local faceDirX = moveX / INPUT_SCALE
    local faceDirZ = moveZ / INPUT_SCALE
    local velY = 0
    
    if Player.rb then
        velY = math.min(0, Player.rb:GetLinearVelocity().y)
    end

    if abs(faceDirX) > 0.01 or abs(faceDirZ) > 0.01 then
        local targetAngle = atan2(faceDirX, faceDirZ) * (180.0 / pi)
        local delta = ((targetAngle - Player.lastAngle + 180) % 360) - 180
        local maxStep = self.public.ROTATION_SPEED * dt
        if math.abs(delta) <= maxStep then
            Player.lastAngle = targetAngle
        else
            Player.lastAngle = Player.lastAngle + (delta > 0 and maxStep or -maxStep)
        end
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
        local delta = ((targetAngle - Player.lastAngle + 180) % 360) - 180
        local maxStep = self.public.ROTATION_SPEED * dt
        if math.abs(delta) <= maxStep then
            Player.lastAngle = targetAngle
        else
            Player.lastAngle = Player.lastAngle + (delta > 0 and maxStep or -maxStep)
        end
        Player.rb:SetRotation(0, Player.lastAngle, 0)
    end

    local hSpeed = self.public.speed
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

local function EquipMask(self, newMask)

    if Player.currentMask == newMask or Player.currentState == State.DEAD then return end
    if Player.currentMask == Mask.HERMES and Player.isDrowning and Player.isGrounded == false then
        Engine.Log("[Player] Hermes quitado sobre el agua")
        Player.currentMask = newMask
        Player.hermesPendingUnequip = true
        Player.hermesDeathRespawn = true
        Player.hermesDeathTimer   = 2.0
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        ChangeState(self, State.DEAD)
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
    _PlayerController_currentMask = newMask
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
            Player.hermesDeathTimer = Player.hermesDeathTimer - dt
            if Player.hermesDeathTimer <= 0 then
                Player.hermesDeathRespawn = false    
                Player.hermesGraceTimer = 0
                self.public.stamina = 0
                local rp = Player.respawnPos
                self.transform:SetPosition(rp.x, rp.y, rp.z)
                if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
                _G._PlayerController_isDead = false
                ChangeState(self, State.IDLE)
                if Player.hermesPendingUnequip then
                    _PlayerController_currentMask = "None" 
                    Player.hermesPendingUnequip = false    
                end
            end
        end
    end
}

States[State.IDLE] = {
    Enter = function(self)
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
        self.public.usingStamina = false

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            local hasWalk = pcall(function() anim:Play("Walk", 0.5) end)
            if hasWalk then
                pcall(function() anim:SetSpeed("Walk", 1) end)
            else
                pcall(function() anim:Play("Idle", 0.5) end)
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
                Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps")
            end
        end
        
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.RUNNING] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            anim:Play("Running", 0.5) 
            anim:SetSpeed("Running", 2.0)
        end

        self.public.usingStamina = true
        self.public.speed = Player.baseSpeed + self.public.speedIncrease
        if Player.currentMask == Mask.HERMES then
            self.public.speed = self.public.speed + self.public.speedHermesBonus
        end		

		if Player.smokePS then Player.smokePS:Play() end 
    end,
    Exit = function(self)
        self.public.speed = Player.baseSpeed
        self.public.usingStamina = false
		if Player.smokePS then Player.smokePS:Stop() end
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
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end

        if self.public.stamina <= 0 then
            ChangeState(self, State.WALK)
            return
        end

        if not Player.godMode then
            self.public.stamina = self.public.stamina - (self.public.staminaCost * dt)
        end

        if Player.stepSFX then
            stepTimer = stepTimer + dt
            if stepTimer >= (0.25/self.public.sprintMultiplier) then
				stepTimer = 0
                Audio.SetSwitch("Player_Speed", "Run", Player.stepSFX)
                Player.stepSFX:SelectPlayAudioEvent("SFX_PlayerFootSteps")
            end
        end
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.ROLL] = {
    timer = 0,
    Enter = function(self)
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.rollStaminaCost
        end
        States[State.ROLL].timer = self.public.rollDuration

        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Roll", 1.0) end
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
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Ares", 1.0) end
        attackTimer = 0
        if chargeCol then 
            chargeCol:Enable() 
            _PlayerController_lastAttack = "charge"
        end
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
    end
}

States[State.SHOOTING] = {
    Enter = function(self)
        _PlayerController_lastAttack = ""
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            anim:Play("Apolo", 2.0) 
        end
        attackTimer = 0

        local worldPos = self.transform.worldPosition
        local radians  = math.rad(Player.lastAngle)
        local fwdX     = math.sin(radians)
        local fwdZ     = math.cos(radians)

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
    end
}

States[State.ATTACK_HEAVY] = {
    colliderActive = false,
    Enter = function(self)
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Hermes", 1.0) end
        attackTimer = 0
        States[State.ATTACK_HEAVY].colliderActive = false
        if heavyCol then heavyCol:Disable() end
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, math.min(0, velocity.y), 0)
        end
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
    end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
        attackTimer = 0
        if attackCol then attackCol:Disable() end

        if attackBuffer == true then
            if attackNum ~= 3 then
                attackNum = attackNum + 1
            end
            attackBuffer = false
        else
            attackNum = 1
        end

        local anim = self.gameObject:GetComponent("Animation")
        if anim and attackNum == 1 then anim:Play("Attack1", 0.3) end
        if anim and attackNum == 2 then anim:Play("Attack2", 0.3) end
        if anim and attackNum == 3 then anim:Play("Attack3", 0.3) end
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt

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
                Player.swordSFX:SelectPlayAudioEvent("SFX_PlayerAttack")
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
    end
}

-- FIX: eliminada la variable local "health" suelta.
-- Toda la lógica de vida usa exclusivamente self.public.health como única fuente de verdad.
local function TakeDamage(self, amount, attackerPos)
    if Player.currentState == State.DEAD then return end
    if Player.godMode then return end

    self.public.health = math.max(0, self.public.health - amount)
    Engine.Log("[Player] HP left: " .. tostring(self.public.health) .. "/100")

    _PlayerController_triggerCameraShake = true

    if self.public.health > 0 and Player.rb and attackerPos then
        if Player.hitSFX then Player.hitSFX:SelectPlayAudioEvent("SFX_PlayerHit") end
        local playerPos = self.transform.worldPosition
        local dx = playerPos.x - attackerPos.x
        local dz = playerPos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        Player.rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
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
    Player.pickMaskSFX   = (maskGo and maskGo:GetComponent("Audio Source")) or rootSource
    Player.changeMaskSFX = (maskGo and maskGo:GetComponent("Audio Source")) or rootSource
    Player.itemPickSFX   = (itemGo and itemGo:GetComponent("Audio Source")) or rootSource

    Engine.Log("[Player] Audio Source Mapping Status:")
    Engine.Log(" - StepSFX: " .. (stepGo and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - SwordSFX: " .. (swordGo and "CHILD FOUND" or "ROOT DEFAULT"))
    Engine.Log(" - VoiceSFX: " .. (voiceGo and "CHILD FOUND" or "ROOT DEFAULT"))
end

function Start(self)
    Engine.Log("[Player] Start() called - Initializing player")
    
    Player.currentState    = nil
    Player.currentMask     = nil
    Player.rb              = nil
    Player.smokePS         = nil
    Player.stepSFX         = nil
    Player.voiceSFX        = nil
    Player.swordSFX        = nil
    Player.pickMaskSFX     = nil
    Player.changeMaskSFX   = nil
    Player.itemPickSFX     = nil
    Player.hitSFX          = nil

    _G.PlayerInstance = self
    
    Game.Resume()
    Game.SetTimeScale(1.0)
    _G._PlayerController_isDead = false

    self.public.staminaCost    = 20.0   
    self.public.staminaRecover = 15.0 

    local spawnPos  = self.transform.worldPosition
    
    Player.spawnPos = spawnPos
    Player.respawnPos = spawnPos
    lastCheckpoint = spawnPos
    Player.baseSpeed = self.public.speed
    
    _impactFrameTimer = 0
    attackBuffer = false
    ATTACK_BUFFER = self.public.attackBufferDuration
    attackNum = 0
    attackBufferPending = false

    -- FIX: stamina y health inicializados correctamente en la misma línea
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
    _PlayerController_currentMask = "None"
	
    local smokeObj = GameObject.FindInChildren(self.gameObject, "SmokeTrail")
    if smokeObj then
        Player.smokePS = smokeObj:GetComponent("ParticleSystem")
        if Player.smokePS then
            Player.smokePS:Stop()
        end
    else
        Engine.Log("[Player] No SmokeTrail child found in hierarchy")
    end

    _G._PlayerController_isDead = false

    giveApoloMask       = false
    giveHermesMask      = false
    giveAresMask        = false

    Mask.APOLLO = "None"
    Mask.HERMES = "None"
    Mask.ARES   = "None"

    Player.currentState = State.IDLE
    ChangeState(self, State.IDLE, true)
    EquipMask(self, Mask.NONE)
    Player.currentMask = Mask.NONE
    
    if Player.rb then
        Player.rb:SetLinearVelocity(0, 0, 0)
    end
end


function Update(self, dt)
    if attackCooldown > 0 then
        attackCooldown = attackCooldown - dt
    end
    if rollCooldown > 0 then
        rollCooldown = rollCooldown - dt
    end

    if _PlayerController_pendingDamage and _PlayerController_pendingDamage > 0 then
        TakeDamage(self, _PlayerController_pendingDamage, _PlayerController_pendingDamagePos)
        _PlayerController_pendingDamage    = 0
        _PlayerController_pendingDamagePos = nil
    end

    if not Player.currentState then
        Player.currentState = nil
        ChangeState(self, State.IDLE, true)
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
        
        Player.firstFrameCheck = true
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
                    Engine.Log("[Player] DELAYED Master Audio Fix: Default Listener Restored!")
                end
            end
            Player.restoreListenerFrames = nil
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

    -- FIX: tecla 7 ahora usa self.public.health directamente (igual que TakeDamage)
    if Input.GetKeyDown("7") and not Player.godMode then
        self.public.health = math.max(0, self.public.health - self.public.hpLossCost)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    if Input.GetKey("G") then
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

    if Input.GetKeyDown("P") then
        self.public.health = math.min(100, self.public.health + self.public.hpRecover)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    if not (Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5) then
        Player.sprintHeld = false
    end

    if Input.GetKeyDown("8") or Input.GetGamepadButtonDown("RB") then 
        MaskScroll(self)
        if Player.pickMaskSFX then Player.pickMaskSFX:SelectPlayAudioEvent("SFX_Mask_PickUp") end
    end

    if Input.GetKeyDown("9") or Input.GetGamepadButtonDown("LB")  then 
        EquipMask(self, Mask.NONE) 
        if Player.changeMaskSFX then Player.changeMaskSFX:SelectPlayAudioEvent("SFX_MaskChange") end
    end

    if Input.GetKeyDown("F1") then 
        giveApoloMask = true
        if Player.pickMaskSFX then Player.pickMaskSFX:SelectPlayAudioEvent("SFX_Mask_PickUp") end
    end

    if Input.GetKeyDown("F2") then 
        giveHermesMask = true
        if Player.pickMaskSFX then Player.pickMaskSFX:SelectPlayAudioEvent("SFX_Mask_PickUp") end
    end

    if Input.GetKeyDown("F3") then 
        giveAresMask = true
        if Player.pickMaskSFX then Player.pickMaskSFX:SelectPlayAudioEvent("SFX_Mask_PickUp") end
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

    if Player.stepSFX then
        Audio.SetSwitch("Surface_Type", Player.currentSurface, Player.stepSFX)
    end
end

function MaskScroll(self)
    local anim = self.gameObject:GetComponent("Animation")
    if anim then anim:Play("Mask", 1.0) end
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
end

function ObtainMask(self)
    if giveApoloMask and Mask.APOLLO == "None" then 
        Mask.APOLLO = "Apolo"
        Engine.Log("Apolo Mask obtain")
    end
    if giveHermesMask and Mask.HERMES == "None" then 
        Mask.HERMES = "Hermes"
        Engine.Log("Hermes Mask obtain")
    end
    if giveAresMask and Mask.ARES == "None" then
        Mask.ARES = "Ares" 
        Engine.Log("Ares Mask obtain")
    end
end

function ResetPlayer(self)
    Engine.Log("[Player] ResetPlayer llamado")

    self.public.health  = 100
    self.public.stamina = 100

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
    EquipMask(self, Mask.NONE)

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


local surfaces = {"Grass", "Water", "Dirt", "Stone"}

function OnTriggerEnter(self, other)
    local matched = false
    for i, surface in ipairs(surfaces) do
        if other:CompareTag(surface) then 
            Player.currentSurface = surface
            Player.foundSurface = true
        end
    end
    if not foundSurface then
        Player.currentSurface = "Dirt"
        foundSurface = true
    end
end

function OnTriggerExit(self, other) end

function OnCollisionEnter(self, other)
    if other:CompareTag("Water") and Player.currentMask == Mask.HERMES then
        Player.isDrowning            = true
        Player.hermesGraceTimer      = HERMES_GRACE_TIME
        Engine.Log("[Player] Hermes on water")
    end

	for i, surface in ipairs(surfaces) do
		if other:CompareTag(surface) then 
			Player.currentSurface = surface
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
    end
    if other:CompareTag("Dirt") or other:CompareTag("Grass") or other:CompareTag("Stone") then
        Player.respawnPos = self.transform.worldPosition
        Player.isGrounded = false
    end
end