local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs
local playerAttackHandled = false

-- audio source gameobjects
local attackSource
local dieSource
local hurtSource
local dodgeSource

local stepTimer = 0.5

-- ── States ────────────────────────────────────────────────────────────────
local State = {
    IDLE    = "Idle",
    WANDER  = "Wander",
    CHASE   = "Chase",
    COMBAT  = "Combat",   -- [NEW] Orbita/strafea alrededor del player (Tunic-style)
    WINDUP  = "Windup",   -- [NEW] Telegraph antes del ataque
    EVADE   = "Evade",
    DEAD    = "Dead"
}

-- ── Enemy table ────────────────────────────────────────────────────────────
local Enemy = {
    currentState    = nil,
    rb              = nil,
    nav             = nil,
    startPos        = nil,
    targetPos       = { x = 0, y = 0, z = 0 },
    nextWanderTimer = 0,
    chaseTimer      = 0,
    currentY        = 0,
    smoothDx        = 0,
    smoothDz        = 0,
    playerGO        = nil,
    attackSFX       = nil,
    dieSFX          = nil,
	dodgeSFX 		= nil,
	hurtSFX			= nil,
    stepSFX         = nil
}

-- ── Attack variables ──────────────────────────────────────────────────────
local isDead              = false
local pendingDeath        = false
local alreadyHit          = false
local attackCol           = nil
local attackTimer         = 0
local isAttacking         = false
local cooldownTimer       = 0
local isOnCooldown        = false
local playerHitThisAttack = false   -- evita doble daño por ataque

-- ── Dash / Evasion ────────────────────────────────────────────────────────
local dashTimer     = 0
local DASH_DURATION = 0.4

-- ── Hit stun ──────────────────────────────────────────────────────────────
local isStunned     = false
local stunTimer     = 0
local STUN_DURATION = 0.35   -- segundos paralizado al recibir un golpe

-- ── Predict system ────────────────────────────────────────────────────────
local predictTimer     = -1
local predictPos       = nil
local playerWasAttacking = false

-- ── [NEW] Combat / Circling variables ─────────────────────────────────────
-- El skeleton orbita al player en estado COMBAT antes de decidir atacar.
-- Cuando el timer llega a 0 entra en WINDUP (telegraph) y luego ataca.
local combatOrbitTimer  = 0   -- tiempo restante orbitando antes del ataque
local combatOrbitDir    = 1   -- 1 = clockwise, -1 = counter-clockwise
local orbitSwitchTimer  = 0   -- timer para cambiar de lado aleatoriamente

-- ── [NEW] Windup variables ────────────────────────────────────────────────
local WINDUP_DURATION   = 0.35  -- pausa de telegraph (ajusta según animación)
local windupTimer       = 0

-- ── Humanized movement ────────────────────────────────────────────────────
local orbitSpeedSmooth  = 0       -- velocidad de órbita con inercia (suavizado)
local orbitPhase        = 0       -- fase de la onda seno para variación orgánica
local isHesitating      = false   -- el skeleton está en pausa táctica
local hesitationTimer   = 0       -- duración de la hesitación actual
local isFeinting        = false   -- está fingiendo un ataque antes de retirarse
local feintTimer        = 0       -- cuánto dura el feint
local FEINT_DURATION    = 0.55    -- tiempo que avanza antes de abortar
local approachSpeedMult = 0       -- multiplicador de velocidad al acercarse (aceleración)
local wobblePhase       = 0       -- fase para el wobble radial del orbit

-- ── Humanized wander ─────────────────────────────────────────────────────
local wanderSpeedMult    = 1.0    -- multiplicador de velocidad actual del wander
local wanderPhase        = 0      -- onda seno para variación de velocidad al caminar
local isMicrostopping    = false  -- pausa breve a mitad del camino
local microstopTimer     = 0
local isLookingAround    = false  -- girando antes de decidir nuevo destino
local lookAroundTimer    = 0
local lookAroundAngle    = 0      -- ángulo objetivo del look-around
local lookAroundSpeed    = 0      -- velocidad del giro actual
local isFidgeting        = false  -- pequeño giro mientras espera en IDLE
local fidgetTimer        = 0
local fidgetAngle        = 0
local lastWanderAngle    = 0      -- dirección del último tramo (sesgo direccional)

-- ── Damage / timing constants ─────────────────────────────────────────────
local DAMAGE_LIGHT     = 10
local DAMAGE_HEAVY     = 25
local ATTACK_DURATION  = 0.5
local ATTACK_COL_DELAY = 0.25

-- [CHANGED] Cooldown más corto y dinámico. En fase enrabiada se reduce más.
local ATTACK_COOLDOWN_BASE = 2.0   -- era 5.0 — mucho más activo
local ATTACK_COOLDOWN_RAGE = 1.2   -- cuando HP < 50%

_EnemyDamage_skeleton = 20

local hp = 30

