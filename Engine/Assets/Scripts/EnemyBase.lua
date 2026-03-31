-- ============================================================
--  EnemyController.lua  –  Tunic-style enemy
--
--  State machine:
--    IDLE ──► PATROL ──► CHASE ──► ANTICIPATE ──► ATTACK ──► (cooldown)
--               ▲                                              │
--               └──────────────────────────────────────────────┘
--
--  Damage / stun / death: same pattern as SkeletonController
--  Movement: NavMesh pathfinding + SetLinearVelocity (physics)
--  Attack:   physics IMPULSE lunge + timed hitbox window
-- ============================================================

-- ── stdlib aliases ────────────────────────────────────────────────────────
local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- ── Audio source GameObjects (filled in Start) ────────────────────────────
local attackSource = nil
local dieSource    = nil
local hurtSource   = nil

-- ── States ───────────────────────────────────────────────────────────────
local State = {
    IDLE       = "Idle",
    PATROL     = "Patrol",
    CHASE      = "Chase",
    ANTICIPATE = "Anticipate",  -- wind-up telegraph (frozen)
    ATTACK     = "Attack",      -- hitbox active window
    DEAD       = "Dead",
}

-- ── Global interop (read by PlayerController) ────────────────────────────
_EnemyDamage_skeleton = 20

