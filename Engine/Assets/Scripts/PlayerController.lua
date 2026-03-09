-- PlayerController.lua
-- Hybrid input (keyboard + gamepad).

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local INPUT_SCALE = 10

local STAMINA_BAR_MAX_HEIGHT = 68.0 

local function UpdateStaminaBar(stamina)
    local fill = (stamina / 100.0) * STAMINA_BAR_MAX_HEIGHT
    UI.SetElementHeight("StaminaGrid", fill) 
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
    currentState = nil,
    lastDirX     = 0,
    lastDirZ     = 1,
}

public = {
    speed               = 10.0,
    rollDuration        = 0.05,
    sprintMultiplier    = 1.5,
    stamina             = 100.0,
    speedIncrease       = 10,
    staminaCost         = 0.5,
    staminaRecover      = 0.1,
    usingStamina        = false,
    tiredMultiplier     = 0.7
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

local function ApplyMovementAndRotation(self, dt, moveX, moveZ)
    local pos = self.transform.position
    
    local nextX = pos.x + (moveX / INPUT_SCALE) * self.public.speed * dt
    local nextZ = pos.z + (moveZ / INPUT_SCALE) * self.public.speed * dt

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
            ChangeState(self, State.WALK)
        end
    end
}

States[State.WALK] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        usingStamina = false
        if anim then anim:Play("Walking", 0.5) end
    end,
    
    Update = function(self, dt)
        if Input.GetKey("LeftShift") and self.public.stamina > 10 then ChangeState(self, State.RUNNING) end
        local moveX, moveZ, inputLen = GetMovementInput()
        
        if inputLen > 1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end
        
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.RUNNING] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Walking", 0.5) end
        usingStamina = true
        self.public.speed = self.public.speed + self.public.speedIncrease
    end,
    Update = function(self, dt)
        if not Input.GetKey("LeftShift") then 
            self.public.speed = self.public.speed - self.public.speedIncrease
            ChangeState(self, State.WALK) 
        end
        local moveX, moveZ, inputLen = GetMovementInput()
        
        if inputLen > 1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        if self.public.stamina <= 0 then
            self.public.speed = self.public.speed - self.public.speedIncrease
            ChangeState(self, State.WALK) 
        end

        self.public.stamina = self.public.stamina - 0.5

        Engine.Log("[Player] STAMINA: " .. tostring(self.public.stamina))
        
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.ROLL] = {
    Enter = function(self)
    end,
    Update = function(self, dt)
    end
}

States[State.CHARGING] = {
    Enter = function(self)
    end,
    Update = function(self, dt)
    end
}

States[State.ATTACK_HEAVY] = {
    Enter = function(self)
    end,
    Update = function(self, dt)
    end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
    end,
    Update = function(self, dt)
    end
}

function Start(self)
    Engine.Log("Player inicializado")
    self.public.stamina = 100
    ChangeState(self, State.IDLE)
end

function Update(self, dt)
    if not Player.currentState then
        Engine.Log("[Player] Update")
        ChangeState(self, State.IDLE)
    end

    if Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)
        if not self.public.usingStamina and self.public.stamina < 100 then
            self.public.stamina = self.public.stamina + self.public.staminaRecover
        end
    end

    UpdateStaminaBar(self.public.stamina)
end