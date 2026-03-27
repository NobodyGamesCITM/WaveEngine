-- PlayerController.lua

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local attackCol
local chargeCol
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
_PlayerController_shakeDuration      = 0.4
_PlayerController_shakeMagnitude     = 4.0
_PlayerController_lastAttack         = ""
_impactFrameTimer                    = 0
_PlayerController_currentMask        = "None"
_PlayerController_isDrowning         = false
_G._PlayerController_isDead          = false  
_G.PlayerInstance                    = nil

local INPUT_SCALE = 10
local HERMES_GRACE_TIME      = 0.2

-- MASKS
local Mask = {
    NONE   = "None",
    APOLLO = "Apollo",
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
    rb              = nil,
    sprintHeld      = false,
	smokePS         = nil,
    attackDelay     = 0.4,
    -- Audio
    stepSFX 		= nil,
    voiceSFX 		= nil,
    swordSFX 		= nil,
    pickMaskSFX     = nil,
    changeMaskSFX   = nil,
    itemPickSFX     = nil,
    hitSFX          = nil,
	currentSurface = "",
    
    -- Hermes mask
    respawnPos       = nil,
    isDrowning       = false,
    hermesGraceTimer = 0.2,
    hermesDeathRespawn = false,
    hermesDeathTimer   = 0.0,
    hermesPendingUnequip = false,
    baseSpeed = 15.0,
    isGrounded = false
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
    attackDuration      = 1.0,
    chargeDuration      = 0.3,
    shootDuration       = 0.2,
    attackCooldown      = 0.5,
    rollCooldownMax     = 0.5,
    knockbackForce      = 14.0,
    hitShakeDuration    = 0.3,
    hitShakeMagnitude   = 6.0,
    ROTATION_SPEED      = 780,
    hermesWaterMax      = 2.0,
    flySpeed            = 20.0,
    interact            = false,
    giveApoloMask       = false,
    giveHermesMask      = false,
    giveAresMask        = false
}


local function normalizeInput(x, z)
    local len = sqrt(x*x + z*z)
    if len > INPUT_SCALE then
        local inv = INPUT_SCALE / len
        return x * inv, z * inv
    end
    return x, z
end

local function GetMovementInput()
    local moveX, moveZ = 0, 0

    if Input.HasGamepad() then
        local gpX, gpZ = Input.GetLeftStick()
        moveX = gpX * INPUT_SCALE
        moveZ = gpZ * INPUT_SCALE
    end
    if Input.GetKey("W") then moveZ = moveZ - INPUT_SCALE end
    if Input.GetKey("S") then moveZ = moveZ + INPUT_SCALE end
    if Input.GetKey("A") then moveX = moveX - INPUT_SCALE end
    if Input.GetKey("D") then moveX = moveX + INPUT_SCALE end

    if interact == true then interact = false end
    if Input.GetKeyDown("R") then
        Engine.Log("interact try")
        interact = true
    end

    moveX, moveZ = normalizeInput(moveX, moveZ)
    local inputLen = sqrt(moveX*moveX + moveZ*moveZ)
    
    return moveX, moveZ, inputLen
end

local function GetAttackInput(self)
    if attackCooldown > 0 then return 0 end
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

    if Player.rb then
        Player.rb:SetLinearVelocity(faceDirX * speed, velY, faceDirZ * speed)
    end
end

local function UpdateFlyingGodMode(self, dt)
    local moveX, moveZ, _ = GetMovementInput()
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

local function ChangeState(self, newState)
    if Player.currentState == newState then return end
    
    Engine.Log("[Player] CHANGING STATE: " .. tostring(newState))
    
    if Player.currentState and States[Player.currentState].Exit then
        States[Player.currentState].Exit(self)
    end
    
    Player.currentState = newState
    
    if States[newState].Enter then
        States[newState].Enter(self)
    end
end

local function EquipMask(self, newMask)
    if Player.currentMask == newMask or Player.currentState == State.DEAD then return end

    --HERMES
    if Player.currentMask == Mask.HERMES and Player.isDrowning == false and Player.isGrounded == false then return end --por discutir
    if Player.currentMask == Mask.HERMES and Player.isDrowning then
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

    --NONE
    if newMask == Mask.NONE then
        Engine.Log("[Player] Unequipping mask")
    else
        Engine.Log("[Player] EQUIPPING MASK: " .. tostring(newMask))
    end
    
    Player.currentMask = newMask
    _PlayerController_currentMask = newMask
end

