-- PlayerController.lua
-- Hybrid input (keyboard + gamepad).

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local attackCol
local attackTimer = 0
local rollCooldown = 0

_PlayerController_triggerCameraShake = false
_PlayerController_shakeDuration      = 0.4
_PlayerController_shakeMagnitude     = 4.0
_PlayerController_lastAttack         = ""
_impactFrameTimer                    = 0
_PlayerController_currentMask        = "None"
_PlayerController_isDrowning         = false

local INPUT_SCALE = 10
local STAMINA_BAR_MAX_HEIGHT = 68.0 
local HEALTH_BAR_MAX_HEIGHT  = 68.0 
local HERMES_GRACE_TIME      = 0.2

local function UpdateStaminaBar(stamina)
    local fill = (stamina / 100.0) * STAMINA_BAR_MAX_HEIGHT
    UI.SetElementHeight("StaminaGrid", fill) 
end

local function UpdateHealthBar(health)
    local fill = (health / 100.0) * HEALTH_BAR_MAX_HEIGHT
    UI.SetElementHeight("HealthGrid", fill) 
end

local function UpdatePotionUI(potions)
    for i = 1, 4 do
        local imageName = "Potion_Image" .. tostring(i)
        if (4 - i) < potions then
            UI.SetElementVisibility(imageName, true)
        else
            UI.SetElementVisibility(imageName, false)
        end
    end
end

local STAMINA_BAR_MAX_HEIGHT = 68.0 
local HEALTH_BAR_MAX_HEIGHT  = 68.0 

local function UpdateStaminaBar(stamina)
    local fill = (stamina / 100.0) * STAMINA_BAR_MAX_HEIGHT
    UI.SetElementHeight("StaminaGrid", fill) 
end

local function UpdateHealthBar(health)
    local fill = (health / 100.0) * HEALTH_BAR_MAX_HEIGHT
    UI.SetElementHeight("HealthGrid", fill) 
end

local function UpdatePotionUI(potions)
    for i = 1, 4 do
        local imageName = "Potion_Image" .. tostring(i)
        if (4 - i) < potions then
            UI.SetElementVisibility(imageName, true)
        else
            UI.SetElementVisibility(imageName, false)
        end
    end
end

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

    -- Potion state
    potionCount         = 4,
    potionHealing       = false,   -- ¿está recuperando vida ahora mismo?
    potionHealRemaining = 0.0,     -- vida que queda por recuperar
    potionHealTotal     = 30.0,    -- vida total que da cada poción
    potionHealRate      = 15.0,    -- vida por segundo que se recupera
    potionCooldown      = 0.0,     -- cooldown para evitar spam de la tecla 3
    potionCooldownMax   = 0.5,

    -- Hermes mask
    isDrowning       = false,
    hermesGraceTimer = 0.0,
}

public = {
    speed               = 15.0,
    rollDuration        = 0.4,
    sprintMultiplier    = 1.5,
    rollSpeed           = 37.5,
    stamina             = 100.0,
    health              = 100.0,
    speedIncrease       = 10.0,
    speedHermesBonus    = 15.0,
    staminaCost         = 0.1,
    staminaRecover      = 0.1,
    rollStaminaCost     = 25,
    usingStamina        = false,
    tiredMultiplier     = 0.7,
    hpLossCost          = 0.2,
    hpRecover           = 0.2,
    attackDuration      = 0.5,
    attackCooldown      = 0.5,
    rollCooldownMax     = 0.5,
    knockbackForce      = 14.0,
    hitShakeDuration    = 0.3,
    hitShakeMagnitude   = 6.0,
    ROTATION_SPEED      = 780,
    hermesWaterMax      = 2.0,
    flySpeed            = 20.0
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

    moveX, moveZ = normalizeInput(moveX, moveZ)
    local inputLen = sqrt(moveX*moveX + moveZ*moveZ)
    
    return moveX, moveZ, inputLen
end

local function GetAttackInput(self)
    if attackCooldown > 0 then return 0 end
    if Input.GetKeyDown("E") then return 1 end
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
    if Player.currentMask == newMask then return end

    --HERMES
        if Player.currentMask == Mask.HERMES and Player.isDrowning then
        Engine.Log("[Player] Hermes while on water!!")
        return
    end
    if Player.currentMask == Mask.HERMES then
        self.public.speedIncrease = self.public.speedIncrease - self.public.speedHermesBonus
        Player.hermesGraceTimer   = 0
        if Player.currentState == State.RUNNING then
            self.public.speed = self.public.speed - self.public.speedHermesBonus
        end
        if Player.isDrowning then
            Player.isDrowning            = false
            _PlayerController_isDrowning = false
            self.public.health           = 0
            ChangeState(self, State.DEAD)
            Player.currentMask            = newMask
            _PlayerController_currentMask = newMask
            return
        end
        Player.isDrowning = false
    end
    if newMask == Mask.HERMES then
        self.public.speedIncrease = self.public.speedIncrease + self.public.speedHermesBonus
        if Player.currentState == State.RUNNING then
            self.public.speed = self.public.speed + self.public.speedHermesBonus
        end
    end

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
    end,
    Update = function(self, dt)
        if Player.rb then Player.rb:SetLinearVelocity(0, 0, 0) end
        if Input.GetKeyDown("1") then
            self.public.health  = 100
            self.public.stamina = 100
            local p = Player.spawnPos
            self.transform:SetPosition(p.x, p.y, p.z)
            ChangeState(self, State.IDLE)
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
        end
        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end
    end
}