public = {
    moveSpeed          = 10.0,
    rotationSpeed      = 15.0,
    dirSmoothing       = 12.0,
    stopSmoothing      = 10.0,
    chaseRange         = 15.0,
    chaseUpdateRate    = 0.5,
    attackRange        = 2.0,
    patrolRadius       = 5.0,
    idleWaitTime       = 3.0,
    maxHp              = 30,
    knockbackForce     = 5.0,
    attackDamage       = 10,
    dashForce          = 25.0,
    dodgeChance        = 0.5,
    -- [NEW] Parámetros de orbiting (Tunic-style)
    orbitSpeed         = 4.5,    -- velocidad angular al circular al player
    orbitRadius        = 3.0,    -- distancia de combate al orbitar
    combatApproachTime = 1.2,    -- tiempo máximo orbitando antes de atacar (random dentro)
    -- [NEW] Lunge al atacar
    lungeForce         = 18.0,   -- impulso hacia el player al iniciar el swing
    -- [NEW] Face player smoothly durante combat
    facePlayerSpeed    = 8.0,    -- qué tan rápido gira hacia el player en COMBAT/WINDUP
}

-- ── Helpers ───────────────────────────────────────────────────────────────
local function lerp(a, b, t)
    t = min(1.0, t)
    return a + (b - a) * t
end

local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

-- [NEW] Rota suavemente hacia un punto objetivo (para combat/windup)
local function FaceTarget(self, targetPos, speed, dt)
    local myPos = self.transform.worldPosition
    local dx = targetPos.x - myPos.x
    local dz = targetPos.z - myPos.z
    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end
    local desiredAngle = atan2(dx, dz) * (180.0 / pi)
    local diff = shortAngleDiff(Enemy.currentY, desiredAngle)
    Enemy.currentY = Enemy.currentY + diff * speed * dt
    self.transform:SetRotation(0, Enemy.currentY, 0)
end

-- [NEW] Devuelve el cooldown actual según HP (rage phase)
local function GetAttackCooldown(self)
    local ratio = hp / self.public.maxHp
    if ratio < 0.5 then
        return ATTACK_COOLDOWN_RAGE
    end
    return ATTACK_COOLDOWN_BASE
end