States[State.DEAD] = {
    Enter  = function(self)
        Engine.Log("[Player] Player is DEAD")
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        _G._PlayerController_isDead = true 
        if Player.voiceSFX then Player.voiceSFX:PlayAudioEvent() end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Idle", 0.5) end
    end,
    Update = function(self, dt)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        -- Debug: reset manual con tecla 1
        if Input.GetKeyDown("1") then
            self.public.health  = 100
            self.public.stamina = 100
            local p = lastCheckpoint
            self.transform:SetPosition(p.x, p.y, p.z)
            _G._PlayerController_isDead = false  -- NUEVO
            ChangeState(self, State.IDLE)
        end

        --respawn Hermes (aquí molaría hacer un fade out y algun sonidillo y tal)
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
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Idle", 0.5) end
    end,
    
    Update = function(self, dt)
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, math.min(0, velocity.y), 0)
        end

        local moveX, moveZ, inputLen = GetMovementInput()
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
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.ARES then
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
        local anim = self.gameObject:GetComponent("Animation")
        --if anim then anim:Play("Walk", 0.5) end --TEMPORAL CAMBIAR POR CAMINAR

        self.public.usingStamina = false

        if anim then 
            anim:Play("Running", 0.5) 
            anim:SetSpeed("Running", 1)
        end
    end,
    
    Update = function(self, dt)
        local sprintInput = Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5
        if sprintInput and not Player.sprintHeld and self.public.stamina > 10 then
            ChangeState(self, State.RUNNING)
        end
        local moveX, moveZ, inputLen = GetMovementInput()
        
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
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.ARES then
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
                Player.stepSFX:PlayAudioEvent()
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
        local moveX, moveZ, inputLen = GetMovementInput()

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
            if Player.currentMask == Mask.HERMES then
                ChangeState(self, State.CHARGING)
                return
            end
            if Player.currentMask == Mask.APOLLO then
                ChangeState(self, State.SHOOTING)
                return
            end
            if Player.currentMask == Mask.ARES then
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
                Player.stepSFX:PlayAudioEvent()
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
        _PlayerController_lastAttack = "heavy"
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.heavyStaminaCost
        end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Charge", 1.0) end
        attackTimer = 0
        if chargeCol then chargeCol:Enable() end
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
        if anim then anim:Play("Idle", 1.0) end --aquí shoot
        attackTimer = 0
    end,
    Update = function(self, dt)
        attackTimer = attackTimer + dt
        if attackTimer >= self.public.shootDuration then
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        _PlayerController_lastAttack = ""
    end
}

States[State.ATTACK_HEAVY] = {
    Enter = function(self)
        _PlayerController_lastAttack = "heavy"
    end,
    Update = function(self, dt) end,
    Exit = function(self)
        if attackCol then attackCol:Disable() end
        _PlayerController_lastAttack = ""
    end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("NormalAttack", 1.0) end
        _PlayerController_lastAttack = "light"
        attackTimer = 0
        if attackCol then attackCol:Disable() end
    end,
    Update = function(self, dt)
        if Player.rb then
            local velocity = Player.rb:GetLinearVelocity()
            Player.rb:SetLinearVelocity(0, velocity.y, 0)
        end

        attackTimer = attackTimer + dt

        if attackTimer >= Player.attackDelay and attackCol then
            attackCol:Enable()
        end

        if attackTimer >= self.public.attackDuration then
            if Player.swordSFX then 
                Player.swordSFX:PlayAudioEvent() 
            end
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        if attackCol then attackCol:Disable() end
        _PlayerController_lastAttack = ""
    end
}

local function TakeDamage(self, amount, attackerPos)
    if Player.currentState == State.DEAD then return end
    if Player.godMode then return end

    self.public.health = math.max(0, self.public.health - amount)
    Engine.Log("[Player] HP left: " .. tostring(self.public.health) .. "/100")

    _PlayerController_triggerCameraShake = true
    _PlayerController_shakeDuration      = self.public.hitShakeDuration
    _PlayerController_shakeMagnitude     = self.public.hitShakeMagnitude

    if self.public.health > 0 and Player.rb and attackerPos then
        if Player.hitSFX then Player.hitSFX:PlayAudioEvent() end
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

