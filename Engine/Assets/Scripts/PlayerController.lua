-- PlayerController.lua
-- Hybrid input (keyboard + gamepad).

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local INPUT_SCALE = 10

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

-- STATES
local State = {
    IDLE         = "Idle",
    WALK         = "Walk",
    RUNNING      = "Running",
    ROLL         = "Roll",
    CHARGING     = "Charging",
    ATTACK_LIGHT = "AttackLight",
    ATTACK_HEAVY = "AttackHeavy"
}

local Player = {
    currentState    = nil,
    lastDirX        = 0,
    lastDirZ        = 1,

    -- Potion state
    potionCount         = 4,
    potionHealing       = false,   -- ¿está recuperando vida ahora mismo?
    potionHealRemaining = 0.0,     -- vida que queda por recuperar
    potionHealTotal     = 30.0,    -- vida total que da cada poción
    potionHealRate      = 15.0,    -- vida por segundo que se recupera
    potionCooldown      = 0.0,     -- cooldown para evitar spam de la tecla 3
    potionCooldownMax   = 0.5,
}

public = {
    speed               = 10.0,
    rollDuration        = 5,
    sprintMultiplier    = 1.5,
    rollMultiplier      = 10,
    stamina             = 100.0,
    health              = 100.0,
    speedIncrease       = 10,
    staminaCost         = 0.1,
    staminaRecover      = 0.1,
    usingStamina        = false,
    tiredMultiplier     = 0.7,
    hpLossCost          = 0.2,   
    hpRecover           = 0.2,  
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

local function ApplyMovementAndRotation(self, dt, moveX, moveZ, speedOverride)
    local pos = self.transform.position
    local speed = speedOverride or self.public.speed

    -- Calculates the new pos
    local nextX = pos.x + (moveX / INPUT_SCALE) * speed * dt
    local nextZ = pos.z + (moveZ / INPUT_SCALE) * speed * dt

    self.transform:SetPosition(nextX, pos.y, nextZ)

    local faceDirX = moveX / INPUT_SCALE
    local faceDirZ = moveZ / INPUT_SCALE

    if abs(faceDirX) > 0.01 or abs(faceDirZ) > 0.01 then
        local angleDeg = atan2(faceDirX, faceDirZ) * (180.0 / pi)
        self.transform:SetRotation(0, angleDeg, 0)
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

States[State.IDLE] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Idle", 0.5) end
    end,
    
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput()
        if inputLen > 0.1 then
            if Input.GetKey("LeftShift") then
                ChangeState(self, State.RUNNING)
            else
                ChangeState(self, State.WALK)
            end
        end
        
        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        if Input.GetKeyDown("LeftCtrl") then
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
        if Input.GetKey("LeftShift") and self.public.stamina > 10 then
            ChangeState(self, State.RUNNING)
        end
        local moveX, moveZ, inputLen = GetMovementInput()
        
        if inputLen > 1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end
        
        if Input.GetKey("LeftShift") then
            ChangeState(self, State.RUNNING)
            return
        end

        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        
        if Input.GetKeyDown("LeftCtrl") then
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
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput()

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end

        if not Input.GetKey("LeftShift") then
            self.public.speed = self.public.speed - self.public.speedIncrease
            ChangeState(self, State.WALK)
            return
        end

        if inputLen > 0.1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        if Input.GetKeyDown("LeftCtrl") then
            self.public.speed = self.public.speed - self.public.speedIncrease
            ChangeState(self, State.ROLL)
            return
        end

        if self.public.stamina <= 0 then
            self.public.speed = self.public.speed - self.public.speedIncrease
            ChangeState(self, State.WALK)
            return
        end

        self.public.stamina = self.public.stamina - self.public.staminaCost
        Engine.Log("[Player] STAMINA: " .. tostring(self.public.stamina))

        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.ROLL] = {
    timer = 0,
    Enter = function(self)
        -- Anim roll, fix direction, stamina...
        States[State.ROLL].timer = self.public.rollDuration
    end,
    Update = function(self, dt)
        -- Move on the direction fixed ignoring the input digo yo, transition to idle at end
        States[State.ROLL].timer = States[State.ROLL].timer - dt

        if States[State.ROLL].timer <= 0 then
            ChangeState(self, State.IDLE)
            return
        end

        local pos = self.transform.position
        local rollSpeed = self.public.speed * self.public.rollMultiplier
        local nextX = pos.x + Player.lastDirX * rollSpeed * dt
        local nextZ = pos.z + Player.lastDirZ * rollSpeed * dt
        self.transform:SetPosition(nextX, pos.y, nextZ)
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
    Enter = function(self) end,
    Update = function(self, dt) end
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

function Start(self)
    Engine.Log("Player inicializado")
    self.public.stamina = 100
    self.public.health  = 100
    Player.potionCount  = 4
    ChangeState(self, State.IDLE)
    UpdatePotionUI(Player.potionCount)
end

function Update(self, dt)
    if not Player.currentState then
        Engine.Log("[Player] Update")
        ChangeState(self, State.IDLE)
    end

    if Player.currentState and States[Player.currentState] then
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
    if Input.GetKey("1") then
        self.public.health = math.max(0, self.public.health - self.public.hpLossCost)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    -- Tecla 2: ganar vida (debug)
    if Input.GetKey("2") then
        self.public.health = math.min(100, self.public.health + self.public.hpRecover)
        Engine.Log("[Player] HEALTH: " .. tostring(self.public.health))
    end

    UpdateStaminaBar(self.public.stamina)
    UpdateHealthBar(self.public.health)
end