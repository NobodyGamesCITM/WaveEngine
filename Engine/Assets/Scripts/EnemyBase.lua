local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- ── States ────────────────────────────────────────────────────────────────
local State = {
    IDLE   = "Idle",
    WANDER = "Wander",
    CHASE  = "Chase",
    DEAD   = "Dead"
}

-- ── Enemy table (estructura de SkeletonController) ────────────────────────
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
}

-- ── Attack variables (de EnemyController) ────────────────────────────────
local isDead      = false
local alreadyHit  = false
local attackCol   = nil
local attackTimer    = 0
local isAttacking    = false
local cooldownTimer  = 0
local isOnCooldown   = false

local DAMAGE_LIGHT     = 10
local DAMAGE_HEAVY     = 25
local ATTACK_DURATION  = 0.5
local ATTACK_COL_DELAY = 0.25
local ATTACK_COOLDOWN  = 5.0   -- segundos de espera entre ataques

_EnemyDamage_skeleton = 20

local hp

public = {
    moveSpeed       = 10.0,
    rotationSpeed   = 15.0,
    dirSmoothing    = 12.0,
    stopSmoothing   = 10.0,
    chaseRange      = 15.0,
    chaseUpdateRate = 0.5,
    attackRange     = 2.0,
    patrolRadius    = 5.0,
    idleWaitTime    = 3.0,
    maxHp           = 30,
    knockbackForce  = 5.0,
    attackDamage    = 10,
}

-- ── Helpers (de SkeletonController) ──────────────────────────────────────
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

-- ── TakeDamage (de EnemyController) ──────────────────────────────────────
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

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

    if hp <= 0 then
        isDead = true
        Enemy.currentState = State.DEAD
        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
    end
end

-- ── Movement (de SkeletonController) ─────────────────────────────────────
local function Movement(self, dt)
    if not Enemy.nav or not Enemy.rb then return false, 0 end

    local vel = Enemy.rb:GetLinearVelocity()
    local vy  = (vel and vel.y) or 0

    local isMoving    = Enemy.nav:IsMoving()
    local dx, dz      = Enemy.nav:GetMoveDirection(0.3)
    local hasFreshDir = (dx ~= 0 or dz ~= 0)

    -- Normalización
    if hasFreshDir then
        local mag = sqrt(dx * dx + dz * dz)
        dx, dz = dx / mag, dz / mag
    end

    -- Suavizado de dirección
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

    -- Rotación
    if Enemy.smoothDx ~= 0 or Enemy.smoothDz ~= 0 then
        local targetAngle = atan2(Enemy.smoothDx, Enemy.smoothDz) * (180.0 / pi)
        local diff = shortAngleDiff(Enemy.currentY, targetAngle)
        Enemy.currentY = Enemy.currentY + diff * self.public.rotationSpeed * dt
        self.transform:SetRotation(0, Enemy.currentY, 0)
    end

    -- Aplicar posición
    local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
    if sMag > 0.01 then
        local speed = self.public.moveSpeed
        local vX    = (Enemy.smoothDx / sMag) * speed
        local vZ    = (Enemy.smoothDz / sMag) * speed
        local pos   = self.transform.position
        self.transform:SetPosition(pos.x + vX * dt, pos.y, pos.z + vZ * dt)
    end

    return isMoving, sMag
