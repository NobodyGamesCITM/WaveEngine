-- ============================================================
--  EnemySkeletonController.lua  –  Primer enemigo del juego
--
--  Estado simplificado, pensado para ser aprendible:
--
--    IDLE ──► PATROL ──► CHASE ──► ORBIT ──► ANTICIPATE ──► ATTACK
--               ▲           ▲        │                         │
--               │           └────────┘  (jugador escapa)       │
--               └──────────────────────────────────────────────┘
--                              (cooldown → ORBIT si sigue cerca, si no CHASE)
--
--  El DODGE existe como interrupción desde CHASE/ORBIT/ANTICIPATE,
--  pero con baja probabilidad y cooldown largo: el jugador puede
--  aprender cuándo ocurre sin sentirlo injusto.
--
--  Movimiento: siempre por física (rb). NavMesh solo en CHASE/PATROL.
--  En ORBIT y DODGE el agente navmesh está parado; el rigidbody
--  gestiona las colisiones con paredes de forma natural.
-- ============================================================

-- ── stdlib aliases ────────────────────────────────────────────────────────
local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

-- ── Audio source GameObjects (filled in Start) ────────────────────────────
local attackSource = nil
local dieSource    = nil
local hurtSource   = nil
local dodgeSource  = nil
local stepsSource  = nil

-- ── States ────────────────────────────────────────────────────────────────
local State = {
    IDLE       = "Idle",
    PATROL     = "Patrol",
    CHASE      = "Chase",
    ORBIT      = "Orbit",      -- strafe alrededor del jugador antes de atacar
    DODGE      = "Dodge",      -- esquive lateral reactivo
    ANTICIPATE = "Anticipate", -- telegrafía el ataque (el jugador puede esquivar)
    ATTACK     = "Attack",
    DEAD       = "Dead",
}

-- ── Global interop ────────────────────────────────────────────────────────
_EnemyDamage_skeleton = 20

-- ── Parámetros públicos ───────────────────────────────────────────────────
public = {
    maxHp           = 30,

    -- Movimiento
    patrolSpeed     = 1.5,
    chaseSpeed      = 3.5,
    lungeForce      = 11.0,
    moveAccel       = 18.0,
    brakeDecel      = 14.0,
    rotationSpeed   = 4.0,

    -- NavMesh
    navRefreshRate  = 0.18,

    -- Detección
    aggroRadius     = 8.0,
    deaggroRadius   = 14.0,
    attackRange     = 2.0,

    -- Patrulla
    patrolWaitMin   = 1.0,
    patrolWaitMax   = 2.8,

    -- ── ORBIT ─────────────────────────────────────────────────────────────
    -- El esqueleto entra en órbita cuando está cerca del jugador.
    -- Da vueltas a su alrededor durante un tiempo aleatorio y luego
    -- entra en ANTICIPATE. El jugador puede anticipar el ataque viendo
    -- cuándo termina el strafe.
    orbitTriggerDist  = 5.0,
    orbitRadius       = 3.2,   -- distancia que intenta mantener al orbitar
    orbitSpeed        = 2.2,   -- velocidad de strafe
    orbitCorrSpeed    = 5.0,   -- fuerza del resorte radial
    orbitCorrMaxFrac  = 0.6,
    orbitDurMin       = 1.2,   -- tiempo mínimo de órbita antes de atacar
    orbitDurMax       = 2.5,
    orbitDirFlipMin   = 0.8,   -- el esqueleto puede cambiar de dirección...
    orbitDirFlipMax   = 1.8,   -- ...para no ser predecible en exceso
    orbitDirFlipChance= 0.35,

    -- ── DODGE ─────────────────────────────────────────────────────────────
    -- Baja probabilidad y cooldown largo: el jugador lo verá pocas veces
    -- y podrá entender cuándo sucede (jugador corriendo directo al enemigo).
    dodgeChance         = 0.10,   -- 10 % de éxito cuando se cumplen condiciones
    dodgeApproachThresh = 10.0,   -- velocidad de aproximación mínima para activar
    dodgeThreatDist     = 4.5,    -- distancia máxima para que el dodge sea válido
    dodgeImpulse        = 10.0,
    dodgeSideRatio      = 0.80,   -- mayoría del impulso es lateral
    dodgeDur            = 0.28,
    dodgeCooldown       = 4.0,    -- espera larga entre esquives: aprendible
    dodgeInvincible     = false,
    animDodge           = "Roll",

    -- ── Ataque ────────────────────────────────────────────────────────────
    -- anticipateDur largo (0.75 s) para que el jugador pueda reaccionar.
    -- Es el primer enemigo: el telegrafío tiene que ser claro.
    anticipateDur   = 0.75,
    attackDur       = 0.45,
    attackColDelay  = 0.18,
    lungeStopDelay  = 0.30,
    cooldown        = 3.0,     -- cooldown fijo (sin rage mode en el primer enemigo)
    attackDamage    = 20,
    knockbackForce  = 6.0,
    stunDuration    = 0.80,
    hitReactDelay   = 0.15,

    -- Anims
    animIdle        = "Idle",
    animWalk        = "Walk",
    animAnticipate  = "Anticipate",
    animAttack      = "Attack",
    animHit         = "Hit",
    animDeath       = "Death",
}

