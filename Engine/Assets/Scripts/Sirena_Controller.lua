local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

-- ── Gravity (ajustar para que coincida con el Rigidbody del motor) ────────
local GRAVITY = 14.0   -- unidades/s²

-- ── States ────────────────────────────────────────────────────────────────
local State = {
    IDLE     = "Idle",
    WINDUP   = "WindUp",   -- telegrafía el disparo antes de lanzar
    COOLDOWN = "Cooldown",
    DEAD     = "Dead",
}

-- ── Estado interno ────────────────────────────────────────────────────────
local Mortar = {
    currentState = nil,
    rb           = nil,
    anim         = nil,
    playerGO     = nil,
    currentY     = 0,    -- ángulo Y actual (para rotación suave hacia el player)
    targetY      = 0,    -- ángulo Y deseado
}

-- ── Variables de vida y daño ──────────────────────────────────────────────
local isDead         = false
local pendingDestroy = false
local alreadyHit     = false
local hp

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

_EnemyDamage_mortar = 30   -- global: el player puede leer esto si hace falta

-- ── Timers internos ───────────────────────────────────────────────────────
local windUpTimer   = 0
local cooldownTimer = 0

-- ── Tabla de proyectiles en vuelo ─────────────────────────────────────────
-- Cada entrada:
--   go         : GameObject del proyectil (puede ser nil los primeros frames)
--   age        : segundos desde el disparo
--   flightTime : tiempo total de vuelo calculado
--   sx,sy,sz   : posición de lanzamiento
--   vx,vy,vz   : velocidad inicial
--   targetX,targetZ : posición de impacto prevista
--   hasHit     : ya se procesó el impacto
local activeShells = {}

-- ── Public (modificable desde el inspector) ───────────────────────────────
public = {
    maxHp            = 50,
    knockbackForce   = 3.0,

    detectRange      = 22.0,   -- distancia máxima para disparar
    minRange         = 5.0,    -- punto ciego: si el player está muy cerca no dispara

    windUpTime       = 1.6,    -- segundos de telegrafía antes del disparo
    flightTime       = 2.0,    -- duración del arco en el aire
    cooldownTime     = 4.5,    -- espera entre disparos

    blastRadius      = 3.5,    -- radio de daño en el impacto
    attackDamage     = 30,     -- daño máximo (en el centro de la explosión)

    barrelOffsetY    = 1.8,    -- altura del punto de disparo sobre el pivot
    rotationSpeed    = 6.0,    -- velocidad de giro para encarar al player

    projectilePrefab = "Sirena_Bullet",  -- nombre del prefab del proyectil
    maxLifetime = MAX_LIFETIME,
}
local finalPath  = Engine.GetAssetsPath() .. "/Prefabs/Sirena_Bullet.prefab"

-- ── Helpers ───────────────────────────────────────────────────────────────
local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

-- Calcula la velocidad inicial para un arco parabólico dado origen, destino y tiempo de vuelo.
-- Ecuaciones cinemáticas:
--   x(t) = sx + vx·t          →  vx = dx / T
--   z(t) = sz + vz·t          →  vz = dz / T
--   y(t) = sy + vy·t - ½g·t²  →  vy = (dy + ½g·T²) / T
local function ComputeLaunchVelocity(sx, sy, sz, tx, ty, tz)
    local dx = tx - sx
    local dz = tz - sz
    local dy = ty - sy
    local distXZ = sqrt(dx*dx + dz*dz)

    -- SEGURIDAD: Distancia mínima para evitar errores matemáticos
    if distXZ < 0.5 then distXZ = 0.5 end

    local h = distXZ * 0.5
    if h < 2.0 then h = 2.0 end
    if dy >= h then h = dy + 1.0 end 

    local vY = sqrt(2 * GRAVITY * h)

    local termBazada = 2 * (h - dy) / GRAVITY
    if termBazada < 0 then termBazada = 0 end
    local T = (vY / GRAVITY) + sqrt(termBazada)

    local vX = dx / T
    local vZ = dz / T

    return vX, vY, vZ, T
end