end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    hp         = self.public.maxHp
    isDead     = false
    alreadyHit = false

    Enemy.nav = self.gameObject:GetComponent("Navigation")
    Enemy.rb  = self.gameObject:GetComponent("Rigidbody")

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

    -- Reintentar conseguir componentes si faltan
    if not Enemy.nav or not Enemy.rb then
        Enemy.nav = self.gameObject:GetComponent("Navigation")
        Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    -- Buscar player si aún no se tiene referencia
    if not Enemy.playerGO then
        Enemy.playerGO = GameObject.Find("Player")
        if Enemy.playerGO then Engine.Log("[Enemy] Player encontrado") end
    end

    local myPos   = self.transform.position
    local inRange = false   -- dentro del attackRange (bloquear y atacar)

    -- ── Detección y persecución del player ───────────────────────────────
    if Enemy.playerGO then
        local pp = Enemy.playerGO.transform.position
        if pp then
            local distX = pp.x - myPos.x
            local distZ = pp.z - myPos.z
            local dist  = sqrt(distX * distX + distZ * distZ)

            if dist < self.public.chaseRange then
                Enemy.currentState = State.CHASE

                if dist <= self.public.attackRange then
                    -- En rango de ataque: parar
                    inRange = true
                    Enemy.nav:StopMovement()
                else
                    -- Seguir persiguiendo
                    Enemy.chaseTimer = Enemy.chaseTimer - dt
                    if Enemy.chaseTimer <= 0 then
                        Enemy.chaseTimer = self.public.chaseUpdateRate
                        Enemy.nav:SetDestination(pp.x, pp.y, pp.z)
                    end
                end
            else
                -- Perdió al player: volver a patrulla
                if Enemy.currentState == State.CHASE then
                    Enemy.currentState    = State.IDLE
                    Enemy.nextWanderTimer = self.public.idleWaitTime
                    Engine.Log("[Enemy] Perdí al player. Descansando.")
                end
            end
        end
    end

    -- ── Modo ataque: quieto golpeando al player ───────────────────────────
    if inRange then
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        local vel = Enemy.rb:GetLinearVelocity()
        Enemy.rb:SetLinearVelocity(0, vel.y, 0)

        -- Cooldown entre ataques: se gestiona fuera del bloque inRange
        if isOnCooldown then return end

        if not isAttacking then
            isAttacking = true
            attackTimer = 0
            Engine.Log("[Enemy] ATTACKING")
        end

        attackTimer = attackTimer + dt

        if attackTimer >= ATTACK_COL_DELAY and attackCol then
            attackCol:Enable()
        end

        if attackTimer >= ATTACK_DURATION then
            isAttacking   = false
            isOnCooldown  = true
            cooldownTimer = ATTACK_COOLDOWN
            if attackCol then attackCol:Disable() end
            attackTimer = 0
        end

        return  -- No hacer movimiento ni patrulla mientras ataca
    end

    -- Cancelar ataque si salió del rango
    if isAttacking then
        isAttacking = false
        if attackCol then attackCol:Disable() end
        attackTimer = 0
    end

    -- Cooldown activo: quieto aunque el player se aleje del attackRange
    if isOnCooldown then
        cooldownTimer = cooldownTimer - dt
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        local vel = Enemy.rb:GetLinearVelocity()
        Enemy.rb:SetLinearVelocity(0, vel.y, 0)
        if cooldownTimer <= 0 then
            isOnCooldown = false
            Engine.Log("[Enemy] Cooldown terminado, listo para atacar")
        end
        return
    end

    -- ── Movimiento (siempre activo fuera del modo ataque) ─────────────────
    local isMoving, speed = Movement(self, dt)

    -- ── State machine de patrulla (IDLE / WANDER) ─────────────────────────
    if Enemy.currentState == State.IDLE then
        Enemy.nextWanderTimer = Enemy.nextWanderTimer - dt

        if Enemy.nextWanderTimer <= 0 then
            local angle = math.random() * pi * 2
            local dist  = math.random() * self.public.patrolRadius

            Enemy.targetPos.x = Enemy.startPos.x + math.cos(angle) * dist
            Enemy.targetPos.z = Enemy.startPos.z + math.sin(angle) * dist

            if Enemy.nav then
                Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                Enemy.currentState = State.WANDER
                Engine.Log("[Enemy] Buscando nuevo punto...")
            end
        end

    elseif Enemy.currentState == State.WANDER then
        -- Llegó al destino: nav parada e inercia asentada
        if not isMoving and speed < 0.05 then
            Enemy.nextWanderTimer = self.public.idleWaitTime
            Enemy.currentState    = State.IDLE
            Engine.Log("[Enemy] He llegado. Descansando.")
        end
    end
end

-- ── OnTriggerEnter ────────────────────────────────────────────────────────
function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        -- El player golpea al enemigo
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end

        -- El enemigo golpea al player
        if isAttacking and _PlayerController_pendingDamage == 0 then
            _PlayerController_pendingDamage    = _EnemyDamage_skeleton
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            Engine.Log("[Enemy] HIT PLAYER for " .. tostring(self.public.attackDamage))
        end
    end
end

-- ── OnTriggerExit ─────────────────────────────────────────────────────────
function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end