-- ── Estado de ejecución ───────────────────────────────────────────────────
local currentState = State.IDLE
local hp           = 0

local isDead       = false
local pendingDeath = false

local isStunned    = false
local stunTimer    = 0

local patrolWait   = 0

local isAttacking         = false
local attackTimer         = 0
local isOnCooldown        = false
local cooldownTimer       = 0
local playerHitThisAttack = false

local anticipateTimer = 0
local lungeStopTimer  = 0

-- ── ORBIT runtime ─────────────────────────────────────────────────────────
local orbitDir      = 1
local orbitTimer    = 0
local orbitDur      = 0
local orbitDirTimer = 0

-- ── DODGE runtime ─────────────────────────────────────────────────────────
local dodgeTimer       = 0
local dodgeCoolTimer   = 0
local dodgeVelX        = 0
local dodgeVelZ        = 0
local stateBeforeDodge = nil
local playerApproachSpd = 0   -- velocidad de aproximación del jugador (suavizada)
local playerPrevX      = 0
local playerPrevZ      = 0

-- ── NavMesh ───────────────────────────────────────────────────────────────
local navRefreshTimer = 0

-- ── Hit detection ─────────────────────────────────────────────────────────
local playerAttackHandled = false
local alreadyHit          = false

-- ── Cola de daño retardado ────────────────────────────────────────────────
local pendingPlayerDmg    = 0
local pendingPlayerDmgPos = nil
local hitReactTimer       = 0

-- ── Componentes ───────────────────────────────────────────────────────────
local nav       = nil
local rb        = nil
local anim      = nil
local attackCol = nil
local playerGO  = nil

local targetVelX = 0
local targetVelZ = 0
local currentYaw = 0

local Enemy = { attackSFX=nil, dieSFX=nil, hurtSFX=nil,  dodgeSFX=nil, stepSFX=nil }

local stepTimer = 0
-- ─────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────────────

local function DistFlat(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return sqrt(dx*dx + dz*dz)
end

local function NormFlat(dx, dz)
    local len = sqrt(dx*dx + dz*dz)
    if len < 0.001 then return 0, 0 end
    return dx/len, dz/len
end

local function PlayerFacingEnemy(playerPos, playerYawDeg, enemyPos, dotThresh)
    local yawRad = playerYawDeg * (pi / 180)
    local fwdX   = math.sin(yawRad)
    local fwdZ   = math.cos(yawRad)
    local dx, dz = NormFlat(enemyPos.x - playerPos.x, enemyPos.z - playerPos.z)
    return (fwdX * dx + fwdZ * dz) >= dotThresh
end

local function Lerp(a, b, t)  return a + (b-a)*t  end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Física: velocidad objetivo y aplicación por interpolación
local function SetTargetVelocity(dx, dz, speed)
    targetVelX = dx * speed
    targetVelZ = dz * speed
end

local function ApplyMoveVelocity(dt, accelRate)
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(Lerp(vel.x, targetVelX, dt * accelRate),
                         vel.y,
                         Lerp(vel.z, targetVelZ, dt * accelRate))
end

local function RequestBrakeXZ(self)
    targetVelX = 0;  targetVelZ = 0;  _ = self
end

local function HardBrakeXZ()
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y or 0, 0)
    targetVelX = 0;  targetVelZ = 0
end