-- ── TakeDamage ───────────────────────────────────────────────────────────
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end
    if not hp then return end
    hp = hp - amount
    Engine.Log("[Enemy] HP left: " .. hp .. "/" .. self.public.maxHp)

    _PlayerController_triggerCameraShake = true

    local rb = self.gameObject:GetComponent("Rigidbody")
    if rb and attackerPos then
        local enemyPos = self.transform.worldPosition
        local dx = enemyPos.x - attackerPos.x
        local dz = enemyPos.z - attackerPos.z
        local len = math.sqrt(dx * dx + dz * dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

	

    if hp <= 0 and not pendingDeath then
        --if dieSFX then dieSFX:PlayAudioEvent() end
        pendingDeath = true
        Engine.Log("[Enemy] HP agotado")
    else
        -- Mini-stun: cancelar lo que estaba haciendo
        isStunned         = true
        stunTimer         = STUN_DURATION
        isAttacking       = false
        playerHitThisAttack = false   -- el ataque se cancela, reset del flag
        windupTimer       = 0
        isFeinting        = false
        isHesitating      = false
        approachSpeedMult = 0
        if attackCol then attackCol:Disable() end
        if Enemy.nav  then Enemy.nav:StopMovement() end
        if Enemy.currentState ~= State.EVADE then
            Enemy.currentState = State.COMBAT
            combatOrbitTimer   = self.public.combatApproachTime * (0.5 + math.random() * 0.5)
        end
        Engine.Log("[Enemy] STUN " .. STUN_DURATION .. "s")
    end
end

-- ── TryEvasion ────────────────────────────────────────────────────────────
local function TryEvasion(self, attackerPos)
    local enemyPos = self.transform.worldPosition
    local dx = enemyPos.x - attackerPos.x
    local dz = enemyPos.z - attackerPos.z
    local len = math.max(0.001, math.sqrt(dx * dx + dz * dz))
    dx, dz = dx / len, dz / len

    local rb = self.gameObject:GetComponent("Rigidbody")
    if not rb then return false end

    local targetAngle = atan2(attackerPos.x - enemyPos.x, attackerPos.z - enemyPos.z) * (180 / pi)
    self.transform:SetRotation(0, targetAngle, 0)
    Enemy.currentY = targetAngle

    rb:AddForce(dx * self.public.dashForce, 0, dz * self.public.dashForce, 2)

    Enemy.currentState = State.EVADE
    dashTimer          = 0

	-- if dodgeSFX then dodgeSFX:PlayAudioEvent() end

    Engine.Log("[Enemy] ESQUIVE!")
    return true
end

-- ── Movement (navegación normal, fuera de combate) ────────────────────────
local function Movement(self, dt)
    if not Enemy.nav or not Enemy.rb then return false, 0 end

    local vel = Enemy.rb:GetLinearVelocity()
    local vy  = (vel and vel.y) or 0

    local isMoving    = Enemy.nav:IsMoving()
    local dx, dz      = Enemy.nav:GetMoveDirection(0.3)
    local hasFreshDir = (dx ~= 0 or dz ~= 0)

    if hasFreshDir then
        local mag = sqrt(dx * dx + dz * dz)
        dx, dz = dx / mag, dz / mag
    end

    if not isMoving then
        Enemy.smoothDx = lerp(Enemy.smoothDx, 0, dt * self.public.stopSmoothing)
        Enemy.smoothDz = lerp(Enemy.smoothDz, 0, dt * self.public.stopSmoothing)

        if abs(Enemy.smoothDx) < 0.01 and abs(Enemy.smoothDz) < 0.01 then
            Enemy.smoothDx, Enemy.smoothDz = 0, 0
            Enemy.rb:SetLinearVelocity(0, vy, 0)
        end
    elseif hasFreshDir then
        local t = min(1.0, dt * self.public.dirSmoothing)
        Enemy.smoothDx = Enemy.smoothDx + (dx - Enemy.smoothDx) * t
        Enemy.smoothDz = Enemy.smoothDz + (dz - Enemy.smoothDz) * t
    end

    if Enemy.smoothDx ~= 0 or Enemy.smoothDz ~= 0 then
        local targetAngle = atan2(Enemy.smoothDx, Enemy.smoothDz) * (180.0 / pi)
        local diff = shortAngleDiff(Enemy.currentY, targetAngle)
        Enemy.currentY = Enemy.currentY + diff * self.public.rotationSpeed * dt
        self.transform:SetRotation(0, Enemy.currentY, 0)
    end

    local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
    if sMag > 0.01 then
        local speed = self.public.moveSpeed
        local vX    = (Enemy.smoothDx / sMag) * speed
        local vZ    = (Enemy.smoothDz / sMag) * speed
        local pos   = self.transform.position
        self.transform:SetPosition(pos.x + vX * dt, pos.y, pos.z + vZ * dt)

        stepTimer = stepTimer + dt
        if stepTimer >= 0.25 then
            stepTimer = 0
            if Enemy.stepSFX then
                --Enemy.stepSFX:PlayAudioEvent()
            end
        end
    else
        stepTimer = 0
    end

    return isMoving, sMag
end

-- ── CombatOrbit: órbita humanizada ──────────────────────────────────────
local function CombatOrbit(self, playerPos, dt, speedScale)
    speedScale = speedScale or 1.0
    local myPos = self.transform.worldPosition

    -- Vector radial (enemy → player invertido)
    local rx = myPos.x - playerPos.x
    local rz = myPos.z - playerPos.z
    local currentDist = sqrt(rx * rx + rz * rz)
    if currentDist < 0.001 then rx = 1; rz = 0; currentDist = 1 end
    local nx = rx / currentDist
    local nz = rz / currentDist

    -- Tangente de órbita
    local tx = -nz * combatOrbitDir
    local tz =  nx * combatOrbitDir

    -- Onda seno para variación orgánica de velocidad (acelera y frena suavemente)
    orbitPhase = orbitPhase + dt * 0.9   -- frecuencia baja = variación lenta
    local sineVariation = 0.55 + 0.45 * math.sin(orbitPhase)  -- rango [0.1 , 1.0]

    -- Velocidad objetivo modulada
    local targetSpeed = self.public.orbitSpeed * sineVariation * speedScale

    -- Suavizar la velocidad de órbita con inercia (no saltos bruscos)
    local smoothRate = 4.0   -- qué tan rápido llega a targetSpeed
    orbitSpeedSmooth = orbitSpeedSmooth + (targetSpeed - orbitSpeedSmooth) * min(1.0, dt * smoothRate)

    -- Wobble radial: la distancia al player oscila ligeramente (no círculo perfecto)
    wobblePhase = wobblePhase + dt * 1.3
    local wobble = math.sin(wobblePhase) * 0.4   -- ±0.4 unidades de radio
    local targetRadius = self.public.orbitRadius + wobble
    local distError = targetRadius - currentDist
    local radialX   = nx * distError * 2.5
    local radialZ   = nz * distError * 2.5

    -- Movimiento final
    local moveX = tx * orbitSpeedSmooth + radialX
    local moveZ = tz * orbitSpeedSmooth + radialZ

    local pos = self.transform.position
    self.transform:SetPosition(pos.x + moveX * dt, pos.y, pos.z + moveZ * dt)

    if Enemy.nav then Enemy.nav:StopMovement() end

    -- Step SFX proporcional a la velocidad real
    if orbitSpeedSmooth > 0.5 then
        stepTimer = stepTimer + dt
        local stepInterval = lerp(0.45, 0.28, orbitSpeedSmooth / self.public.orbitSpeed)
        if stepTimer >= stepInterval then
            stepTimer = 0
            --if Enemy.stepSFX then Enemy.stepSFX:PlayAudioEvent() end
        end
    else
        stepTimer = 0
    end

    -- Face player suavemente
    FaceTarget(self, playerPos, self.public.facePlayerSpeed, dt)
end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    Game.SetTimeScale(1.0)

    hp         = self.public.maxHp
    isDead     = false
    alreadyHit = false

    Enemy.nav = self.gameObject:GetComponent("Navigation")
    Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
    Enemy.stepSFX = self.gameObject:GetComponent("Audio Source")

    dieSource = GameObject.Find("SK_DieSource")
    Enemy.dieSFX = dieSource:GetComponent("Audio Source")

    attackSource = GameObject.Find("SK_KopisSource")
    Enemy.attackSFX = attackSource:GetComponent("Audio Source")
	
	dodgeSource = GameObject.Find("SK_DodgeSource")
	Enemy.dodgeSFX = dodgeSource:GetComponent("Audio Source")
	
	hurtSource = GameObject.Find("SK_HurtSource")
	Enemy.hurtSFX = hurtSource:GetComponent("Audio Source")

    local pos = self.transform.position
    Enemy.startPos = { x = pos.x, y = pos.y, z = pos.z }

    Enemy.currentState    = State.IDLE
    Enemy.nextWanderTimer = self.public.idleWaitTime
    Enemy.chaseTimer      = 0
    Enemy.playerGO        = nil

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
        Engine.Log("[Enemy] Attack collider disabled")
    else
        Engine.Log("[Enemy] ERROR: No attack collider found")
    end
end

-- ── Update ────────────────────────────────────────────────────────────────
function Update(self, dt)
    if isDead then return end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        pendingDeath = true
    end

    -- Muerte: cancelar todo y destruir inmediatamente
    if pendingDeath then
        -- Cancelar cualquier acción activa
        isAttacking   = false
        isOnCooldown  = false
        predictTimer  = -1
        windupTimer   = 0
        if Enemy.nav  then Enemy.nav:StopMovement() end
        if Enemy.rb   then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end

        Enemy.currentState = State.DEAD
        isDead = true

        --if Enemy.dieSFX then Enemy.dieSFX:PlayAudioEvent() end

        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
        return
    end

    -- ── Hit stun: paralizar al enemy mientras dure el stun ───────────────
    if isStunned then
        stunTimer = stunTimer - dt
        -- Parar todo movimiento
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        if Enemy.rb then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Enemy] Stun terminado")
        end
        return
    end

    -- ── Detectar golpe del player ─────────────────────────────────────────
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and Enemy.playerGO and not isDead then
            local myPos = self.transform.position
            local pp    = Enemy.playerGO.transform.position
            if pp then
                local dx   = pp.x - myPos.x
                local dz   = pp.z - myPos.z
                local dist = sqrt(dx * dx + dz * dz)

                if dist <= (self.public.attackRange + 1.5) then
                    playerAttackHandled = true
                    local attack = _PlayerController_lastAttack

                    if Enemy.currentState ~= State.EVADE and predictTimer < 0 then
                        if attack == "light" then
                            TakeDamage(self, DAMAGE_LIGHT, pp)
                        elseif attack == "charge" then
                            TakeDamage(self, DAMAGE_HEAVY, pp)
                        end
                    else
                        Engine.Log("[Enemy] Golpe evitado por predicción/esquive")
                    end
                end
            end
        end
    else
        -- El ataque del player terminó: resetear ambas flags de hit
        playerAttackHandled = false
        alreadyHit          = false
    end

    -- ── Predict: lee el wind-up del player y programa esquive ─────────────
    local playerIsAttacking = (_PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "")

    if playerIsAttacking and not playerWasAttacking then
        if Enemy.currentState ~= State.EVADE then
            local myPos2 = self.transform.position
            local pp2    = Enemy.playerGO and Enemy.playerGO.transform.position
            if pp2 then
                local dist2 = sqrt((pp2.x - myPos2.x)^2 + (pp2.z - myPos2.z)^2)
                if dist2 < self.public.chaseRange and math.random() < self.public.dodgeChance then
                    predictTimer = math.random() * 0.3
                    predictPos   = { x = pp2.x, y = pp2.y, z = pp2.z }
                    Engine.Log("[Enemy] Predict programado en " .. string.format("%.2f", predictTimer) .. "s")
                end
            end
        end
    end
    playerWasAttacking = playerIsAttacking

    -- Countdown del esquive predicho
    if predictTimer >= 0 then
        predictTimer = predictTimer - dt
        if predictTimer <= 0 then
            predictTimer = -1
            if TryEvasion(self, predictPos) then
                Engine.Log("[Enemy] ¡Esquive por predicción!")
            end
            predictPos = nil
        end
    end

    -- ── Estado EVADE: esperar que acabe el dash ───────────────────────────
    if Enemy.currentState == State.EVADE then
        dashTimer = dashTimer + dt
        if dashTimer >= DASH_DURATION then
            Enemy.currentState    = State.COMBAT   -- [CHANGED] vuelve a COMBAT, no a IDLE
            Enemy.nextWanderTimer = 0.5
            dashTimer             = 0
            -- Reset orbit timer para que vuelva a orbitar un poco antes de atacar
            combatOrbitTimer = self.public.combatApproachTime * 0.5
        end
        return
    end

    -- Reintentar componentes si faltan
    if not Enemy.nav or not Enemy.rb then
        Enemy.nav = self.gameObject:GetComponent("Navigation")
        Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
        Enemy.stepSFX = self.gameObject:GetComponent("Audio Source")
        Enemy.dieSFX  = dieSource:GetComponent("Audio Source")
        Enemy.attackSFX = attackSource:GetComponent("Audio Source")
		Enemy.dodgeSFX = dodgeSource:GetComponent("Audio Source")
		Enemy.hurtSFX = hurtSource:GetComponent("Audio Source")
        return
    end

    if not Enemy.playerGO then
        Enemy.playerGO = GameObject.Find("Player")
        if Enemy.playerGO then Engine.Log("[Enemy] Player encontrado") end
    end

    local myPos = self.transform.position

    -- ── Detectar distancia al player ─────────────────────────────────────
    local playerPos   = nil
    local dist        = 999
    local inChaseRange  = false
    local inAttackRange = false

    if Enemy.playerGO then
        playerPos = Enemy.playerGO.transform.position
        if playerPos then
            local dx = playerPos.x - myPos.x
            local dz = playerPos.z - myPos.z
            dist = sqrt(dx * dx + dz * dz)
            inChaseRange  = dist < self.public.chaseRange
            inAttackRange = dist <= self.public.attackRange
        end
    end

    -- ── Cooldown activo: orbita al player en vez de quedarse quieto ───────
    -- [CHANGED] Antes se quedaba totalmente parado. Ahora sigue circulando
    -- (más Tunic-like: el enemigo nunca está completamente estático en combate)
    if isOnCooldown then
        cooldownTimer = cooldownTimer - dt
        if cooldownTimer <= 0 then
            isOnCooldown = false
            Engine.Log("[Enemy] Cooldown terminado, listo para atacar")
        end

        -- Si el player está cerca, orbitar durante el cooldown
        if inChaseRange and playerPos then
            -- Cambio de dirección de orbiting aleatorio
            orbitSwitchTimer = orbitSwitchTimer - dt
            if orbitSwitchTimer <= 0 then
                orbitSwitchTimer = math.random() * 1.5 + 0.8
                if math.random() < 0.3 then
                    combatOrbitDir = -combatOrbitDir
                end
            end
            CombatOrbit(self, playerPos, dt * 0.6)  -- orbita más lento durante cooldown
            FaceTarget(self, playerPos, self.public.facePlayerSpeed, dt)
        else
            -- Si el player se alejó, parar
            Enemy.smoothDx = 0
            Enemy.smoothDz = 0
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, vel.y, 0)
        end
        return
    end

    -- ── [NEW] Estado WINDUP: telegraph antes de atacar ────────────────────
    -- El skeleton se para, mira fijamente al player y carga el golpe.
    if Enemy.currentState == State.WINDUP then
        windupTimer = windupTimer + dt

        -- Parar movimiento
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        local vel = Enemy.rb:GetLinearVelocity()
        Enemy.rb:SetLinearVelocity(0, vel.y, 0)
        if Enemy.nav then Enemy.nav:StopMovement() end

        -- Face player muy rápido durante el windup (intimidante)
        if playerPos then
            FaceTarget(self, playerPos, self.public.facePlayerSpeed * 1.5, dt)
        end

        -- Cuando termina el windup → iniciar el ataque real con lunge
        if windupTimer >= WINDUP_DURATION then
            windupTimer  = 0
            isAttacking  = true
            attackTimer  = 0
            Enemy.currentState = State.CHASE   -- vuelve a CHASE para que el código de ataque funcione

            -- [NEW] Lunge: impulso hacia el player al iniciar el swing
            if Enemy.rb and playerPos then
                local lx = playerPos.x - myPos.x
                local lz = playerPos.z - myPos.z
                local ll = math.max(0.001, sqrt(lx * lx + lz * lz))
                lx, lz = lx / ll, lz / ll
                Enemy.rb:AddForce(lx * self.public.lungeForce, 0, lz * self.public.lungeForce, 2)
            end

            Engine.Log("[Enemy] LUNGE + SWING!")
            if Enemy.attackSFX then
                --Enemy.attackSFX:PlayAudioEvent()
            end
        end
        return
    end

    -- ── Lógica de ataque activo ───────────────────────────────────────────
    if isAttacking then
        -- Parar nav durante el swing
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        local vel = Enemy.rb:GetLinearVelocity()
        if vel then Enemy.rb:SetLinearVelocity(vel.x, vel.y, vel.z) end  -- dejar el lunge actuar
        if Enemy.nav then Enemy.nav:StopMovement() end

        attackTimer = attackTimer + dt

        if attackTimer >= ATTACK_COL_DELAY and attackCol then
            attackCol:Enable()
        end

        -- ── Fallback: check de proximidad por frame ───────────────────────
        -- Garantiza el daño aunque OnTriggerEnter no se dispare (p.ej. el player
        -- ya estaba dentro del collider cuando se activó el ataque).
        if attackTimer >= ATTACK_COL_DELAY and not playerHitThisAttack and Enemy.playerGO then
            local pp  = Enemy.playerGO.transform.position
            local mp  = self.transform.worldPosition
            if pp then
                local hdx  = pp.x - mp.x
                local hdz  = pp.z - mp.z
                local dist = sqrt(hdx * hdx + hdz * hdz)
                if dist <= self.public.attackRange then
                    local pending = _PlayerController_pendingDamage or 0
                    if pending == 0 then
                        playerHitThisAttack            = true
                        _PlayerController_pendingDamage    = _EnemyDamage_skeleton
                        _PlayerController_pendingDamagePos = self.transform.worldPosition
                        Engine.Log("[Enemy] HIT PLAYER (proximity) for " .. tostring(_EnemyDamage_skeleton))
                    end
                end
            end
        end

        if attackTimer >= ATTACK_DURATION then
            isAttacking          = false
            isOnCooldown         = true
            playerHitThisAttack  = false   -- reset para el siguiente ataque
            cooldownTimer = GetAttackCooldown(self) + math.random() * 0.8  -- [NEW] variacion aleatoria
            if attackCol then attackCol:Disable() end
            attackTimer = 0
            -- Volver a COMBAT para seguir circulando
            Enemy.currentState   = State.COMBAT
            combatOrbitTimer     = self.public.combatApproachTime * (0.4 + math.random() * 0.6)
            Engine.Log("[Enemy] Cooldown iniciado: " .. string.format("%.2f", cooldownTimer) .. "s")
        end
        return
    end

    -- ── Cancelar ataque si salió del rango ───────────────────────────────
    -- (solo aplica si isAttacking estaba true y salió de inRange)
    -- isAttacking ya se gestiona en el bloque de arriba.

    -- ── Detección de rango y transición de estados ───────────────────────
    if inChaseRange and playerPos then

        -- ── DENTRO del rango de ataque: iniciar WINDUP ───────────────────
        if inAttackRange then
            if Enemy.currentState ~= State.WINDUP and not isAttacking then
                -- Parar movimiento
                Enemy.smoothDx = 0
                Enemy.smoothDz = 0
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, vel.y, 0)
                if Enemy.nav then Enemy.nav:StopMovement() end

                -- Solo entrar en WINDUP si el esquive/predict no está activo
                if Enemy.currentState ~= State.EVADE and predictTimer < 0 then
                    Enemy.currentState = State.WINDUP
                    windupTimer        = 0
                    Engine.Log("[Enemy] WINDUP iniciado")
                end
            end
            return
        end

        -- ── FUERA del rango de ataque pero dentro del chaseRange ─────────
        -- Transición a COMBAT (circling) si no estaba ya
        if Enemy.currentState ~= State.COMBAT then
            Enemy.currentState   = State.COMBAT
            combatOrbitTimer     = self.public.combatApproachTime * (0.5 + math.random() * 0.5)
            combatOrbitDir       = (math.random() < 0.5) and 1 or -1
            orbitSwitchTimer     = math.random() * 1.2 + 0.6
            -- Reset estados de humanización al entrar en COMBAT
            isHesitating      = false
            isFeinting        = false
            approachSpeedMult = 0
            Engine.Log("[Enemy] Entrando en COMBAT (orbiting)")
        end

        -- ── Estado COMBAT: orbitar con hesitaciones, feints y approach ────
        if Enemy.currentState == State.COMBAT then
            combatOrbitTimer = combatOrbitTimer - dt
            orbitSwitchTimer = orbitSwitchTimer - dt

            -- ── Hesitación táctica ────────────────────────────────────────
            -- El skeleton se planta un momento, como leyendo al rival.
            if isHesitating then
                hesitationTimer = hesitationTimer - dt
                -- Durante la hesitación: quieto pero girando hacia el player
                orbitSpeedSmooth = orbitSpeedSmooth * (1.0 - dt * 6.0)  -- freno rápido
                Enemy.smoothDx = 0
                Enemy.smoothDz = 0
                if Enemy.rb then
                    local vel = Enemy.rb:GetLinearVelocity()
                    Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
                end
                FaceTarget(self, playerPos, self.public.facePlayerSpeed * 1.2, dt)
                if hesitationTimer <= 0 then
                    isHesitating = false
                    Engine.Log("[Enemy] Fin hesitación")
                end
                return
            end

            -- ── Cambio de dirección de órbita ────────────────────────────
            if orbitSwitchTimer <= 0 then
                orbitSwitchTimer = math.random() * 1.8 + 0.7

                -- 30% chance: cambiar lado
                if math.random() < 0.30 then
                    combatOrbitDir = -combatOrbitDir
                    orbitSpeedSmooth = orbitSpeedSmooth * 0.3  -- freno al cambiar de lado
                    Engine.Log("[Enemy] Cambia dirección de órbita")
                end

                -- 20% chance: entrar en hesitación (se planta y mira)
                if math.random() < 0.20 then
                    isHesitating    = true
                    hesitationTimer = math.random() * 0.4 + 0.2
                    Engine.Log("[Enemy] Hesitación táctica " .. string.format("%.2f", hesitationTimer) .. "s")
                end
            end

            -- ── Feint (fingir un ataque y retirarse) ─────────────────────
            if isFeinting then
                feintTimer = feintTimer - dt
                -- Acercarse hacia el player (el feint)
                approachSpeedMult = min(1.0, approachSpeedMult + dt * 4.0)
                Enemy.chaseTimer = Enemy.chaseTimer - dt
                if Enemy.chaseTimer <= 0 then
                    Enemy.chaseTimer = self.public.chaseUpdateRate
                    if Enemy.nav then
                        Enemy.nav:SetDestination(playerPos.x, playerPos.y, playerPos.z)
                    end
                end
                -- Velocidad reducida (es un amago, no un lunge completo)
                local savedSpeed = self.public.moveSpeed
                self.public.moveSpeed = savedSpeed * 0.55 * approachSpeedMult
                Movement(self, dt)
                self.public.moveSpeed = savedSpeed
                FaceTarget(self, playerPos, self.public.facePlayerSpeed, dt)

                if feintTimer <= 0 then
                    -- Abortar: retroceder un paso atrás
                    isFeinting = false
                    approachSpeedMult = 0
                    if Enemy.rb then
                        local myPos2 = self.transform.worldPosition
                        local bx = myPos2.x - playerPos.x
                        local bz = myPos2.z - playerPos.z
                        local bl = math.max(0.001, sqrt(bx*bx + bz*bz))
                        Enemy.rb:AddForce((bx/bl) * 6.0, 0, (bz/bl) * 6.0, 2)
                    end
                    -- Reset orbit para que siga circulando después del feint
                    combatOrbitTimer = self.public.combatApproachTime * (0.6 + math.random() * 0.4)
                    Engine.Log("[Enemy] Feint abortado, retrocediendo")
                end
                return
            end

            -- ── Decisión: orbitar o acercarse a atacar ────────────────────
            if combatOrbitTimer <= 0 then
                -- Timer expirado: decidir entre feint o ataque real
                if not isFeinting and math.random() < 0.35 then
                    -- 35% chance: feint primero
                    isFeinting        = true
                    feintTimer        = FEINT_DURATION
                    approachSpeedMult = 0
                    Engine.Log("[Enemy] Iniciando feint")
                else
                    -- Approach real hacia el player con aceleración suave
                    approachSpeedMult = min(1.0, approachSpeedMult + dt * 3.5)
                    Enemy.chaseTimer  = Enemy.chaseTimer - dt
                    if Enemy.chaseTimer <= 0 then
                        Enemy.chaseTimer = self.public.chaseUpdateRate
                        if Enemy.nav then
                            Enemy.nav:SetDestination(playerPos.x, playerPos.y, playerPos.z)
                        end
                    end
                    local savedSpeed = self.public.moveSpeed
                    self.public.moveSpeed = savedSpeed * approachSpeedMult
                    Movement(self, dt)
                    self.public.moveSpeed = savedSpeed
                    FaceTarget(self, playerPos, self.public.facePlayerSpeed, dt)
                end
            else
                -- Todavía en período de orbiting
                approachSpeedMult = 0   -- reset para que el approach empiece lento
                CombatOrbit(self, playerPos, dt)
            end
        end

    else
        -- Perdió al player: volver a patrulla
        if Enemy.currentState == State.CHASE or Enemy.currentState == State.COMBAT then
            Enemy.currentState    = State.IDLE
            Enemy.nextWanderTimer = self.public.idleWaitTime
            Engine.Log("[Enemy] Perdí al player. Descansando.")
        end

        -- ── Movimiento de patrulla humanizado (IDLE / WANDER) ───────────
        local isMoving, speed = Movement(self, dt)

        -- ── IDLE ──────────────────────────────────────────────────────────
        if Enemy.currentState == State.IDLE then
            Enemy.nextWanderTimer = Enemy.nextWanderTimer - dt

            -- Fidgeting: pequeños giros mientras espera (no queda como un poste)
            if not isFidgeting and math.random() < dt * 0.4 then
                isFidgeting  = true
                fidgetTimer  = math.random() * 0.6 + 0.3
                -- Giro de ±15-45 grados
                local sign   = (math.random() < 0.5) and 1 or -1
                fidgetAngle  = Enemy.currentY + sign * (15 + math.random() * 30)
            end
            if isFidgeting then
                fidgetTimer = fidgetTimer - dt
                local diff  = shortAngleDiff(Enemy.currentY, fidgetAngle)
                Enemy.currentY = Enemy.currentY + diff * 3.5 * dt
                self.transform:SetRotation(0, Enemy.currentY, 0)
                if fidgetTimer <= 0 then isFidgeting = false end
            end

            -- Cuando el timer de espera llega a 0: look-around antes de moverse
            if Enemy.nextWanderTimer <= 0 then
                if not isLookingAround then
                    -- Iniciar look-around: girar hacia una dirección aleatoria
                    isLookingAround  = true
                    lookAroundTimer  = math.random() * 0.7 + 0.3
                    local sign       = (math.random() < 0.5) and 1 or -1
                    lookAroundAngle  = Enemy.currentY + sign * (40 + math.random() * 60)
                    lookAroundSpeed  = 60 + math.random() * 40   -- grados/seg
                    isFidgeting      = false
                    Engine.Log("[Enemy] Look-around antes de moverme")
                else
                    -- Ejecutar el giro de look-around
                    lookAroundTimer = lookAroundTimer - dt
                    local diff      = shortAngleDiff(Enemy.currentY, lookAroundAngle)
                    Enemy.currentY  = Enemy.currentY + diff * (lookAroundSpeed / 90.0) * dt
                    self.transform:SetRotation(0, Enemy.currentY, 0)

                    if lookAroundTimer <= 0 then
                        -- Listo: elegir destino con sesgo direccional
                        isLookingAround = false

                        -- Sesgo: 60% seguir dirección similar al último tramo,
                        --         40% dirección completamente aleatoria
                        local angle
                        if math.random() < 0.60 and lastWanderAngle ~= 0 then
                            -- Variación de ±50° sobre el último ángulo
                            local spread = (math.random() - 0.5) * 2 * (pi * 50/180)
                            angle = lastWanderAngle + spread
                        else
                            angle = math.random() * pi * 2
                        end
                        lastWanderAngle = angle

                        -- Distancia variable (tramos cortos y largos mezclados)
                        local minR = self.public.patrolRadius * 0.25
                        local maxR = self.public.patrolRadius
                        local d    = minR + math.random() * (maxR - minR)

                        Enemy.targetPos.x = Enemy.startPos.x + math.cos(angle) * d
                        Enemy.targetPos.z = Enemy.startPos.z + math.sin(angle) * d

                        -- Velocidad aleatoria por tramo: paseo (0.4), trote (0.7), rápido (1.0)
                        local roll = math.random()
                        if roll < 0.45 then
                            wanderSpeedMult = 0.35 + math.random() * 0.15   -- paseo lento
                        elseif roll < 0.80 then
                            wanderSpeedMult = 0.55 + math.random() * 0.20   -- trote
                        else
                            wanderSpeedMult = 0.80 + math.random() * 0.20   -- paso rápido
                        end

                        if Enemy.nav then
                            Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                            Enemy.currentState = State.WANDER
                            isMicrostopping    = false
                            Engine.Log("[Enemy] Nuevo destino, velocidad x" .. string.format("%.2f", wanderSpeedMult))
                        end
                    end
                end
            end

        -- ── WANDER ────────────────────────────────────────────────────────
        elseif Enemy.currentState == State.WANDER then

            -- Microstop: pausa breve a mitad del camino (como si algo llamara la atención)
            if isMicrostopping then
                microstopTimer = microstopTimer - dt
                -- Parar velocidad durante el microstop
                Enemy.smoothDx = lerp(Enemy.smoothDx, 0, dt * self.public.stopSmoothing)
                Enemy.smoothDz = lerp(Enemy.smoothDz, 0, dt * self.public.stopSmoothing)
                if Enemy.rb then
                    local vel = Enemy.rb:GetLinearVelocity()
                    Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
                end
                -- Pequeño giro durante el microstop (curiosidad)
                local sign = (math.random() < 0.5) and 1 or -1
                Enemy.currentY = Enemy.currentY + sign * 25 * dt
                self.transform:SetRotation(0, Enemy.currentY, 0)

                if microstopTimer <= 0 then
                    isMicrostopping = false
                    -- Retomar la navegación al destino
                    if Enemy.nav then
                        Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                    end
                end
            else
                -- Variación orgánica de velocidad con onda seno mientras camina
                wanderPhase = wanderPhase + dt * 1.1
                local sine  = 0.75 + 0.25 * math.sin(wanderPhase)   -- rango [0.5, 1.0]

                -- Aplicar velocidad modulada
                local savedSpeed = self.public.moveSpeed
                self.public.moveSpeed = savedSpeed * wanderSpeedMult * sine
                Movement(self, dt)   -- ya se llamó arriba, esta es para ajustar en wander
                self.public.moveSpeed = savedSpeed

                -- Decidir si hacer un microstop (probabilidad baja, solo si está en movimiento)
                if isMoving and not isMicrostopping and math.random() < dt * 0.08 then
                    isMicrostopping = true
                    microstopTimer  = math.random() * 0.5 + 0.2
                    if Enemy.nav then Enemy.nav:StopMovement() end
                    Engine.Log("[Enemy] Microstop")
                end
            end

            -- Llegó al destino
            if not isMoving and speed < 0.05 and not isMicrostopping then
                -- Tiempo de espera variable: corto (0.5s), normal (2s), largo (4s)
                local roll = math.random()
                local wait
                if roll < 0.3 then
                    wait = 0.3 + math.random() * 0.5        -- parada rápida
                elseif roll < 0.75 then
                    wait = self.public.idleWaitTime * (0.6 + math.random() * 0.6)
                else
                    wait = self.public.idleWaitTime * (1.2 + math.random() * 0.8)  -- larga pausa
                end
                Enemy.nextWanderTimer = wait
                Enemy.currentState    = State.IDLE
                isFidgeting           = false
                Engine.Log("[Enemy] Descansando " .. string.format("%.1f", wait) .. "s")
            end
        end
    end
end

-- ── OnTriggerEnter ────────────────────────────────────────────────────────
function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            --if hurtSFX then hurtSFX:PlayAudioEvent() end
            if attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition

                if Enemy.currentState == State.EVADE or predictTimer >= 0 then
                    Engine.Log("[Enemy] Golpe evitado por predicción")
                else
                    if attack == "light" then
                        TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                    elseif attack == "heavy" then
                        TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                    end
                end
            end
        end

        if isAttacking and not playerHitThisAttack then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisAttack            = true
                _PlayerController_pendingDamage    = _EnemyDamage_skeleton
                _PlayerController_pendingDamagePos = self.transform.worldPosition
                Engine.Log("[Enemy] HIT PLAYER (trigger) for " .. tostring(_EnemyDamage_skeleton))
            end
        end
    end
end

-- ── OnTriggerExit ─────────────────────────────────────────────────────────
-- alreadyHit se resetea en Update cuando _PlayerController_lastAttack vuelve a ""
-- así un sweep que entra/sale del trigger varias veces solo hace daño una vez.
function OnTriggerExit(self, other)
end