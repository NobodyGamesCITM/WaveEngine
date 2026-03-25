local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

local State = {
    IDLE   = "Idle",
    WANDER = "Wander",
    CHASE  = "Chase",
    CHARGE = "Charge",
    DEAD   = "Dead"
}

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
    chargeDirX      = 0,
    chargeDirZ      = 0,
    chargeTimer     = 0,
    cooldownTimer   = 0,
    hitDuringCharge = false,
}

local isDead     = false
local alreadyHit = false
local attackCol  = nil

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

_EnemyDamage_minocabro = 35

local hp

public = {
    moveSpeed       = 8.0,
    chargeSpeed     = 28.0,
    rotationSpeed   = 10.0,
    dirSmoothing    = 10.0,
    stopSmoothing   = 8.0,
    chaseRange      = 18.0,
    chargeRange     = 12.0,
    chaseUpdateRate = 0.4,
    chargeDuration  = 0.7,
    chargeCooldown  = 3.5,
    patrolRadius    = 6.0,
    idleWaitTime    = 3.0,
    maxHp           = 60,
    knockbackForce  = 22.0,
}

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

local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    hp = hp - amount
    Engine.Log("[Minocabro] HP: " .. hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if Enemy.rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx * dx + dz * dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        local vel = Enemy.rb:GetLinearVelocity()
        Enemy.rb:SetLinearVelocity(
            dx * self.public.knockbackForce * 0.4,
            vel.y,
            dz * self.public.knockbackForce * 0.4
        )
    end

    if hp <= 0 then
        isDead = true
        Enemy.currentState = State.DEAD
        Engine.Log("[Minocabro] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.1
        self:Destroy()
    end
end

local function RotateTowards(self, dirX, dirZ, dt)
    if abs(dirX) < 0.01 and abs(dirZ) < 0.01 then return end
    local targetAngle = atan2(dirX, dirZ) * (180.0 / pi)
    local diff = shortAngleDiff(Enemy.currentY, targetAngle)
    Enemy.currentY = Enemy.currentY + diff * self.public.rotationSpeed * dt
    self.transform:SetRotation(0, Enemy.currentY, 0)
end

local function Movement(self, dt)
    if not Enemy.nav or not Enemy.rb then return false, 0 end

    local vel      = Enemy.rb:GetLinearVelocity()
    local vy       = (vel and vel.y) or 0

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
        else
            Enemy.rb:SetLinearVelocity(
                Enemy.smoothDx * self.public.moveSpeed,
                vy,
                Enemy.smoothDz * self.public.moveSpeed
            )
        end
    elseif hasFreshDir then
        local t = min(1.0, dt * self.public.dirSmoothing)
        Enemy.smoothDx = Enemy.smoothDx + (dx - Enemy.smoothDx) * t
        Enemy.smoothDz = Enemy.smoothDz + (dz - Enemy.smoothDz) * t

        local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
        if sMag > 0.01 then
            Enemy.rb:SetLinearVelocity(
                (Enemy.smoothDx / sMag) * self.public.moveSpeed,
                vy,
                (Enemy.smoothDz / sMag) * self.public.moveSpeed
            )
        end

        RotateTowards(self, Enemy.smoothDx, Enemy.smoothDz, dt)
    end

    local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
    return isMoving, sMag
end

local function BeginCharge(self)
    if not Enemy.playerGO then return end

    local myPos = self.transform.worldPosition
    local pp    = Enemy.playerGO.transform.worldPosition
    if not pp then return end

    local dx  = pp.x - myPos.x
    local dz  = pp.z - myPos.z
    local len = sqrt(dx * dx + dz * dz)
    if len < 0.001 then return end

    Enemy.chargeDirX      = dx / len
    Enemy.chargeDirZ      = dz / len
    Enemy.chargeTimer     = self.public.chargeDuration 
    Enemy.hitDuringCharge = false
    Enemy.smoothDx        = 0
    Enemy.smoothDz        = 0

    local targetAngle = atan2(Enemy.chargeDirX, Enemy.chargeDirZ) * (180.0 / pi)
    Enemy.currentY = targetAngle
    self.transform:SetRotation(0, Enemy.currentY, 0)

    if Enemy.nav then Enemy.nav:StopMovement() end

    Enemy.currentState = State.CHARGE
    Engine.Log("[Minocabro] ¡EMBESTIDA!")
end

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
    Enemy.cooldownTimer   = 0
    Enemy.playerGO        = nil

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    Engine.Log("[Minocabro] Start OK - HP: " .. hp)
end

function Update(self, dt)
    if isDead then return end

    if not Enemy.nav or not Enemy.rb then
        Enemy.nav = self.gameObject:GetComponent("Navigation")
        Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not Enemy.playerGO then
        Enemy.playerGO = GameObject.Find("Player")
        if Enemy.playerGO then Engine.Log("[Minocabro] Player encontrado") end
    end

    if Enemy.cooldownTimer > 0 then
        Enemy.cooldownTimer = Enemy.cooldownTimer - dt
    end

    -- CHARGE
    if Enemy.currentState == State.CHARGE then
        Enemy.chargeTimer = Enemy.chargeTimer - dt

        if attackCol then attackCol:Enable() end

        local vel = Enemy.rb:GetLinearVelocity()
        Enemy.rb:SetLinearVelocity(
            Enemy.chargeDirX * self.public.chargeSpeed,
            vel.y,
            Enemy.chargeDirZ * self.public.chargeSpeed
        )

        if Enemy.chargeTimer <= 0 then
            if attackCol then attackCol:Disable() end
            local vel2 = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, vel2.y, 0)
            Enemy.cooldownTimer = self.public.chargeCooldown
            Enemy.currentState  = State.CHASE
            Engine.Log("[Minocabro] Embestida terminada")
        end
        return
    end

    -- Detección del player 
    if Enemy.playerGO then
        local myPos = self.transform.worldPosition
        local pp    = Enemy.playerGO.transform.worldPosition

        if pp then
            local distX = pp.x - myPos.x
            local distZ = pp.z - myPos.z
            local dist  = sqrt(distX * distX + distZ * distZ)

            if dist < self.public.chaseRange then

                if dist <= self.public.chargeRange and Enemy.cooldownTimer <= 0 then
                    BeginCharge(self)
                    return
                end

                Enemy.currentState = State.CHASE
                Enemy.chaseTimer   = Enemy.chaseTimer - dt
                if Enemy.chaseTimer <= 0 then
                    Enemy.chaseTimer = self.public.chaseUpdateRate
                    if Enemy.nav then
                        Enemy.nav:SetDestination(pp.x, pp.y, pp.z)
                    end
                end

            else
                if Enemy.currentState == State.CHASE then
                    local vel = Enemy.rb:GetLinearVelocity()
                    Enemy.rb:SetLinearVelocity(0, vel.y, 0)
                    Enemy.currentState    = State.IDLE
                    Enemy.nextWanderTimer = self.public.idleWaitTime
                    Engine.Log("[Minocabro] Perdí al player")
                end
            end
        end
    end

    local isMoving, speed = Movement(self, dt)

    -- IDLE / WANDER
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
                Engine.Log("[Minocabro] Nuevo punto de patrulla")
            end
        end

    elseif Enemy.currentState == State.WANDER then
        if not isMoving and speed < 0.05 then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            Enemy.nextWanderTimer = self.public.idleWaitTime
            Enemy.currentState    = State.IDLE
            Engine.Log("[Minocabro] Llegué al punto, descansando")
        end
    end
end

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then

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

        if Enemy.currentState == State.CHARGE
           and not Enemy.hitDuringCharge
           and _PlayerController_pendingDamage == 0 then

            Enemy.hitDuringCharge              = true
            _PlayerController_pendingDamage    = _EnemyDamage_minocabro
            _PlayerController_pendingDamagePos = self.transform.worldPosition

            if attackCol then attackCol:Disable() end
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            Enemy.chargeTimer   = 0
            Enemy.cooldownTimer = self.public.chargeCooldown
            Enemy.currentState  = State.CHASE

            Engine.Log("[Minocabro] ¡Impacto! Daño: " .. _EnemyDamage_minocabro)
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end