local function FaceTargetSmooth(self, target, dt)
    local p  = self.transform.worldPosition
    local dx = target.x - p.x
    local dz = target.z - p.z
    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end

    local desiredYaw = atan2(dx, dz) * (180 / pi)
    local delta      = desiredYaw - currentYaw
    delta = delta - math.floor((delta + 180) / 360) * 360

    local turn = Clamp(delta,
        -self.public.rotationSpeed * dt * 60,
         self.public.rotationSpeed * dt * 60)
    currentYaw = currentYaw + turn
    rb:SetRotation(0, currentYaw, 0)
end

local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

-- ─────────────────────────────────────────────────────────────────────────
-- TAKEDAMAGE
-- ─────────────────────────────────────────────────────────────────────────

local function QueuePlayerDamage(self, amount, attackerPos)
    pendingPlayerDmg    = amount
    pendingPlayerDmgPos = attackerPos
    hitReactTimer       = self.public.hitReactDelay
    Engine.Log("[Skeleton] Daño en cola: " .. amount)
end

local function TakeDamage(self, amount, attackerPos)
    if isDead or not hp then return end

    hp = hp - amount
    Engine.Log("[Skeleton] HP: " .. hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if rb and attackerPos then
        local ep     = self.transform.worldPosition
        local dx, dz = NormFlat(ep.x - attackerPos.x, ep.z - attackerPos.z)
        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 and not pendingDeath then
        if Enemy.dieSFX then Enemy.dieSFX:PlayAudioEvent() end
        pendingDeath = true
    else
        isStunned           = true
        stunTimer           = self.public.stunDuration
        isAttacking         = false
        playerHitThisAttack = false
        anticipateTimer     = 0
        lungeStopTimer      = 0
        orbitTimer          = 0

        if attackCol then attackCol:Disable() end
        if nav       then nav:StopMovement()  end
        HardBrakeXZ()
        if Enemy.hurtSFX then Enemy.hurtSFX:PlayAudioEvent() end
        PlayAnim(self.public.animHit, 0.05)
        Engine.Log("[Skeleton] STUN " .. self.public.stunDuration .. "s")
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- ESTADOS
-- ─────────────────────────────────────────────────────────────────────────

local function UpdateIdle(self, dt)
    RequestBrakeXZ(self)
    ApplyMoveVelocity(dt, self.public.brakeDecel)

    patrolWait = patrolWait - dt
    if patrolWait > 0 then return end

    local px, py, pz = nav:GetRandomPoint()
    if px then
        nav:SetDestination(px, py, pz)
        PlayAnim(self.public.animWalk, 0.2)
        currentState = State.PATROL
    else
        patrolWait = self.public.patrolWaitMin
    end
end

local function UpdatePatrol(self, dt)
    if not nav:IsMoving() then
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)
        PlayAnim(self.public.animIdle, 0.2)
        patrolWait   = self.public.patrolWaitMin
            + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)
        currentState = State.IDLE
        return
    end

    local dx, dz = nav:GetMoveDirection(0.3)
    SetTargetVelocity(dx, dz, self.public.patrolSpeed)
    ApplyMoveVelocity(dt, self.public.moveAccel)
    if abs(dx) > 0.001 or abs(dz) > 0.001 then
        local p = self.transform.worldPosition
        FaceTargetSmooth(self, {x=p.x+dx, y=p.y, z=p.z+dz}, dt)
    end
end