function Start(self)
    Engine.Log("Player inicializado")
    _G.PlayerInstance = self

    self.public.staminaCost    = 20.0   
    self.public.staminaRecover = 15.0 

    local spawnPos  = self.transform.worldPosition
    Player.spawnPos = spawnPos
    Player.respawnPos = spawnPos
    Player.baseSpeed = self.public.speed
    
    _impactFrameTimer = 0

    self.public.stamina = 100
    self.public.health  = 100

	--steps
    self.stepTimer = 0

    voiceSource = GameObject.Find("VoiceSource")
    attackSource = GameObject.Find("AttackSource")
    hitSource = GameObject.Find("HitSource")
    equipSource = GameObject.Find("EquipSource")
    changeSource = GameObject.Find("ChangeSource")
    itemSource = GameObject.Find("ItemSource")

    Player.stepSFX = self.gameObject:GetComponent("Audio Source")
    Player.voiceSFX = voiceSource:GetComponent("Audio Source")
    Player.swordSFX = attackSource:GetComponent("Audio Source")
    Player.hitSFX = hitSource:GetComponent("Audio Source")
    Player.pickMaskSFX = equipSource:GetComponent("Audio Source")
    Player.changeMaskSFX = changeSource:GetComponent("Audio Source")
    Player.itemPickSFX = itemSource:GetComponent("Audio Source")

    if not Player.stepSFX then
 		Engine.Log("[PLAYER AUDIO] Unable to retrieve the player's AudioSource") 
	end

    if not Player.voiceSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve VoiceSource") 
	end

    if not Player.swordSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve SwordSource") 
	end

    if not Player.hitSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve hitSource") 
	end

    if not Player.pickMaskSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve equipSource") 
	end
    
    if not Player.changeMaskSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve changeSource") 
	end

    if not Player.itemPickSFX then 
		Engine.Log("[PLAYER AUDIO] Unable to retrieve changeSource") 
	end

    Player.currentSurface = "Dirt" --default surface

    attackCooldown = 0
    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then attackCol:Disable() end 

    chargeCol = self.gameObject:GetComponent("Sphere Collider")
    if chargeCol then chargeCol:Disable() end 

    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil

    Player.rb = self.gameObject:GetComponent("Rigidbody")
    if not Player.rb then
        Engine.Log("[Player] No rigidbody found")
    end
    
    Player.isDrowning       = false
    Player.hermesGraceTimer = 0
    _PlayerController_currentMask = "None"
	
    local smokeObj = GameObject.Find("SmokeTrail")
    if smokeObj then
        Player.smokePS = smokeObj:GetComponent("ParticleSystem")
        if Player.smokePS then
            Player.smokePS:Stop()
        end
    else
        Engine.Log("[Player] No SmokeTrail child found")
    end

    _G._PlayerController_isDead = false

    ChangeState(self, State.IDLE)
    EquipMask(self, Mask.NONE)
end


function Update(self, dt)
    Engine.Log("[dt] " .. tostring(dt))
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
        Engine.Log("[Player] Update")
        ChangeState(self, State.IDLE)
    end

    if Player.godMode then
        UpdateFlyingGodMode(self, dt)
    elseif Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)

        if (Player.currentState == State.IDLE or Player.currentState == State.WALK) and self.public.stamina < 100 then
            self.public.stamina = math.min(100, self.public.stamina + (self.public.staminaRecover * dt))
        end
    end
    if Input.GetKey("7") and not Player.godMode then
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

    if Input.GetKey("8") then
        self.public.health = math.min(100, self.public.health + self.public.hpRecover)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    if not (Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5) then
        Player.sprintHeld = false
    end

    --hermes
    --DOING
    if Input.GetKeyDown("8") then 
        --EquipMask(self, Mask.HERMES) 
        MaskScroll(self)
        if Player.pickMaskSFX then Player.pickMaskSFX:PlayAudioEvent() end
    end --debug

    if Input.GetKeyDown("9") then 
        EquipMask(self, Mask.NONE) 
        if Player.changeMaskSFX then Player.changeMaskSFX:PlayAudioEvent() end
    end --debug

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
                Player.hermesDeathTimer   = 2.0
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
    if player.currentMask == Mask.NONE then EquipMask(Mask.APOLLO)
    elseif player.currentMask == Mask.APOLLO then EquipMask(Mask.HERMES)
    elseif player.currentMask == Mask.HERMES then EquipMask(Mask.ARES)
    elseif player.currentMask == Mask.ARES then EquipMask(Mask.APOLLO)
end
function ObtainMask(self)
    if giveApoloMask and Mask.APOLLO == "None" then Mask.APOLLO = "Apolo"end
    if giveHermesMask and Mask.HERMES == "None" then Mask.HERMES = "Hermes"end
    if giveAresMask and Mask.ARES == "None" then Mask.ARES = "Ares"end
end
function ResetPlayer(self)
    Engine.Log("[Player] ResetPlayer llamado")

    -- Vida y stamina al máximo
    self.public.health  = 100
    self.public.stamina = 100

    -- Pociones
    if _G.PotionSystem then
        _G.PotionSystem:ResetPotions()
    end

    -- Cooldowns
    attackCooldown = 0
    rollCooldown   = 0

    -- Limpiar flags globales
    _G._PlayerController_isDead           = false
    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil

    -- Masks
    Player.isDrowning            = false
    _PlayerController_isDrowning = false
    Player.hermesGraceTimer      = 0
    EquipMask(self, Mask.NONE)

    -- Reposicionar al spawn
    local p = Player.spawnPos
    if p then
        self.transform:SetPosition(p.x, p.y, p.z)
    end

    -- Forzar redibujado de UI
    if _G.ForceRefreshHUD then
        _G.ForceRefreshHUD()
    end
    -- Volver al estado inicial
    ChangeState(self, State.IDLE)
    Engine.Log("[Player] Reset completado")
end


local surfaces = {"Grass", "Water", "Dirt"}

function OnTriggerEnter(self, other)
	for i, surface in ipairs(surfaces) do
		if other:CompareTag(surface) then 
			Player.currentSurface = surface
		end
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

    if other:CompareTag("Dirt") or other:CompareTag("Grass") then
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
    if other:CompareTag("Dirt") or other:CompareTag("Grass") then
        Player.respawnPos = self.transform.worldPosition
        Player.isGrounded = false
    end
end