-- ── Public parameters ─────────────────────────────────────────────────────
public = {
    maxHp          = 30,

    -- Speeds
    patrolSpeed    = 2.5,
    chaseSpeed     = 4.8,
    lungeForce     = 18.0,       -- IMPULSE magnitude on the lunge

    -- Detection
    aggroRadius    = 8.0,
    deaggroRadius  = 14.0,
    attackRange    = 2.0,        -- distance to trigger ANTICIPATE

    -- Attack timing (seconds)
    anticipateDur  = 0.45,       -- telegraph freeze
    attackDur      = 0.45,       -- hitbox-active window
    attackColDelay = 0.22,       -- delay before enabling the hitbox collider
    cooldownBase   = 2.0,        -- base cooldown after each attack
    cooldownRage   = 1.2,        -- cooldown when HP < 50 %

    -- Damage & reaction
    attackDamage   = 20,
    knockbackForce = 5.0,
    stunDuration   = 0.35,       -- seconds paralysed after receiving a hit

    -- Patrol
    patrolWaitMin  = 1.0,
    patrolWaitMax  = 2.8,

    -- Rotation
    rotationSpeed  = 8.0,

    -- Animation names (change to match your rig's clip names)
    animIdle       = "Idle",
    animWalk       = "Walk",
    animAnticipate = "Anticipate",
    animAttack     = "Attack",
    animHit        = "Hit",
    animDeath      = "Death",
}

-- ── Runtime variables ─────────────────────────────────────────────────────
local currentState = State.IDLE
local hp           = 0

-- Death
local isDead       = false
local pendingDeath = false

-- Hit stun
local isStunned = false
local stunTimer = 0

-- Patrol
local patrolWait = 0

-- Attack / cooldown
local isAttacking         = false
local attackTimer         = 0
local isOnCooldown        = false
local cooldownTimer       = 0
local playerHitThisAttack = false   -- prevents double-damage per swing

-- ANTICIPATE (wind-up)
local anticipateTimer = 0

-- Player hit detection (dual system: trigger + polling, same as SkeletonController)
local playerAttackHandled = false   -- reset when lastAttack returns to ""
local alreadyHit          = false   -- guard inside OnTriggerEnter

-- Cached components
local nav       = nil
local rb        = nil
local anim      = nil
local attackCol = nil
local playerGO  = nil

-- Audio component references
local Enemy = {
    attackSFX = nil,
    dieSFX    = nil,
    hurtSFX   = nil,
    stepSFX   = nil,
}

-- ── Pure helpers ──────────────────────────────────────────────────────────

local function DistFlat(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return sqrt(dx * dx + dz * dz)
end

local function NormFlat(dx, dz)
    local len = sqrt(dx * dx + dz * dz)
    if len < 0.001 then return 0, 0 end
    return dx / len, dz / len
end

-- Returns the correct cooldown duration depending on rage phase.
local function GetAttackCooldown(self)
    local ratio = hp / self.public.maxHp
    if ratio < 0.5 then return self.public.cooldownRage end
    return self.public.cooldownBase
end

-- Drive horizontal velocity; preserve Y for gravity.
local function SetMoveVelocity(dx, dz, speed)
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(dx * speed, vel.y, dz * speed)
end

-- Kill XZ momentum, keep Y.
local function BrakeXZ()
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y, 0)
end

-- Smooth Y-axis rotation toward a world XZ point (uses rb so physics body stays in sync).
local function FaceTarget(self, target)
    local p  = self.transform.worldPosition
    local dx = target.x - p.x
    local dz = target.z - p.z
    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end
    rb:SetRotation(0, atan2(dx, dz) * (180.0 / pi), 0)
end

-- Convenience animation wrapper.
local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

-- ── TakeDamage ────────────────────────────────────────────────────────────
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end
    if not hp  then return end

    hp = hp - amount
    Engine.Log("[Enemy] HP left: " .. hp .. "/" .. self.public.maxHp)

    _PlayerController_triggerCameraShake = true

    -- Physics knockback impulse away from the attacker
    if rb and attackerPos then
        local enemyPos = self.transform.worldPosition
        local dx = enemyPos.x - attackerPos.x
        local dz = enemyPos.z - attackerPos.z
        local len = sqrt(dx * dx + dz * dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 and not pendingDeath then
        -- Death handled in Update next frame (same pattern as SkeletonController)
        --if Enemy.dieSFX then Enemy.dieSFX:PlayAudioEvent() end
        pendingDeath = true
        Engine.Log("[Enemy] HP agotado")
    else
        -- Hit stun: cancel any active action
        --if Enemy.hurtSFX then Enemy.hurtSFX:PlayAudioEvent() end
        isStunned           = true
        stunTimer           = self.public.stunDuration
        isAttacking         = false
        playerHitThisAttack = false   -- attack cancelled, reset flag
        anticipateTimer     = 0
        if attackCol then attackCol:Disable() end
        if nav       then nav:StopMovement()  end
        PlayAnim(self.public.animHit, 0.05)
        Engine.Log("[Enemy] STUN " .. self.public.stunDuration .. "s")
    end
end

-- ── State logic ───────────────────────────────────────────────────────────

local function UpdateIdle(self, dt)
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
        BrakeXZ()
        PlayAnim(self.public.animIdle, 0.2)
        patrolWait   = self.public.patrolWaitMin
            + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)
        currentState = State.IDLE
        return
    end

    local dx, dz = nav:GetMoveDirection(0.3)
    SetMoveVelocity(dx, dz, self.public.patrolSpeed)
    if dx ~= 0 or dz ~= 0 then
        local p = self.transform.worldPosition
        FaceTarget(self, { x = p.x + dx, y = p.y, z = p.z + dz })
    end
end

local function UpdateChase(self, dt)
    if not playerGO then currentState = State.IDLE; return end

    local myPos = self.transform.worldPosition
    local plPos = playerGO.transform.worldPosition
    local dist  = DistFlat(myPos, plPos)

    -- Deaggro: player escaped
    if dist > self.public.deaggroRadius then
        nav:StopMovement()
        BrakeXZ()
        PlayAnim(self.public.animIdle, 0.3)
        currentState = State.IDLE
        return
    end

    -- In range and cooldown over → begin wind-up
    if dist <= self.public.attackRange and not isOnCooldown then
        nav:StopMovement()
        BrakeXZ()
        anticipateTimer = 0
        PlayAnim(self.public.animAnticipate, 0.05)
        currentState = State.ANTICIPATE
        return
    end

    nav:SetDestination(plPos.x, plPos.y, plPos.z)
    local dx, dz = nav:GetMoveDirection(0.3)
    SetMoveVelocity(dx, dz, self.public.chaseSpeed)
    FaceTarget(self, plPos)
end

local function UpdateAnticipate(self, dt)
    anticipateTimer = anticipateTimer + dt

    -- Freeze and lock eyes on the player (the Tunic telegraph moment)
    BrakeXZ()
    if nav then nav:StopMovement() end
    if playerGO then FaceTarget(self, playerGO.transform.worldPosition) end

    if anticipateTimer < self.public.anticipateDur then return end

    -- Fire the lunge
    local myPos = self.transform.worldPosition
    local plPos = playerGO and playerGO.transform.worldPosition or myPos
    local ndx, ndz = NormFlat(plPos.x - myPos.x, plPos.z - myPos.z)
    rb:AddForce(ndx * self.public.lungeForce, 0, ndz * self.public.lungeForce, 2)

    if attackCol then attackCol:Disable() end   -- re-enabled after attackColDelay
    playerHitThisAttack = false
    isAttacking         = true
    attackTimer         = 0
    PlayAnim(self.public.animAttack, 0.05)
    --if Enemy.attackSFX then Enemy.attackSFX:PlayAudioEvent() end
    currentState = State.ATTACK
    Engine.Log("[Enemy] LUNGE + SWING!")
end

local function UpdateAttack(self, dt)
    attackTimer = attackTimer + dt

    -- Enable hitbox after the short delay (same two-stage pattern as SkeletonController)
    if attackTimer >= self.public.attackColDelay and attackCol then
        attackCol:Enable()
    end

    -- Proximity fallback: guarantee player damage even if OnTriggerEnter misfires
    if attackTimer >= self.public.attackColDelay
        and not playerHitThisAttack
        and playerGO
    then
        local pp  = playerGO.transform.position
        local mp  = self.transform.worldPosition
        if pp then
            local dist = sqrt((pp.x - mp.x)^2 + (pp.z - mp.z)^2)
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

    if attackTimer >= self.public.attackDur then
        isAttacking         = false
        playerHitThisAttack = false
        if attackCol then attackCol:Disable() end
        attackTimer = 0

        -- Cooldown with random jitter + rage phase (same as SkeletonController)
        isOnCooldown  = true
        cooldownTimer = GetAttackCooldown(self) + math.random() * 0.8
        currentState  = State.CHASE
        PlayAnim(self.public.animWalk, 0.25)
        Engine.Log("[Enemy] Cooldown " .. string.format("%.2f", cooldownTimer) .. "s")
    end
end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    Game.SetTimeScale(1.0)

    hp                  = self.public.maxHp
    isDead              = false
    pendingDeath        = false
    alreadyHit          = false
    playerAttackHandled = false
    currentState        = State.IDLE
    patrolWait          = self.public.patrolWaitMin
        + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)

    -- Components
    nav       = self.gameObject:GetComponent("Navigation")
    rb        = self.gameObject:GetComponent("Rigidbody")
    anim      = self.gameObject:GetComponent("Animation")
    attackCol = self.gameObject:GetComponent("Box Collider")
    Enemy.stepSFX = self.gameObject:GetComponent("Audio Source")

    -- Audio sources (child GameObjects with AudioSource components,
    -- same convention as SkeletonController's SK_DieSource etc.)
    attackSource = GameObject.Find("Enemy_AttackSource")
    dieSource    = GameObject.Find("Enemy_DieSource")
    hurtSource   = GameObject.Find("Enemy_HurtSource")
    if attackSource then Enemy.attackSFX = attackSource:GetComponent("Audio Source") end
    if dieSource    then Enemy.dieSFX    = dieSource:GetComponent("Audio Source")    end
    if hurtSource   then Enemy.hurtSFX   = hurtSource:GetComponent("Audio Source")   end

    PlayAnim(self.public.animIdle, 0.0)
    Engine.Log("[Enemy] Start OK")
end

-- ── Update ────────────────────────────────────────────────────────────────
function Update(self, dt)
    if isDead then return end

    -- ── Handle pending death (deferred one frame, same as SkeletonController) ─
    if pendingDeath then
        isAttacking  = false
        isOnCooldown = false
        if nav then nav:StopMovement() end
        if rb  then
            local vel = rb:GetLinearVelocity()
            rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        if attackCol then attackCol:Disable() end

        currentState = State.DEAD
        isDead       = true

        --if Enemy.dieSFX then Enemy.dieSFX:PlayAudioEvent() end

        PlayAnim(self.public.animDeath, 0.05)
        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
        return
    end

    -- ── External damage table (e.g. from projectiles or AoE) ─────────────
    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
    end

    -- ── Hit stun: freeze the enemy while it lasts ─────────────────────────
    if isStunned then
        stunTimer = stunTimer - dt
        if rb then
            local vel = rb:GetLinearVelocity()
            rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Enemy] Stun over")
        end
        return
    end

    -- ── Cooldown tick ─────────────────────────────────────────────────────
    if isOnCooldown then
        cooldownTimer = cooldownTimer - dt
        if cooldownTimer <= 0 then
            isOnCooldown = false
            Engine.Log("[Enemy] Cooldown over, ready to attack")
        end
    end

    -- ── Recover lost component references ────────────────────────────────
    if not nav or not rb then
        nav = self.gameObject:GetComponent("Navigation")
        rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not playerGO then
        playerGO = GameObject.Find("Player")
        if playerGO then Engine.Log("[Enemy] Player found") end
    end

    -- ── Player attack polling (Mode A) ────────────────────────────────────
    -- Checks _PlayerController_lastAttack every frame so hits register even
    -- when the overlap happens between trigger events.
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and playerGO and not isDead then
            local myPos = self.transform.worldPosition
            local pp    = playerGO.transform.position
            if pp then
                local dist = sqrt((pp.x - myPos.x)^2 + (pp.z - myPos.z)^2)
                if dist <= (self.public.attackRange + 1.5) then
                    playerAttackHandled = true
                    local attack = _PlayerController_lastAttack
                    if attack == "light" then
                        TakeDamage(self, 10, pp)
                    elseif attack == "heavy" or attack == "charge" then
                        TakeDamage(self, 25, pp)
                    end
                end
            end
        end
    else
        -- Player attack ended: reset both guard flags
        playerAttackHandled = false
        alreadyHit          = false
    end

    -- ── Aggro detection while idle / patrolling ───────────────────────────
    if (currentState == State.IDLE or currentState == State.PATROL) and playerGO then
        local dist = DistFlat(self.transform.worldPosition, playerGO.transform.worldPosition)
        if dist <= self.public.aggroRadius then
            nav:StopMovement()
            BrakeXZ()
            PlayAnim(self.public.animWalk, 0.2)
            currentState = State.CHASE
        end
    end

    -- ── State machine dispatch ────────────────────────────────────────────
    if     currentState == State.IDLE       then UpdateIdle(self, dt)
    elseif currentState == State.PATROL     then UpdatePatrol(self, dt)
    elseif currentState == State.CHASE      then UpdateChase(self, dt)
    elseif currentState == State.ANTICIPATE then UpdateAnticipate(self, dt)
    elseif currentState == State.ATTACK     then UpdateAttack(self, dt)
    end
end

-- ── OnTriggerEnter (Mode B) ───────────────────────────────────────────────
-- Trigger-based hit detection. Works together with the polling in Update.
function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then

        -- Receive a player attack
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            --if Enemy.hurtSFX then Enemy.hurtSFX:PlayAudioEvent() end
            if attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, 10, attackerPos)
                elseif attack == "heavy" or attack == "charge" then
                    TakeDamage(self, 25, attackerPos)
                end
            end
        end

        -- Deal damage to the player (once per swing)
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
-- alreadyHit resets in Update when _PlayerController_lastAttack goes back to "".
function OnTriggerExit(self, other)
end