local function UpdateChase(self, dt)
    if not playerGO then currentState = State.IDLE; return end

    local myPos = self.transform.worldPosition
    local plPos = playerGO.transform.worldPosition
    local dist  = DistFlat(myPos, plPos)

    -- Pierde el agro si el jugador se aleja demasiado
    if dist > self.public.deaggroRadius then
        nav:StopMovement(); RequestBrakeXZ(self)
        PlayAnim(self.public.animIdle, 0.3)
        currentState = State.IDLE
        Engine.Log("[Skeleton] CHASE → IDLE (deaggro)")
        return
    end

    -- Entra en órbita cuando está suficientemente cerca
    if dist <= self.public.orbitTriggerDist and not isOnCooldown then
        nav:StopMovement()
        orbitDir      = (math.random() < 0.5) and 1 or -1
        orbitTimer    = 0
        orbitDur      = self.public.orbitDurMin
            + math.random() * (self.public.orbitDurMax - self.public.orbitDurMin)
        orbitDirTimer = self.public.orbitDirFlipMin
            + math.random() * (self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
        PlayAnim(self.public.animWalk, 0.2)
        currentState = State.ORBIT
        Engine.Log("[Skeleton] CHASE → ORBIT")
        return
    end

    -- Navmesh: recalcula ruta al jugador periódicamente
    navRefreshTimer = navRefreshTimer - dt
    if navRefreshTimer <= 0 then
        nav:SetDestination(plPos.x, plPos.y, plPos.z)
        navRefreshTimer = self.public.navRefreshRate
    end

    local dx, dz = nav:GetMoveDirection(0.3)
    SetTargetVelocity(dx, dz, self.public.chaseSpeed)
    ApplyMoveVelocity(dt, self.public.moveAccel)
    FaceTargetSmooth(self, plPos, dt)
end

-- ── ORBIT ─────────────────────────────────────────────────────────────────
--
-- El esqueleto rodea al jugador en círculo a distancia fija (orbitRadius),
-- usando solo física. El navmesh está parado: las paredes se gestionan
-- mediante colisiones del rigidbody.
--
-- Después de orbitDur segundos, entra en ANTICIPATE y ataca.
-- Ocasionalmente cambia de dirección para no ser completamente predecible.
--
local function UpdateOrbit(self, dt)
    if not playerGO then currentState = State.IDLE; return end

    local myPos = self.transform.worldPosition
    local plPos = playerGO.transform.worldPosition
    local dist  = DistFlat(myPos, plPos)

    -- Siempre mira al jugador
    FaceTargetSmooth(self, plPos, dt)

    -- Sale del agro si el jugador se aleja mucho
    if dist > self.public.deaggroRadius then
        RequestBrakeXZ(self)
        PlayAnim(self.public.animIdle, 0.3)
        currentState = State.IDLE
        Engine.Log("[Skeleton] ORBIT → IDLE (deaggro)")
        return
    end

    -- Si el jugador escapó, vuelve a perseguir con navmesh
    if dist > self.public.orbitTriggerDist * 1.6 then
        navRefreshTimer = 0
        PlayAnim(self.public.animWalk, 0.2)
        currentState = State.CHASE
        Engine.Log("[Skeleton] ORBIT → CHASE (jugador escapó)")
        return
    end

    -- Cuando el timer de órbita expira, ataca
    if orbitTimer >= orbitDur then
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)
        anticipateTimer = 0
        PlayAnim(self.public.animAnticipate, 0.05)
        currentState = State.ANTICIPATE
        Engine.Log("[Skeleton] ORBIT → ANTICIPATE")
        return
    end

    -- Cambio de dirección ocasional
    orbitDirTimer = orbitDirTimer - dt
    if orbitDirTimer <= 0 then
        if math.random() < self.public.orbitDirFlipChance then
            orbitDir = -orbitDir
        end
        orbitDirTimer = self.public.orbitDirFlipMin
            + math.random() * (self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
    end

    -- ── Composición de velocidad (pura física) ─────────────────────────────
    -- Vector radial: del jugador al enemigo (dirección "alejarse del jugador")
    local rdx, rdz = NormFlat(myPos.x - plPos.x, myPos.z - plPos.z)

    -- Vector tangencial: perpendicular al radial (dirección de strafe)
    local tdx, tdz
    if orbitDir > 0 then tdx, tdz = -rdz,  rdx
    else                  tdx, tdz =  rdz, -rdx  end

    -- Resorte radial: corrige la distancia al radio deseado
    local error   = dist - self.public.orbitRadius
    local corrMax = self.public.orbitSpeed * self.public.orbitCorrMaxFrac
    local corrVel = Clamp(-error * self.public.orbitCorrSpeed, -corrMax, corrMax)

    -- Pulso sinusoidal suave: da naturalidad al movimiento de aproximación/alejamiento
    local pulse = math.sin(orbitTimer * 5.0) * self.public.orbitSpeed * 0.3

    local radialTotal = corrVel + pulse
    local blendX      = tdx * self.public.orbitSpeed + rdx * radialTotal
    local blendZ      = tdz * self.public.orbitSpeed + rdz * radialTotal

    -- Renormaliza a orbitSpeed para que la velocidad sea constante
    local bLen = sqrt(blendX * blendX + blendZ * blendZ)
    if bLen > 0.001 then
        blendX = (blendX / bLen) * self.public.orbitSpeed
        blendZ = (blendZ / bLen) * self.public.orbitSpeed
    end

    targetVelX = blendX
    targetVelZ = blendZ
    ApplyMoveVelocity(dt, self.public.moveAccel)

    orbitTimer = orbitTimer + dt
end

-- ── DODGE ─────────────────────────────────────────────────────────────────
--
-- Movimiento lateral puro por física (navmesh parado).
-- El esqueleto sigue mirando al jugador para que parezca intencional.
-- Cooldown largo (4 s): en un combate normal el jugador lo verá 1-2 veces
-- y puede aprender a reconocerlo.
--
local function UpdateDodge(self, dt)
    dodgeTimer = dodgeTimer - dt

    targetVelX = dodgeVelX
    targetVelZ = dodgeVelZ
    ApplyMoveVelocity(dt, self.public.moveAccel * 2)

    if playerGO then
        FaceTargetSmooth(self, playerGO.transform.worldPosition, dt)
    end

    if dodgeTimer <= 0 then
        RequestBrakeXZ(self)
        dodgeCoolTimer = self.public.dodgeCooldown

        local resume = stateBeforeDodge or State.ORBIT
        if resume == State.ORBIT then
            orbitTimer = 0
            orbitDur   = self.public.orbitDurMin
                + math.random() * (self.public.orbitDurMax - self.public.orbitDurMin)
        elseif resume == State.CHASE then
            navRefreshTimer = 0
        end

        PlayAnim(self.public.animWalk, 0.15)
        currentState = resume
        Engine.Log("[Skeleton] DODGE → " .. resume)
    end
end

-- ── TryDodge ──────────────────────────────────────────────────────────────
-- Intento de esquive predictivo. Se evalúa antes del dispatch de estados.
-- Condiciones: jugador corriendo directo al esqueleto a alta velocidad,
--              dentro del rango de amenaza, y cooldown terminado.
-- Un 10 % de probabilidad garantiza que el jugador lo pueda ver pero
-- no se sienta como un muro de invulnerabilidad.
--
local function TryDodge(self, dt, playerPos, myPos)
    if dodgeCoolTimer > 0 then return false end
    if isDead or isStunned  then return false end

    -- Solo esquiva desde estos estados (no desde ATTACK ni ANTICIPATE tardío)
    if currentState ~= State.ORBIT
    and currentState ~= State.CHASE
    and currentState ~= State.ANTICIPATE then
        return false
    end

    local dist = DistFlat(myPos, playerPos)
    if dist > self.public.dodgeThreatDist then return false end

    if playerApproachSpd < self.public.dodgeApproachThresh then return false end

    if math.random() > self.public.dodgeChance then return false end

    -- ── Dirección del esquive ──────────────────────────────────────────────
    -- Eje lateral perpendicular al vector jugador→enemigo.
    -- Elegimos el lado hacia el que el jugador NO se mueve.
    local rdx, rdz = NormFlat(myPos.x - playerPos.x, myPos.z - playerPos.z)

    local latX1, latZ1 =  rdz, -rdx
    local latX2, latZ2 = -rdz,  rdx

    local pvX = playerPos.x - playerPrevX
    local pvZ = playerPos.z - playerPrevZ
    local dot1 = pvX * latX1 + pvZ * latZ1
    local dot2 = pvX * latX2 + pvZ * latZ2

    local lx, lz
    if dot1 <= dot2 then lx, lz = latX1, latZ1
    else                  lx, lz = latX2, latZ2  end

    -- Mezcla lateral + ligero retroceso
    local s  = self.public.dodgeSideRatio
    local bx = lx * s + (-rdx) * (1 - s)
    local bz = lz * s + (-rdz) * (1 - s)
    local bl = sqrt(bx * bx + bz * bz)
    if bl > 0.001 then bx = bx / bl; bz = bz / bl end

    dodgeVelX        = bx * self.public.dodgeImpulse
    dodgeVelZ        = bz * self.public.dodgeImpulse
    dodgeTimer       = self.public.dodgeDur
    stateBeforeDodge = currentState

    rb:AddForce(bx * self.public.dodgeImpulse * 0.5, 0,
                bz * self.public.dodgeImpulse * 0.5, 2)

    if nav then nav:StopMovement() end
    if Enemy.dodgeSFX then Enemy.dodgeSFX:PlayAudioEvent() end
    PlayAnim(self.public.animDodge, 0.05)
    currentState = State.DODGE
    Engine.Log("[Skeleton] DODGE (approachSpd=" .. string.format("%.1f", playerApproachSpd) .. ")")
    return true
end

-- ── ANTICIPATE ────────────────────────────────────────────────────────────
local function UpdateAnticipate(self, dt)
    anticipateTimer = anticipateTimer + dt
    RequestBrakeXZ(self)
    ApplyMoveVelocity(dt, self.public.brakeDecel)
    if nav      then nav:StopMovement() end
    if playerGO then FaceTargetSmooth(self, playerGO.transform.worldPosition, dt) end

    if anticipateTimer < self.public.anticipateDur then return end

    -- Ejecuta el ataque con lunge
    local myPos     = self.transform.worldPosition
    local plPos     = playerGO and playerGO.transform.worldPosition or myPos
    local ndx, ndz  = NormFlat(plPos.x - myPos.x, plPos.z - myPos.z)

    rb:AddForce(ndx * self.public.lungeForce, 0, ndz * self.public.lungeForce, 2)
    targetVelX = ndx * self.public.lungeForce * 0.5
    targetVelZ = ndz * self.public.lungeForce * 0.5

    if attackCol then attackCol:Disable() end
    playerHitThisAttack = false
    isAttacking         = true
    attackTimer         = 0
    lungeStopTimer      = self.public.lungeStopDelay

    if Enemy.attackSFX then Enemy.attackSFX:PlayAudioEvent() end
    PlayAnim(self.public.animAttack, 0.05)
    currentState = State.ATTACK
    Engine.Log("[Skeleton] ANTICIPATE → ATTACK (lunge)")
end

-- ── ATTACK ────────────────────────────────────────────────────────────────
local function UpdateAttack(self, dt)
    attackTimer    = attackTimer    + dt
    lungeStopTimer = lungeStopTimer - dt

    if lungeStopTimer <= 0 then
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)
    end

    -- Activa el collider de daño después de un pequeño delay
    if attackTimer >= self.public.attackColDelay and attackCol then
        attackCol:Enable()
    end

    -- Polling de hit por distancia (respaldo al trigger)
    if attackTimer >= self.public.attackColDelay and not playerHitThisAttack and playerGO then
        local pp = playerGO.transform.position
        local mp = self.transform.worldPosition
        if pp and DistFlat(pp, mp) <= self.public.attackRange then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisAttack                = true
                _PlayerController_pendingDamage    = _EnemyDamage_skeleton
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end

    if attackTimer >= self.public.attackDur then
        isAttacking         = false
        playerHitThisAttack = false
        if attackCol then attackCol:Disable() end
        attackTimer   = 0
        isOnCooldown  = true
        cooldownTimer = self.public.cooldown + math.random() * 0.8

        -- Si el jugador sigue cerca, vuelve a orbitar; si no, persigue
        local dist = playerGO and DistFlat(self.transform.worldPosition,
                                           playerGO.transform.worldPosition) or 999
        if dist <= self.public.orbitTriggerDist * 1.3 then
            orbitDir      = -orbitDir
            orbitTimer    = 0
            orbitDur      = self.public.orbitDurMin
                + math.random() * (self.public.orbitDurMax - self.public.orbitDurMin)
            orbitDirTimer = self.public.orbitDirFlipMin
                + math.random() * (self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
            PlayAnim(self.public.animWalk, 0.25)
            currentState = State.ORBIT
            Engine.Log("[Skeleton] ATTACK → ORBIT (jugador cerca)")
        else
            navRefreshTimer = 0
            PlayAnim(self.public.animWalk, 0.25)
            currentState = State.CHASE
            Engine.Log("[Skeleton] ATTACK → CHASE (cooldown " .. string.format("%.2f", cooldownTimer) .. "s)")
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- START
-- ─────────────────────────────────────────────────────────────────────────
function Start(self)
    Game.SetTimeScale(1.0)

    hp                  = self.public.maxHp
    isDead              = false
    pendingDeath        = false
    alreadyHit          = false
    playerAttackHandled = false
    pendingPlayerDmg    = 0
    pendingPlayerDmgPos = nil
    hitReactTimer       = 0
    isStunned           = false
    isAttacking         = false
    isOnCooldown        = false
    targetVelX          = 0
    targetVelZ          = 0
    navRefreshTimer     = 0
    orbitDir            = 1
    orbitTimer          = 0
    orbitDur            = 0
    orbitDirTimer       = 0
    playerPrevX         = 0
    playerPrevZ         = 0
    playerApproachSpd   = 0
    dodgeTimer          = 0
    dodgeCoolTimer      = 0
    dodgeVelX           = 0
    dodgeVelZ           = 0
    stateBeforeDodge    = nil
    anticipateTimer     = 0
    lungeStopTimer      = 0
    currentYaw          = (self.transform.worldRotation and self.transform.worldRotation.y) or 0
    currentState        = State.IDLE
    patrolWait          = self.public.patrolWaitMin
        + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)

    nav       = self.gameObject:GetComponent("Navigation")
    rb        = self.gameObject:GetComponent("Rigidbody")
    anim      = self.gameObject:GetComponent("Animation")
    attackCol = self.gameObject:GetComponent("Box Collider")

    attackSource = GameObject.Find("SK_KopisSource")
    hurtSource   = GameObject.Find("SK_HurtSource")
    dieSource    = GameObject.Find("SK_DieSource")
    dodgeSource  = GameObject.Find("SK_DodgeSource")
    stepsSource  = GameObject.Find("SK_StepsSource")
    if attackSource then Enemy.attackSFX = attackSource:GetComponent("Audio Source") end
    if dieSource    then Enemy.dieSFX    = dieSource:GetComponent("Audio Source")    end
    if hurtSource   then Enemy.hurtSFX   = hurtSource:GetComponent("Audio Source")   end
    if dodgeSource  then Enemy.dodgeSFX  = dodgeSource:GetComponent("Audio Source")   end
    if stepsSource  then Enemy.stepSFX  = stepsSource:GetComponent("Audio Source")   end

    ---Enemy.stepSFX = self.gameObject:GetComponent("Audio Source")

    PlayAnim(self.public.animIdle, 0.0)
    Engine.Log("[Skeleton] Start OK  HP=" .. hp)
