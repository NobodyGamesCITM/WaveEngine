-- PlayerController.lua
-- Hybrid input (keyboard + gamepad).

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

local attackCol
local attackTimer = 0

local INPUT_SCALE = 10

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
    stamina             = 4,
    tiredMultiplier     = 0.7,  
    attackDuration      = 0.1
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

local function GetAttackInput()
    if Input.GetKey("E") then return 1 end
    return 0
end

local function ApplyMovementAndRotation(self, dt, moveX, moveZ)
    local pos = self.transform.position
    
    -- Calculates the new pos
    local nextX = pos.x + (moveX / INPUT_SCALE) * self.public.speed * dt
    local nextZ = pos.z + (moveZ / INPUT_SCALE) * self.public.speed * dt

    self.transform:SetPosition(nextX, pos.y, nextZ)

    -- Apply rotation
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
        
        -- TRANSITION, se usa 0.1 por el drift
        if inputLen > 0.1 then
            ChangeState(self, State.WALK)
            
        end
        
        if GetAttackInput() == 1 then
            ChangeState(self, State.ATTACK_LIGHT)
        end
        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
    end
}

States[State.WALK] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then anim:Play("Walking", 0.5) end
    end,
    
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput()
        
        -- Save the last direction looking so the roll is on that direction
        if inputLen > 1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        -- Transition to idle if you can move
        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end
        
        if GetAttackInput() == 1 then
            ChangeState(self, State.ATTACK_LIGHT)
            return
        end
        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        
        -- Movement and rotation
        ApplyMovementAndRotation(self, dt, moveX, moveZ)
    end
}

States[State.RUNNING] = {
    Enter = function(self)
        -- Anim running
    end,
    Update = function(self, dt)
        -- Logic running, muliply vel and stamina
    end
}

States[State.ROLL] = {
    Enter = function(self)
        -- Anim roll, fix direction, stamina...
    end,
    Update = function(self, dt)
        -- Move on the direction fixed ignoring the input digo yo, transition to idle at end
    end
}

States[State.CHARGING] = {
    Enter = function(self)
        -- Anim attackheavy
    end,
    Update = function(self, dt)
        -- Move slow y todo eso
    end
}

States[State.ATTACK_HEAVY] = {
    Enter = function(self)
        -- Stamina, anim attack y todo eso
    end,
    Update = function(self, dt)
        -- return idle
    end
}

States[State.ATTACK_LIGHT] = {
    Enter = function(self)
        -- Anim attacklight
        attackTimer = 0
        if attackCol then attackCol:Enable() end
    end,
    Update = function(self, dt)
        -- wait anim end and return idle
        attackTimer = attackTimer + dt
        if attackTimer >= self.public.attackDuration then
            ChangeState(self, State.IDLE)
        end
    end,
    Exit = function(self)
        if attackCol then attackCol:Disable() end
    end
}

function Start(self)
    Engine.Log("Player inicializado")

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then attackCol:Disable() end 

    ChangeState(self, State.IDLE)
end

function Update(self, dt)
    if not Player.currentState then
        Engine.Log("[Player] Update")
        ChangeState(self, State.IDLE)
    end

    if Player.currentState and States[Player.currentState] then
        States[Player.currentState].Update(self, dt)
    end
end

function OnCollisionEnter(self, otherName)
    Engine.Log("[Player] Hit a: " .. otherName)
end

function OnTriggerEnter(self, otherName)
    Engine.Log("[Player] Triggered with a: " .. otherName)
end