States[State.WALK] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        self.public.usingStamina = false
        if anim then anim:Play("Walking", 0.5) end
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

        -- Check if can trasition to Roll, AttackLight, Charging y todo eso

        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and self.public.stamina >= self.public.rollStaminaCost and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end

        -- Movement and rotation
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.RUNNING] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Walking", 0.5) end
        self.public.usingStamina = true
        self.public.speed = self.public.speed + self.public.speedIncrease
    end,
    Exit = function(self)
        self.public.speed = self.public.speed - self.public.speedIncrease
        self.public.usingStamina = false
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

        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        if (Input.GetKeyDown("LeftCtrl") or Input.GetGamepadButtonDown("B")) and rollCooldown <= 0 then
            ChangeState(self, State.ROLL)
            return
        end

        if self.public.stamina <= 0 then
            ChangeState(self, State.WALK)
            return
        end

        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.staminaCost
        end
        Engine.Log("[Player] STAMINA: " .. tostring(self.public.stamina))

        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.ROLL] = {
    timer = 0,
    Enter = function(self)
        -- Anim roll, fix direction, stamina...
        if not Player.godMode then
            self.public.stamina = self.public.stamina - self.public.rollStaminaCost
        end
        States[State.ROLL].timer = self.public.rollDuration
    end,
    Exit = function(self)
        rollCooldown = self.public.rollCooldownMax
    end,
    Update = function(self, dt)
        -- Move on the direction fixed ignoring the input digo yo, transition to idle at end
        States[State.ROLL].timer = States[State.ROLL].timer - dt

        if States[State.ROLL].timer <= 0 then
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
    Enter = function(self) end,
    Update = function(self, dt) end
}

States[State.ATTACK_HEAVY] = {
    Enter = function(self) end,
    Update = function(self, dt) end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
        -- Anim attacklight
        _PlayerController_lastAttack = "light"
        attackTimer = 0
        if attackCol then attackCol:Enable() end
    end,
    Update = function(self, dt)
        -- wait anim end and return idle
        attackTimer = attackTimer + dt
        if attackTimer >= self.public.attackDuration then
            attackCooldown = self.public.attackCooldown
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        if attackCol then attackCol:Disable() end
    end
}

local function UpdatePotionHeal(self, dt)
    if Player.potionHealing then
        local healThisTick = Player.potionHealRate * dt
        local actualHeal   = math.min(healThisTick, Player.potionHealRemaining)
        local maxHeal      = math.min(actualHeal, 100.0 - self.public.health)

        self.public.health          = self.public.health + maxHeal
        Player.potionHealRemaining  = Player.potionHealRemaining - actualHeal

        Engine.Log("[Player] POTION HEAL: +" .. tostring(maxHeal) .. " | HP: " .. tostring(self.public.health))

        -- Terminar curación cuando se agota la cantidad o la vida ya está llena
        if Player.potionHealRemaining <= 0 or self.public.health >= 100.0 then
            Player.potionHealing       = false
            Player.potionHealRemaining = 0.0
        end
    end
end