end

-- ─────────────────────────────────────────────────────────────────────────
-- UPDATE
-- ─────────────────────────────────────────────────────────────────────────
function Update(self, dt)
    if isDead or not self.gameObject then return end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        return
    end

    -- Muerte diferida (permite que la animación arranque limpia)
    if pendingDeath then
        isAttacking = false;  isOnCooldown = false
        if nav then nav:StopMovement() end
        if rb  then HardBrakeXZ() end
        currentState = State.DEAD
        isDead       = true
        PlayAnim(self.public.animDeath, 0.05)
        Engine.Log("[Skeleton] MUERTO")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        Enemy.dieSFX:PlayAudioEvent()
        self:Destroy()
        return
    end

    -- Daño externo (vía tabla global)
    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
    end

    -- Flush del daño retardado del jugador
    if pendingPlayerDmg > 0 then
        hitReactTimer = hitReactTimer - dt
        if hitReactTimer <= 0 then
            local dmg = pendingPlayerDmg
            local pos = pendingPlayerDmgPos
            pendingPlayerDmg    = 0
            pendingPlayerDmgPos = nil

            -- Comprobación de orientación en el momento del impacto
            local applyDmg = true
            if playerGO then
                local pp    = playerGO.transform.worldPosition
                local myPos = self.transform.worldPosition
                local plYaw = playerGO.transform.worldRotation
                              and playerGO.transform.worldRotation.y or 0
                applyDmg = PlayerFacingEnemy(pp, plYaw, myPos, 0.0)
            end
            if applyDmg then
                TakeDamage(self, dmg, pos)
            end
        end
    end

    -- Stun
    if isStunned then
        stunTimer = stunTimer - dt
        HardBrakeXZ()
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Skeleton] Stun terminado")
        end
        return
    end

    -- Cooldown de ataque
    if isOnCooldown then
        cooldownTimer = cooldownTimer - dt
        if cooldownTimer <= 0 then
            isOnCooldown = false
        end
    end

    -- Cooldown de esquive (independiente del de ataque)
    if dodgeCoolTimer > 0 then
        dodgeCoolTimer = dodgeCoolTimer - dt
    end

    -- Lazy-init de componentes
    if not nav or not rb then
        nav = self.gameObject:GetComponent("Navigation")
        rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not playerGO then
        playerGO = GameObject.Find("Player")
    end

    -- ── Polling del ataque del jugador (Modo A) ───────────────────────────
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and playerGO and not isDead then
            local myPos = self.transform.worldPosition
            local pp    = playerGO.transform.position
            if pp then
                local dist = DistFlat(myPos, pp)
                if dist <= self.public.attackRange + 1.5 then
                    playerAttackHandled = true
                    local atk = _PlayerController_lastAttack
                    local dmg = 0
                    if     atk == "light"  then dmg = 10
                    elseif atk == "heavy" or atk == "charge" then dmg = 25
                    end
                    if dmg > 0 then QueuePlayerDamage(self, dmg, pp) end
                end
            end
        end
    else
        playerAttackHandled = false
        alreadyHit          = false
    end

    -- ── Estimación de velocidad de aproximación del jugador ───────────────
    if playerGO then
        local pp  = playerGO.transform.worldPosition
        local myP = self.transform.worldPosition
        local pvX = (pp.x - playerPrevX) / math.max(dt, 0.001)
        local pvZ = (pp.z - playerPrevZ) / math.max(dt, 0.001)
        local edx, edz = NormFlat(myP.x - pp.x, myP.z - pp.z)
        local rawApproach = pvX * edx + pvZ * edz
        playerApproachSpd = Lerp(playerApproachSpd, math.max(0, rawApproach), dt * 8.0)
        playerPrevX = pp.x
        playerPrevZ = pp.z

        -- Intento de esquive (antes del dispatch, puede interrumpir estados)
        if TryDodge(self, dt, pp, myP) then return end
    end

    -- ── Agro ──────────────────────────────────────────────────────────────
    if (currentState == State.IDLE or currentState == State.PATROL) and playerGO then
        local dist = DistFlat(self.transform.worldPosition, playerGO.transform.worldPosition)
        if dist <= self.public.aggroRadius then
            nav:StopMovement(); RequestBrakeXZ(self); navRefreshTimer = 0
            PlayAnim(self.public.animWalk, 0.2)
            currentState = State.CHASE
            Engine.Log("[Skeleton] AGRO")
        end
    end


    -- ── Sonido de pasos ───────────────────────────────────────────────────
    if currentState == State.PATROL or currentState == State.CHASE
      or currentState == State.ORBIT  or currentState == State.DODGE then
        stepTimer = stepTimer + dt
        if stepTimer >= 0.5 then
            stepTimer = 0
            Enemy.stepSFX:PlayAudioEvent()
        end
    else
        stepTimer = 0
        if Enemy.stepSFX then Enemy.stepSFX:StopAudioEvent() end
    end

    -- ── Dispatch de estados ───────────────────────────────────────────────
    if     currentState == State.IDLE       then UpdateIdle(self, dt)
    elseif currentState == State.PATROL     then UpdatePatrol(self, dt)
    elseif currentState == State.CHASE      then UpdateChase(self, dt)
    elseif currentState == State.ORBIT      then UpdateOrbit(self, dt)
    elseif currentState == State.DODGE      then UpdateDodge(self, dt)
    elseif currentState == State.ANTICIPATE then UpdateAnticipate(self, dt)
    elseif currentState == State.ATTACK     then UpdateAttack(self, dt)
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- TRIGGER EVENTS
-- ─────────────────────────────────────────────────────────────────────────

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        -- El jugador golpea al esqueleto
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= nil and attack ~= "" then
                local ap  = other.transform.worldPosition
                local dmg = 0
                if     attack == "light"  then dmg = 10
                elseif attack == "heavy" or attack == "charge" then dmg = 25
                end
                if dmg > 0 then
                    alreadyHit = true
                    QueuePlayerDamage(self, dmg, ap)
                end
            end
        end

        -- El esqueleto golpea al jugador
        if isAttacking and not playerHitThisAttack then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisAttack                = true
                _PlayerController_pendingDamage    = _EnemyDamage_skeleton
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end
end

function OnTriggerExit(self, other) end