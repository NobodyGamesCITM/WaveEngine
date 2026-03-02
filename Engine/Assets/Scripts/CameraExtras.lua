



public = {
    playerName     = "MC",  -- nombre del GameObject del jugador
    followSpeed    = 5.0,        -- velocidad de interpolacion del seguimiento
    zoomSpeed      = 3.0,        -- unidades por segundo
    zoomMin        = 0.3,        -- escala minima del offset (muy cerca)
    zoomMax        = 3.0,        -- escala maxima del offset (muy lejos)
    shakeDuration  = 0.4,
    shakeMagnitude = 0.3,
    shakeFrequency = 25.0,
}

local initialized  = false
local playerTransform = nil

-- Offset inicial camara - player (se calcula en Init)
local offsetX, offsetY, offsetZ = 0.0, 0.0, 0.0
-- Escala del offset (zoom): 1.0 = distancia original
local offsetScale = 1.0

-- Shake
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
    if not playerObj then
        Engine.Log("[CameraFeatures] ERROR: No se encontro el GameObject '" .. self.public.playerName .. "'")
        return
    end

    playerTransform = playerObj.transform

    
    local camPos    = self.transform.worldPosition
    local playerPos = playerTransform.worldPosition

    offsetX = camPos.x - playerPos.x
    offsetY = camPos.y - playerPos.y
    offsetZ = camPos.z - playerPos.z

    offsetScale = 1.0
    initialized = true
end



local function UpdateFollow(self, dt)
    local playerPos = playerTransform.worldPosition

   
    local targetX = playerPos.x + offsetX * offsetScale
    local targetY = playerPos.y + offsetY * offsetScale
    local targetZ = playerPos.z + offsetZ * offsetScale

   
    local camPos = self.transform.worldPosition

    
    local t = clamp(self.public.followSpeed * dt, 0.0, 1.0)
    local newX = lerp(camPos.x, targetX, t) + shakeOffsetX
    local newY = lerp(camPos.y, targetY, t)
    local newZ = lerp(camPos.z, targetZ, t) + shakeOffsetZ

    self.transform:SetPosition(newX, newY, newZ)
end

local function UpdateZoom(self, dt)
    local zoomDir = 0
    if Input.GetKey("5") then zoomDir = -1 end  -- acercar
    if Input.GetKey("6") then zoomDir =  1 end  -- alejar
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

    local progress  = shakeTimer / cfg.shakeDuration
    local amplitude = cfg.shakeMagnitude * progress
    local t         = cfg.shakeDuration - shakeTimer

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
    UpdateShake(self, dt)
    UpdateFollow(self, dt)
end