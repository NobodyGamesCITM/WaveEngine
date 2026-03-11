-- Controls:
-- 5 → Zoom In  (hold)
-- 6 → Zoom Out (hold)
-- 7 → Camera Shake (press)



public = {
    playerName     = "MC",
    followSpeed    = 5.0,
    zoomSpeed      = 3.0,
    zoomMin        = 0.3,
    zoomMax        = 3.0,
    shakeDuration  = 0.4,
    shakeMagnitude = 0.3,
    shakeFrequency = 25.0,
}

-- Internal state
local initialized      = false
local playerTransform  = nil

-- Initial world offset (camera - player)
local offsetX, offsetY, offsetZ = 0.0, 0.0, 0.0
local offsetScale = 1.0  -- 1.0 = original distance

-- Shake state
local shakeTimer   = 0.0
local shakeOffsetX = 0.0
local shakeOffsetZ = 0.0

local function clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function Init(self)
    local playerObj = GameObject.Find(self.public.playerName)
    if not playerObj then return end

    playerTransform = playerObj.transform

    -- Compute initial world offset
    local camPos    = self.transform.worldPosition
    local playerPos = playerTransform.worldPosition

    offsetX = camPos.x - playerPos.x
    offsetY = camPos.y - playerPos.y
    offsetZ = camPos.z - playerPos.z

    offsetScale = 1.0
    initialized = true
end

-- Smooth follow towards player + scaled offset
local function UpdateFollow(self, dt)
    local playerPos = playerTransform.worldPosition

    local targetX = playerPos.x + offsetX * offsetScale
    local targetY = playerPos.y + offsetY * offsetScale
    local targetZ = playerPos.z + offsetZ * offsetScale

    -- Remove previous frame shake before interpolation
    local camPos = self.transform.worldPosition
    local cleanX = camPos.x - shakeOffsetX
    local cleanZ = camPos.z - shakeOffsetZ

    local t = clamp(self.public.followSpeed * dt, 0.0, 1.0)

    local baseX = lerp(cleanX, targetX, t)
    local baseY = lerp(camPos.y, targetY, t)
    local baseZ = lerp(cleanZ, targetZ, t)

    -- Apply shake on top of base position
    self.transform:SetPosition(baseX + shakeOffsetX, baseY, baseZ + shakeOffsetZ)
end

local function UpdateZoom(self, dt)
    local zoomDir = 0
    if Input.GetKey("5") then zoomDir = -1 end
    if Input.GetKey("6") then zoomDir =  1 end
    if zoomDir == 0 then return end

    local cfg = self.public
    offsetScale = clamp(
        offsetScale + zoomDir * cfg.zoomSpeed * dt,
        cfg.zoomMin,
        cfg.zoomMax
    )
end

local function TriggerShake(self)
    shakeTimer = self.public.shakeDuration
end

local function UpdateShake(self, dt)
    local cfg = self.public

    if shakeTimer <= 0.0 then
        shakeOffsetX = 0.0
        shakeOffsetZ = 0.0
        return
    end

    shakeTimer = shakeTimer - dt

    -- Linearly decreasing amplitude
    local progress  = shakeTimer / cfg.shakeDuration
    local amplitude = cfg.shakeMagnitude * progress
    local t         = cfg.shakeDuration - shakeTimer

    -- 2D shake on XZ plane
    shakeOffsetX = amplitude * math.sin(t * cfg.shakeFrequency * 2.0 * math.pi)
    shakeOffsetZ = amplitude * math.sin(t * cfg.shakeFrequency * 2.0 * math.pi * 1.3)

    if shakeTimer <= 0.0 then
        shakeOffsetX = 0.0
        shakeOffsetZ = 0.0
    end
end

function Start(self)
    Init(self)
end

function Update(self, dt)
    if not initialized then
        Init(self)
        return
    end

    UpdateZoom(self, dt)

    if Input.GetKeyDown("7") then
        TriggerShake(self)
    end

    if _PlayerController_triggerCameraShake then
        if _PlayerController_shakeDuration  then self.public.shakeDuration  = _PlayerController_shakeDuration  end
        if _PlayerController_shakeMagnitude then self.public.shakeMagnitude = _PlayerController_shakeMagnitude end
        TriggerShake(self)
        _PlayerController_triggerCameraShake = false
    end

    UpdateShake(self, dt)
    UpdateFollow(self, dt)
end