-- FogTrigger.lua
-- Cambia la niebla del PostProcessing cuando el player entra/sale del trigger.
--
-- SETUP:
--   1. Crea un GameObject vacio y ponle este script.
--   2. El mismo GO (o uno hijo) debe tener un Box Collider marcado como trigger
--      con el tamano y posicion de la zona deseada.
--   3. El GameObject con ComponentPostProcessing debe llamarse "Camera" (o cambia ppGoName).
--   4. El GameObject del player debe tener el tag "Player" (o cambia playerTag).

FogTrigger = {}
FogTrigger.__index = FogTrigger

function FogTrigger:Start()
    -- Configuracion
    self.playerTag  = "Player"
    self.ppGoName   = "MainCamera"          -- GO que tiene el ComponentPostProcessing
    self.lerpSpeed  = 2.0               -- velocidad de transicion (unidades/s)

    -- Niebla FUERA del trigger (estado inicial)
    self.fogOut = {
        enabled     = false,
        density     = 0.01,
        colorR      = 0.7, colorG = 0.8, colorB = 0.9,
        fogStart    = 10.0,
        fogEnd      = 100.0,
    }

    -- Niebla DENTRO del trigger
    self.fogIn = {
        enabled     = true,
        density     = 0.06,
        colorR      = 0.2, colorG = 0.25, colorB = 0.3,
        fogStart    = 5.0,
        fogEnd      = 40.0,
    }

    -- Referencias
    self.ppGo = GameObject.Find(self.ppGoName)
    if not self.ppGo then
        Engine.Log("[FogTrigger] ERROR: No se encontro el GO '" .. self.ppGoName .. "'")
        return
    end
    self.pp = self.ppGo:GetComponent("PostProcessing")
    if not self.pp then
        Engine.Log("[FogTrigger] ERROR: El GO '" .. self.ppGoName .. "' no tiene PostProcessing")
        return
    end

    -- Collider trigger de este mismo GO
    self.col = self.gameObject:GetComponent("Box Collider")
    if not self.col then
        Engine.Log("[FogTrigger] ERROR: No hay Box Collider en este GameObject")
        return
    end

    -- Estado interno
    self.playerInside  = false
    self.currentT      = 0.0   -- 0 = fogOut, 1 = fogIn

    -- Aplica estado inicial sin transicion
    self:ApplyFog(0.0)
    Engine.Log("[FogTrigger] Inicializado correctamente")
end

-- Comprueba si el player esta dentro del AABB del trigger.
-- Como el motor no expone IsOverlapping en Lua, lo hacemos manualmente
-- comparando la posicion del player con el transform + escala del trigger GO.
function FogTrigger:IsPlayerInsideTrigger()
    local players = GameObject.FindByTag(self.playerTag)
    if not players or #players == 0 then return false end

    local player = players[1]
    local pt = player.transform
    local px, py, pz = pt:GetPosition()

    -- Centro del trigger
    local tt = self.gameObject.transform
    local tx, ty, tz = tt:GetPosition()

    -- Mitad del tamano: usa la escala del GO como aproximacion del box size.
    -- Si necesitas mas precision, guarda el half-extent en Start y ajustalo manualmente.
    local sx, sy, sz = tt:GetScale()
    local hx = math.abs(sx) * 0.5
    local hy = math.abs(sy) * 0.5
    local hz = math.abs(sz) * 0.5

    return  px >= (tx - hx) and px <= (tx + hx)
        and py >= (ty - hy) and py <= (ty + hy)
        and pz >= (tz - hz) and pz <= (tz + hz)
end

-- Interpola y aplica los parametros de niebla al PostProcessing.
-- t = 0 -> fogOut,  t = 1 -> fogIn
function FogTrigger:ApplyFog(t)
    local function lerp(a, b, f) return a + (b - a) * f end

    local o = self.fogOut
    local i = self.fogIn

    -- Enabled: activa la niebla en cuanto empieza la transicion de entrada
    local fogEnabled = (t > 0.0)
    self.pp:SetFogEnabled(fogEnabled)

    self.pp:SetFogDensity (lerp(o.density,  i.density,  t))
    self.pp:SetFogColor   (lerp(o.colorR,   i.colorR,   t),
                           lerp(o.colorG,   i.colorG,   t),
                           lerp(o.colorB,   i.colorB,   t))
    self.pp:SetFogStart   (lerp(o.fogStart, i.fogStart, t))
    self.pp:SetFogEnd     (lerp(o.fogEnd,   i.fogEnd,   t))
end

function FogTrigger:Update()
    if not self.pp then return end

    local dt = Time.GetDeltaTime()
    local inside = self:IsPlayerInsideTrigger()

    -- Detecta eventos de entrada/salida (solo para log)
    if inside and not self.playerInside then
        Engine.Log("[FogTrigger] Player ENTRO en la zona de niebla")
        self.playerInside = true
    elseif not inside and self.playerInside then
        Engine.Log("[FogTrigger] Player SALIO de la zona de niebla")
        self.playerInside = false
    end

    -- Avanza la interpolacion hacia el objetivo
    local target = inside and 1.0 or 0.0
    self.currentT = self.currentT + (target - self.currentT) * math.min(self.lerpSpeed * dt, 1.0)

    -- Clamp para evitar drift flotante
    if math.abs(self.currentT - target) < 0.001 then
        self.currentT = target
    end

    self:ApplyFog(self.currentT)
end