-- ── TakeDamage ────────────────────────────────────────────────────────────
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    hp = hp - amount
    Engine.Log("[Mortar] HP: " .. hp .. "/" .. self.public.maxHp)

    _PlayerController_triggerCameraShake = true

    -- Knockback
    if Mortar.rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx * dx + dz * dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        Mortar.rb:AddForce(dx * self.public.knockbackForce, 0,
                           dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 then
        isDead              = true
        pendingDestroy      = true
        Mortar.currentState = State.DEAD

        -- Ralentización de impacto
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07

        -- Destruir todos los proyectiles en vuelo
        for _, shell in ipairs(activeShells) do
            SafeDestroyShell(shell)
        end
        activeShells = {}

        Engine.Log("[Mortar] DEAD")
    end
end

-- ── FacePlayer: gira suavemente hacia la posición del player ─────────────
local function FacePlayer(self, playerPos, dt)
    local myPos = self.transform.position
    local dx    = playerPos.x - myPos.x
    local dz    = playerPos.z - myPos.z
    Mortar.targetY = atan2(dx, dz) * (180.0 / pi)

    local diff = shortAngleDiff(Mortar.currentY, Mortar.targetY)
    Mortar.currentY = Mortar.currentY + diff * self.public.rotationSpeed * dt
    self.transform:SetRotation(0, Mortar.currentY, 0)
end

-- ── FireShell: lanza un proyectil parabólico hacia la posición dada ───────
local function FireShell(self, tx, ty, tz)
    local myPos = self.transform.worldPosition
    local sx    = myPos.x
    local sy    = myPos.y + self.public.barrelOffsetY
    local sz    = myPos.z

    local vx, vy, vz, T = ComputeLaunchVelocity(sx, sy, sz, tx, ty + 0.3, tz)

    local bulletAsset = Prefab.Load("Sirena_Bullet", finalPath)
    if bulletAsset then
        local shell = Prefab.Instantiate("Sirena_Bullet")

        table.insert(activeShells, {
            go         = shell,
            age        = 0,
            flightTime = T,
            sx = sx, sy = sy, sz = sz,
            vx = vx, vy = vy, vz = vz,
            targetX    = tx,
            targetZ    = tz,
            hasHit     = false,
        })
        
        Engine.Log("[Mortar] FIRE! Dist=" .. string.format("%.1f", sqrt((tx-sx)^2+(tz-sz)^2)) .. " T=" .. string.format("%.2f", T))
    else
        Engine.Log("[Mortar] Error al cargar el proyectil.")
    end
end

-- ── SafeMoveShell: mueve el GO del proyectil con protección ante userdata inválido ──
local function SafeMoveShell(s, x, y, z, t)
    if not s.go then return end
    if s.goInvalid then return end  -- ya sabemos que falló, no reintentar

    local ok, err = pcall(function()
        local tr = s.go.transform
        if not tr then return end
        tr:SetPosition(x, y, z)

        local speedX  = s.vx
        local speedY  = s.vy - GRAVITY * t
        local speedZ  = s.vz
        local heading = atan2(speedX, speedZ) * (180.0 / pi)
        local pitch   = -atan2(speedY, sqrt(speedX * speedX + speedZ * speedZ))
                        * (180.0 / pi)
        tr:SetRotation(pitch, heading, 0)
    end)

    if not ok then
        -- El userdata existe pero el puntero interno es null (instanciación fallida)
        s.goInvalid = true
        s.go        = nil
    end
end

-- ── SafeDestroyShell: destruye el GO con protección ──────────────────────
local function SafeDestroyShell(s)
    if not s.go or s.goInvalid then return end
    pcall(function() GameObject.Destroy(s.go) end)
    s.go = nil
end

-- ── UpdateShells: simula el arco parabólico y gestiona los impactos ───────
local function UpdateShells(self, dt)
    if #activeShells == 0 then return end

    for i = #activeShells, 1, -1 do
        local s = activeShells[i]
        s.age = s.age + dt

        -- Posición en el tiempo t mediante cinemática
        local t = s.age
        local x = s.sx + s.vx * t
        local y = s.sy + s.vy * t - 0.5 * GRAVITY * t * t
        local z = s.sz + s.vz * t

        -- Mover el visual del proyectil (falla silenciosamente si el GO es inválido)
        SafeMoveShell(s, x, y, z, t)

        -- ── Detección de impacto ──────────────────────────────────────────
        local impacted = (s.age >= s.flightTime) or (y < -50.0)

        if impacted and not s.hasHit then
            s.hasHit = true

            Engine.Log("[Mortar] Impact at ("
                     .. string.format("%.1f", x) .. ", "
                     .. string.format("%.1f", z) .. ")")

            -- Daño en área al player
            if Mortar.playerGO then
                local pp = Mortar.playerGO.transform.position
                if pp then
                    local impDx   = pp.x - s.targetX
                    local impDz   = pp.z - s.targetZ
                    local impDist = sqrt(impDx * impDx + impDz * impDz)

                    if impDist <= self.public.blastRadius then
                        local factor = 1.0 - (impDist / self.public.blastRadius) * 0.5
                        local dmg    = math.max(math.floor(self.public.attackDamage * factor), 1)

                        if _PlayerController_pendingDamage == 0 then
                            _PlayerController_pendingDamage    = dmg
                            _PlayerController_pendingDamagePos = { x = x, y = y, z = z }
                            Engine.Log("[Mortar] HIT PLAYER for " .. dmg
                                     .. " (dist=" .. string.format("%.2f", impDist) .. ")")
                        end
                    end
                end
            end

            SafeDestroyShell(s)
            table.remove(activeShells, i)
        end
    end
end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    Game.SetTimeScale(1.0)

    hp             = self.public.maxHp
    isDead         = false
    alreadyHit     = false
    pendingDestroy = false

    Mortar.currentState = State.IDLE
    Mortar.currentY     = 0
    Mortar.targetY      = 0
    Mortar.playerGO     = nil
    Mortar.rb           = self.gameObject:GetComponent("Rigidbody")
    Mortar.anim         = self.gameObject:GetComponent("Animation")

    windUpTimer   = 0
    cooldownTimer = 0
    activeShells  = {}

    Prefab.Load("Sirena_Bullet", finalPath)
    -- Bloqueamos el Rigidbody para que el mortero no se mueva
    if Mortar.rb then
        Mortar.rb:SetLinearVelocity(0, 0, 0)
    end

    Engine.Log("[Mortar] Initialized. HP=" .. hp
             .. " detectRange=" .. self.public.detectRange)
end

-- ── Update ────────────────────────────────────────────────────────────────
function Update(self, dt)
    if not self.gameObject then return end

    -- Debug: suicidio con tecla 0
    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        return
    end

    if isDead then
        if pendingDestroy then
            self:Destroy()
            pendingDestroy = false
        end
        return
    end

    -- Simular proyectiles en vuelo independientemente del estado del mortero
    UpdateShells(self, dt)

    -- Reintentar componentes si faltan
    if not Mortar.rb then
        Mortar.rb = self.gameObject:GetComponent("Rigidbody")
    end

    -- Mantener el mortero quieto (sin navegación, solo anclamos velocidad)
    if Mortar.rb then
        local vel = Mortar.rb:GetLinearVelocity()
        if vel then
            Mortar.rb:SetLinearVelocity(0, vel.y, 0)
        end
    end

    -- Buscar player
    if not Mortar.playerGO then
        Mortar.playerGO = GameObject.Find("Player")
        if Mortar.playerGO then
            Engine.Log("[Mortar] Player encontrado")
        end
    end

    if not Mortar.playerGO then return end

    local myPos = self.transform.position
    local pp    = Mortar.playerGO.transform.position
    if not pp then return end

    local distX = pp.x - myPos.x
    local distZ = pp.z - myPos.z
    local dist  = sqrt(distX * distX + distZ * distZ)

    -- ── Máquina de estados ────────────────────────────────────────────────

    if Mortar.currentState == State.IDLE then
        -- Espera a que el player entre en rango
        if dist <= self.public.detectRange and dist >= self.public.minRange then
            Mortar.currentState = State.WINDUP
            windUpTimer         = 0
            Engine.Log("[Mortar] Player detectado a dist=" ..
                       string.format("%.1f", dist) .. ". Wind-up...")
        end

    elseif Mortar.currentState == State.WINDUP then
        -- Gira hacia el player mientras se telegrafía el disparo
        FacePlayer(self, pp, dt)
        windUpTimer = windUpTimer + dt

        -- Si el player sale de rango durante el wind-up, abortamos
        if dist > self.public.detectRange or dist < self.public.minRange then
            Mortar.currentState = State.COOLDOWN
            cooldownTimer       = self.public.cooldownTime * 0.4
            Engine.Log("[Mortar] Player fuera de rango. Abortando disparo.")
            return
        end

        -- Animar (si hay animación de wind-up disponible)
        if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Charge") then
            Mortar.anim:Play("Charge")
        end

        if windUpTimer >= self.public.windUpTime then
            -- Snapshot de la posición del player en el momento del disparo
            FireShell(self, pp.x, pp.y, pp.z)

            if Mortar.anim then Mortar.anim:Play("Fire") end

            Mortar.currentState = State.COOLDOWN
            cooldownTimer       = self.public.cooldownTime
            Engine.Log("[Mortar] FIRED! Cooldown=" .. self.public.cooldownTime .. "s")
        end

    elseif Mortar.currentState == State.COOLDOWN then
        cooldownTimer = cooldownTimer - dt

        if cooldownTimer <= 0 then
            -- Si el player sigue en rango, volvemos a wind-up directamente
            if dist <= self.public.detectRange and dist >= self.public.minRange then
                Mortar.currentState = State.WINDUP
                windUpTimer         = 0
                Engine.Log("[Mortar] Cooldown listo. Nuevo wind-up.")
            else
                Mortar.currentState = State.IDLE
                Engine.Log("[Mortar] Cooldown listo. Volviendo a IDLE.")
            end
        end
    end

    -- Seguridad: procesar destrucción pendiente al final del frame
    if pendingDestroy then
        self:Destroy()
        pendingDestroy = false
    end
end

-- ── OnTriggerEnter: el mortero puede recibir golpes del player ────────────
function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end
    end
end

-- ── OnTriggerExit ─────────────────────────────────────────────────────────
function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end