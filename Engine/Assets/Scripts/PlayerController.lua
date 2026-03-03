-- PlayerController.lua
-- Hybrid input (keyboard + gamepad) with a roll mechanic.

local sqrt  = math.sqrt
local abs   = math.abs
local max_  = math.max
local atan2 = math.atan2
local pi    = math.pi

local INPUT_SCALE = 10
local STAMINA_USAGE = true

local Player = {
    rollSpeed    = 20.0,
    rollCooldown = 0.8,
    rollTimer    = 0,
    coolTimer    = 0,
    rollDirX     = 0,
    rollDirZ     = 0,
    lastDirX     = 0,
    lastDirZ     = 1,
}



public = {
    speed               = 10.0,
    rollDuration        = 0.05,
    sprintMultiplier    = 1.5,
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



local function isRollPressed()
    local space = Input.GetKeyDown("Space")
    local aBtn  = Input.HasGamepad() and Input.GetGamepadButtonDown("A")
    return space or aBtn
end

local function startRoll(dirX, dirZ, cfg)
    cfg.stamina = cfg.stamina - 1
    Player.rollDirX  = dirX
    Player.rollDirZ  = dirZ
    Player.rollTimer = cfg.rollDuration
    Player.coolTimer = Player.rollCooldown
end



local function IsSprintPressed()
    local shift = Input.GetKeyDown("LeftShift")
    local bbtn  = Input.HasGamepad() and Input.GetGamepadButtonDown("B")
    return shift or bbtn
end

local function startSprint(cfg)
    cfg.stamina = cfg.stamina - 1
    local sprintVelocity
    sprintVelocity = cfg.speed * cfg.sprintMultiplier
end

local function tired(cfg)
    Engine.Log("Stamina: " ..cfg.stamina)
    local tiredVelocity
    tiredVelocity = cfg.speed * cfg.tiredMultiplier
    STAMINA_USAGE = false
end

local function recoverStamina(cfg)
    cfg.stamina = cfg.stamina + 1
    STAMINA_USAGE = true
    Engine.Log("Stamina recovered: " ..cfg.stamina)
end

function Start(self)
    Engine.Log("Player inicialized")
    Engine.Log("Stamina: " ..self.public.stamina)
end

function Update(self, dt)
    
    local anim = self.gameObject:GetComponent("Animation")

    Player.rollTimer = max_(0, Player.rollTimer - dt)
    Player.coolTimer = max_(0, Player.coolTimer - dt)

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

    moveX, moveZ   = normalizeInput(moveX, moveZ)
    local inputLen = sqrt(moveX*moveX + moveZ*moveZ)

    if inputLen > 0 then
        anim:Play("Walking", 0.5)
    else
        anim:Play("Idle", 0.5)
    end

    if inputLen > 1 then
        Player.lastDirX = moveX / INPUT_SCALE
        Player.lastDirZ = moveZ / INPUT_SCALE
    end

    -- Run functions --
    if IsSprintPressed() then
        startSprint(self.public)
    end

    if self.public.stamina <= 0 then
        tired(self.public)
    end

    if isRollPressed() and Player.rollTimer <= 0 and Player.coolTimer <= 0 then
        local dirX = inputLen > 1 and (moveX / INPUT_SCALE) or Player.lastDirX
        local dirZ = inputLen > 1 and (moveZ / INPUT_SCALE) or Player.lastDirZ
        startRoll(dirX, dirZ, self.public)
        Engine.Log("Stamina: " ..self.public.stamina)
    end

    local pos   = self.transform.position
    local nextX = pos.x
    local nextZ = pos.z

    if Player.rollTimer > 0 then
        nextX = pos.x + Player.rollDirX * Player.rollSpeed * dt
        nextZ = pos.z + Player.rollDirZ * Player.rollSpeed * dt
    elseif inputLen > 0 then
        nextX = pos.x + (moveX / INPUT_SCALE) * self.public.speed * dt
        nextZ = pos.z + (moveZ / INPUT_SCALE) * self.public.speed * dt
    end

    self.transform:SetPosition(nextX, pos.y, nextZ)

    local faceDirX = Player.rollTimer > 0 and Player.rollDirX or (moveX / INPUT_SCALE)
    local faceDirZ = Player.rollTimer > 0 and Player.rollDirZ or (moveZ / INPUT_SCALE)

    if abs(faceDirX) > 0.01 or abs(faceDirZ) > 0.01 then
        local angleDeg = atan2(faceDirX, faceDirZ) * (180.0 / pi)
        self.transform:SetRotation(0, angleDeg, 0)
    end
end
