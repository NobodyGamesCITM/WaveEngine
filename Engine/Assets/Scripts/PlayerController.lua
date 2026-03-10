-- PlayerController.lua
-- Hybrid input (keyboard + gamepad).

local sqrt  = math.sqrt
local abs   = math.abs
local atan2 = math.atan
local pi    = math.pi

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
    rollDuration        = 5,
    sprintMultiplier    = 1.5,
    rollMultiplier      = 10,
    stamina             = 4,
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

local function ApplyMovementAndRotation(self, dt, moveX, moveZ, speedOverride)
    local pos = self.transform.position
    local speed = speedOverride or self.public.speed

    -- Calculates the new pos
    local nextX = pos.x + (moveX / INPUT_SCALE) * speed * dt
    local nextZ = pos.z + (moveZ / INPUT_SCALE) * speed * dt

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
        -- Anim running
    end,
    Update = function(self, dt)
        local moveX, moveZ, inputLen = GetMovementInput()

        if inputLen <= 0.1 then
            ChangeState(self, State.IDLE)
            return
        end

        if not Input.GetKey("LeftShift") then
            ChangeState(self, State.WALK)
            return
        end

        if inputLen > 0.1 then
            Player.lastDirX = moveX / INPUT_SCALE
            Player.lastDirZ = moveZ / INPUT_SCALE
        end

        -- Check if can trasition to Roll, AttackLight, Charging y todo eso
        if Input.GetKeyDown("LeftCtrl") then
            ChangeState(self, State.ROLL)
            return
        end

        local sprintSpeed = self.public.speed * self.public.sprintMultiplier
        ApplyMovementAndRotation(self, dt, moveX, moveZ, sprintSpeed)
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
    end,
    Update = function(self, dt)
        -- wait anim end and return idle
    end
}

function Start(self)
    Engine.Log("Player inicializado")
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