local function TakeDamage(self, amount, attackerPos)
    if Player.currentState == State.DEAD then return end
    if Player.godMode then return end

    self.public.health = math.max(0, self.public.health - amount)
    Engine.Log("[Player] HP left: " .. tostring(self.public.health) .. "/100")

    _PlayerController_triggerCameraShake = true
    _PlayerController_shakeDuration      = self.public.hitShakeDuration
    _PlayerController_shakeMagnitude     = self.public.hitShakeMagnitude

    if self.public.health > 0 and Player.rb and attackerPos then
        local playerPos = self.transform.worldPosition
        local dx = playerPos.x - attackerPos.x
        local dz = playerPos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        Player.rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    UpdateHealthBar(self.public.health)

    if self.public.health <= 0 then
        Engine.Log("[Player] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.17
        ChangeState(self, State.DEAD)
    end
end

function Start(self)
    Engine.Log("Player inicializado")

    --respawn debug
    local spawnPos = self.transform.worldPosition
    Player.spawnPos = spawnPos
    
    --stamina
    _impactFrameTimer = 0

    self.public.stamina = 100
    self.public.health  = 100
    Player.potionCount  = 4

    --attack
    attackCooldown = 0
    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then attackCol:Disable() end 
    _PlayerController_pendingDamage    = 0
    _PlayerController_pendingDamagePos = nil

    --rigidbody
    Player.rb = self.gameObject:GetComponent("Rigidbody")
    if not Player.rb then
        Engine.Log("[Player] No rigidbody found")
    end
    
    --masks
    Player.isDrowning       = false
    Player.hermesGraceTimer = 0
    _PlayerController_currentMask = "None"

    ChangeState(self, State.IDLE)
    EquipMask(self, Mask.NONE)
    UpdatePotionUI(Player.potionCount)
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
        Engine.Log("[Player] Update")
        ChangeState(self, State.IDLE)
    end

    if Player.godMode then
        UpdateFlyingGodMode(self, dt)
    elseif Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)

        -- Recuperar stamina si no se está usando
        if not self.public.usingStamina and self.public.stamina < 100 then
            self.public.stamina = self.public.stamina + self.public.staminaRecover
        end
    end

    -- Cooldown de la tecla de poción (evita consumir varias en un frame)
    if Player.potionCooldown > 0 then
        Player.potionCooldown = Player.potionCooldown - dt
    end

    -- Tecla 3: usar poción
    if Input.GetKey("3") and Player.potionCooldown <= 0 then
        if Player.potionCount > 0 and self.public.health < 100 and not Player.potionHealing then
            Player.potionCount          = Player.potionCount - 1
            Player.potionHealing        = true
            Player.potionHealRemaining  = Player.potionHealTotal
            Player.potionCooldown       = Player.potionCooldownMax
            Engine.Log("[Player] POCION USADA | Restantes: " .. tostring(Player.potionCount))
            UpdatePotionUI(Player.potionCount)
        end
    end

    -- Aplicar curación gradual de la poción
    UpdatePotionHeal(self, dt)

    -- Tecla 1: perder vida (debug)
    if Input.GetKey("1") and not Player.godMode then
        self.public.health = math.max(0, self.public.health - self.public.hpLossCost)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    -- Tecla G: toggle god mode (debug)
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

    -- Tecla 2: ganar vida (debug)
    if Input.GetKey("2") then
        self.public.health = math.min(100, self.public.health + self.public.hpRecover)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    if not (Input.GetKey("LeftShift") or Input.GetGamepadAxis("LT") > 0.5) then
        Player.sprintHeld = false
    end

    UpdateStaminaBar(self.public.stamina)
    UpdateHealthBar(self.public.health)

    --hermes
    if Input.GetKeyDown("8") then EquipMask(self, Mask.HERMES) end --debug
    if Input.GetKeyDown("9") then EquipMask(self, Mask.NONE) end --debug

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
                self.public.health = 0
                Engine.Log("[Player] Out of hermes :( )")
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

function OnTriggerEnter(self, other) end
function OnTriggerExit(self, other) end

function OnCollisionEnter(self, other)
    if other:CompareTag("Water") and Player.currentMask == Mask.HERMES then
        Player.isDrowning            = true
        _PlayerController_isDrowning = true
        Player.hermesGraceTimer      = HERMES_GRACE_TIME
        Engine.Log("[Player] Hermes on water")
    end
end

function OnCollisionExit(self, other)
    if other:CompareTag("Water") then
        Player.isDrowning            = false
        _PlayerController_isDrowning = false
        Player.hermesGraceTimer      = 0
        Engine.Log("[Player] Player out of water")
    end
end