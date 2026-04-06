local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

-- ── Audio GameObjects (found in Start) ───────────────────────────────────
local attackSource = nil
local dieSource    = nil
local hurtSource   = nil

-- ── States ───────────────────────────────────────────────────────────────
local State = {
    IDLE           = "Idle",
    WALK           = "Walk",           -- NavMesh approach (far, no abilities)
    RETREAT        = "Retreat",        -- Back away (close, no attack, no dash)
    ANTICIPATE_ATK = "AntAtk",        -- Melee wind-up
    ATTACK         = "Attack",         -- Melee active
    ANTICIPATE_DSH = "AntDsh",        -- Dash wind-up
    DASH           = "Dash",           -- Dash burst toward player
    ANTICIPATE_CHG = "AntChg",        -- Charge wind-up
    CHARGE         = "Charge",         -- Full charge / embestida
    DEAD           = "Dead",
}

-- ── Global damage export (read by player hit system) ─────────────────────
_BossDamage = 40

-- ── Public parameters ─────────────────────────────────────────────────────
public = {
    maxHp              = 200,

    -- ── Ranges ────────────────────────────────────────────────────────────
    closeRange         = 4.0,    -- dist <= this → "close" branch
    attackRange        = 2.5,    -- melee hitbox proximity check
    aggroRadius        = 22.0,   -- not used as a gate here but useful for UI/debug

    -- ── Movement ──────────────────────────────────────────────────────────
    walkSpeed          = 4.2,    -- NavMesh walk speed (far + no abilities)
    retreatSpeed       = 5.5,    -- physics retreat speed
    moveAccel          = 16.0,   -- velocity lerp rate (acceleration)
    brakeDecel         = 12.0,   -- velocity lerp rate (braking)
    rotationSpeed      = 8.0,    -- degrees per frame (× dt × 60)

    -- ── NavMesh ───────────────────────────────────────────────────────────
    navRefreshRate     = 0.2,    -- seconds between SetDestination calls

    -- ── Melee attack ──────────────────────────────────────────────────────
    attackDamage       = 35,
    attackKnockback    = 7.0,
    anticipateAtkDur   = 0.50,   -- wind-up before lunge
    attackDur          = 0.55,   -- total attack state duration
    attackColDelay     = 0.22,   -- delay before hitbox activates
    attackLungeForce   = 14.0,   -- forward impulse on lunge
    attackLungeStopT   = 0.22,   -- seconds until lunge brakes
    attackCooldownBase = 2.5,    -- seconds before next attack

    -- ── Dash (approach ability, short cooldown) ───────────────────────────
    dashForce          = 24.0,   -- physics impulse
    dashDur            = 0.40,   -- how long the dash lasts
    anticipateDshDur   = 0.30,   -- quick wind-up
    dashCooldownBase   = 5.0,
    dashDamage         = 20,
    dashHitRadius      = 1.8,    -- proximity to register a dash hit

    -- ── Charge / Embestida (long-range, strong) ───────────────────────────
    chargeForce        = 32.0,   -- big physics impulse
    chargeDur          = 0.80,   -- full charge duration
    anticipateChgDur   = 0.70,   -- long wind-up (telegraphed)
    chargeCooldownBase = 10.0,
    chargeDamage       = 55,
    chargeKnockback    = 18.0,
    chargeHitRadius    = 2.2,

    -- ── Damage received ───────────────────────────────────────────────────
    stunDuration       = 0.30,
    knockbackForce     = 6.0,

    -- ── Animations (swap names to match your rig) ─────────────────────────
    animIdle           = "Idle",
    animWalk           = "Walk",
    animAntAtk         = "Anticipate",
    animAttack         = "Attack",
    animAntDash        = "DashAnticipate",
    animDash           = "Dash",
    animAntChg         = "ChargeAnticipate",
    animCharge         = "Charge",
    animHit            = "Hit",
    animDeath          = "Death",
}

-- ── Runtime state ─────────────────────────────────────────────────────────
local currentState   = State.IDLE
local hp             = 0
local isDead         = false
local pendingDeath   = false
local isStunned      = false
local stunTimer      = 0

-- Cooldown flags & timers
local canAttack       = true
local attackCooldown  = 0
local canDash         = true
local dashCooldown    = 0
local canCharge       = true
local chargeCooldown  = 0

-- Per-ability timers
local anticipateTimer  = 0
local attackTimer      = 0
local lungeStopTimer   = 0
local dashTimer        = 0
local chargeTimer      = 0

-- Hit-once guards per ability activation
local playerHitThisAtk  = false
local playerHitThisDash = false
local playerHitThisChg  = false

-- Player attack polling guard
local alreadyHit = false

-- NavMesh throttle
local navRefreshTimer = 0

-- Components
local nav       = nil
local rb        = nil
local anim      = nil
local attackCol = nil
local playerGO  = nil

-- Physics velocity targets
local targetVelX = 0
local targetVelZ = 0
local currentYaw = 0

local Boss = { attackSFX = nil, dieSFX = nil, hurtSFX = nil }

-- ─────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────────────

local function DistFlat(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return sqrt(dx * dx + dz * dz)
end

local function NormFlat(dx, dz)
    local len = sqrt(dx * dx + dz * dz)
    if len < 0.001 then return 0, 0 end
    return dx / len, dz / len
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Physics movement
local function SetTargetVelocity(dx, dz, speed)
    targetVelX = dx * speed
    targetVelZ = dz * speed
end

local function ApplyMoveVelocity(dt, accelRate)
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(
        Lerp(vel.x, targetVelX, dt * accelRate),
        vel.y,
        Lerp(vel.z, targetVelZ, dt * accelRate)
    )
end

local function RequestBrakeXZ()
    targetVelX = 0
    targetVelZ = 0
end

local function HardBrakeXZ()
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y or 0, 0)
    targetVelX = 0
    targetVelZ = 0
end

-- Smooth yaw rotation toward a world-space target point
local function FaceTargetSmooth(self, target, dt)
    local p  = self.transform.worldPosition
    local dx = target.x - p.x
    local dz = target.z - p.z
    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end

    local desiredYaw = atan2(dx, dz) * (180 / pi)
    local delta      = desiredYaw - currentYaw
    delta = delta - math.floor((delta + 180) / 360) * 360   -- wrap to (-180, 180]

    local maxTurn = self.public.rotationSpeed * dt * 60
    currentYaw    = currentYaw + Clamp(delta, -maxTurn, maxTurn)
    rb:SetRotation(0, currentYaw, 0)
end

local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

-- ─────────────────────────────────────────────────────────────────────────
-- COOLDOWN TICK  (called every frame outside stun)
-- ─────────────────────────────────────────────────────────────────────────

local function TickCooldowns(dt)
    if not canAttack then
        attackCooldown = attackCooldown - dt
        if attackCooldown <= 0 then
            canAttack = true
            Engine.Log("[Boss] Attack ready")
        end
    end

    if not canDash then
        dashCooldown = dashCooldown - dt
        if dashCooldown <= 0 then
            canDash = true
            Engine.Log("[Boss] Dash ready")
        end
    end

    if not canCharge then
        chargeCooldown = chargeCooldown - dt
        if chargeCooldown <= 0 then
            canCharge = true
            Engine.Log("[Boss] Charge ready")
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- TAKE DAMAGE
-- ─────────────────────────────────────────────────────────────────────────

local function TakeDamage(self, amount, attackerPos)
    if isDead or not hp then return end

    hp = hp - amount
    Engine.Log("[Boss] HP: " .. hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if hp <= 0 and not pendingDeath then
        pendingDeath = true
        return
    end

    -- Physics knockback away from attacker
    if rb and attackerPos then
        local ep     = self.transform.worldPosition
        local kx, kz = NormFlat(ep.x - attackerPos.x, ep.z - attackerPos.z)
        rb:AddForce(kx * self.public.knockbackForce, 0, kz * self.public.knockbackForce, 2)
    end

    -- Partial cooldown refund if charge was interrupted (it already started)
    if currentState == State.CHARGE or currentState == State.ANTICIPATE_CHG then
        canCharge      = false
        chargeCooldown = self.public.chargeCooldownBase * 0.6
        Engine.Log("[Boss] Charge interrupted – half cooldown")
    end

    -- Reset all mid-ability state
    if attackCol then attackCol:Disable() end
    if nav       then nav:StopMovement()  end
    HardBrakeXZ()

    anticipateTimer     = 0
    attackTimer         = 0
    lungeStopTimer      = 0
    dashTimer           = 0
    chargeTimer         = 0
    playerHitThisAtk    = false
    playerHitThisDash   = false
    playerHitThisChg    = false

    isStunned    = true
    stunTimer    = self.public.stunDuration
    currentState = State.IDLE
    PlayAnim(self.public.animHit, 0.05)
    Engine.Log("[Boss] Stunned " .. self.public.stunDuration .. "s")
end

-- ─────────────────────────────────────────────────────────────────────────
-- DECIDE  – core decision tree; only called from IDLE, WALK, RETREAT
-- ─────────────────────────────────────────────────────────────────────────

local function Decide(self, dist)
    local isClose = (dist <= self.public.closeRange)

    -- ── CLOSE branch ──────────────────────────────────────────────────────
    if isClose then
        if canAttack then
            -- Melee attack
            if nav then nav:StopMovement() end
            RequestBrakeXZ()
            anticipateTimer  = 0
            playerHitThisAtk = false
            PlayAnim(self.public.animAntAtk, 0.10)
            currentState = State.ANTICIPATE_ATK
            Engine.Log("[Boss] CLOSE+canAttack → ANTICIPATE_ATK")

        elseif not canDash then
            -- No attack, no dash: retreat
            if nav then nav:StopMovement() end
            PlayAnim(self.public.animWalk, 0.15)
            currentState = State.RETREAT
            Engine.Log("[Boss] CLOSE+noCooldowns → RETREAT")

        else
            -- No attack but dash ready: hold position, face player, wait
            -- (dash is an approach tool, not used to flee)
            RequestBrakeXZ()
            PlayAnim(self.public.animIdle, 0.20)
            currentState = State.IDLE
        end

    -- ── FAR branch ────────────────────────────────────────────────────────
    else
        if canCharge then
            -- Charge / embestida
            if nav then nav:StopMovement() end
            RequestBrakeXZ()
            anticipateTimer  = 0
            playerHitThisChg = false
            PlayAnim(self.public.animAntChg, 0.10)
            currentState = State.ANTICIPATE_CHG
            Engine.Log("[Boss] FAR+canCharge → ANTICIPATE_CHG")

        elseif canDash then
            -- Dash to close the gap
            if nav then nav:StopMovement() end
            RequestBrakeXZ()
            anticipateTimer  = 0
            playerHitThisDash = false
            PlayAnim(self.public.animAntDash, 0.10)
            currentState = State.ANTICIPATE_DSH
            Engine.Log("[Boss] FAR+canDash → ANTICIPATE_DSH")

        else
            -- Walk via NavMesh while waiting for cooldowns
            if currentState ~= State.WALK then
                navRefreshTimer = 0
                PlayAnim(self.public.animWalk, 0.20)
                currentState = State.WALK
                Engine.Log("[Boss] FAR+noCooldowns → WALK")
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- STATE UPDATES
-- ─────────────────────────────────────────────────────────────────────────

-- IDLE: brake and immediately re-evaluate
local function UpdateIdle(self, dt, dist, plPos)
    RequestBrakeXZ()
    ApplyMoveVelocity(dt, self.public.brakeDecel)
    FaceTargetSmooth(self, plPos, dt)
    Decide(self, dist)
end

-- ── WALK: NavMesh approach, re-evaluate each frame ────────────────────────
local function UpdateWalk(self, dt, dist, plPos)
    -- An ability just became ready, or we are now close → re-decide
    if dist <= self.public.closeRange or canCharge or canDash then
        Decide(self, dist)
        return
    end

    -- Throttled NavMesh destination refresh
    navRefreshTimer = navRefreshTimer - dt
    if navRefreshTimer <= 0 then
        nav:SetDestination(plPos.x, plPos.y, plPos.z)
        navRefreshTimer = self.public.navRefreshRate
    end

    -- Read nav direction and drive via physics (respects NavMesh geometry)
    local dx, dz = nav:GetMoveDirection(0.3)
    SetTargetVelocity(dx, dz, self.public.walkSpeed)
    ApplyMoveVelocity(dt, self.public.moveAccel)

    -- Face movement direction while walking
    if abs(dx) > 0.001 or abs(dz) > 0.001 then
        local p = self.transform.worldPosition
        FaceTargetSmooth(self, { x = p.x + dx, y = p.y, z = p.z + dz }, dt)
    end
end

-- ── RETREAT: physics back-away from player ────────────────────────────────
local function UpdateRetreat(self, dt, dist, plPos)
    local myPos = self.transform.worldPosition

    -- Exit conditions: attack or dash came off cooldown, or far enough away
    local shouldExit = canAttack or canDash or (dist >= self.public.closeRange * 1.6)
    if shouldExit then
        Decide(self, dist)
        return
    end

    -- Move directly away from player using physics
    local rdx, rdz = NormFlat(myPos.x - plPos.x, myPos.z - plPos.z)
    SetTargetVelocity(rdx, rdz, self.public.retreatSpeed)
    ApplyMoveVelocity(dt, self.public.moveAccel)

    -- Keep facing the player while retreating
    FaceTargetSmooth(self, plPos, dt)
end

-- ── ANTICIPATE MELEE ──────────────────────────────────────────────────────
local function UpdateAntAtk(self, dt, plPos)
    anticipateTimer = anticipateTimer + dt
    RequestBrakeXZ()
    ApplyMoveVelocity(dt, self.public.brakeDecel)
    FaceTargetSmooth(self, plPos, dt)

    if anticipateTimer < self.public.anticipateAtkDur then return end

    -- Launch lunge impulse
    local myPos    = self.transform.worldPosition
    local ndx, ndz = NormFlat(plPos.x - myPos.x, plPos.z - myPos.z)
    rb:AddForce(ndx * self.public.attackLungeForce, 0, ndz * self.public.attackLungeForce, 2)

    if attackCol then attackCol:Disable() end
    playerHitThisAtk = false
    attackTimer      = 0
    lungeStopTimer   = self.public.attackLungeStopT

    PlayAnim(self.public.animAttack, 0.05)
    currentState = State.ATTACK
    Engine.Log("[Boss] ANTICIPATE_ATK → ATTACK (lunge)")
end

-- ── ATTACK (melee active) ─────────────────────────────────────────────────
local function UpdateAttack(self, dt, plPos)
    attackTimer    = attackTimer    + dt
    lungeStopTimer = lungeStopTimer - dt

    -- Brake after lunge window
    if lungeStopTimer <= 0 then
        RequestBrakeXZ()
        ApplyMoveVelocity(dt, self.public.brakeDecel)
    end

    -- Activate hitbox after delay
    if attackTimer >= self.public.attackColDelay and attackCol then
        attackCol:Enable()
    end

    -- Proximity hit check (backup if trigger misses)
    if attackTimer >= self.public.attackColDelay and not playerHitThisAtk and playerGO then
        local pp = playerGO.transform.position
        if pp and DistFlat(pp, self.transform.worldPosition) <= self.public.attackRange then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisAtk                   = true
                _PlayerController_pendingDamage    = self.public.attackDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end

    if attackTimer >= self.public.attackDur then
        playerHitThisAtk = false
        if attackCol then attackCol:Disable() end

        -- Start cooldown
        canAttack      = false
        attackCooldown = self.public.attackCooldownBase
        attackTimer    = 0

        Engine.Log("[Boss] ATTACK done → cooldown " .. self.public.attackCooldownBase .. "s")
        currentState = State.IDLE   -- re-decision on next frame
    end
end

-- ── ANTICIPATE DASH ───────────────────────────────────────────────────────
local function UpdateAntDsh(self, dt, plPos)
    anticipateTimer = anticipateTimer + dt
    RequestBrakeXZ()
    ApplyMoveVelocity(dt, self.public.brakeDecel)
    FaceTargetSmooth(self, plPos, dt)

    if anticipateTimer < self.public.anticipateDshDur then return end

    local myPos    = self.transform.worldPosition
    local ndx, ndz = NormFlat(plPos.x - myPos.x, plPos.z - myPos.z)
    rb:AddForce(ndx * self.public.dashForce, 0, ndz * self.public.dashForce, 2)

    playerHitThisDash = false
    dashTimer         = 0

    PlayAnim(self.public.animDash, 0.05)
    currentState = State.DASH
    Engine.Log("[Boss] ANTICIPATE_DSH → DASH (impulse launched)")
end

-- ── DASH (active burst) ───────────────────────────────────────────────────
local function UpdateDash(self, dt)
    dashTimer = dashTimer + dt

    -- Hit check while moving fast
    if not playerHitThisDash and playerGO then
        local pp = playerGO.transform.position
        if pp and DistFlat(pp, self.transform.worldPosition) <= self.public.dashHitRadius then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisDash                  = true
                _PlayerController_pendingDamage    = self.public.dashDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end

    if dashTimer >= self.public.dashDur then
        HardBrakeXZ()
        playerHitThisDash = false

        canDash      = false
        dashCooldown = self.public.dashCooldownBase
        dashTimer    = 0

        Engine.Log("[Boss] DASH done → cooldown " .. self.public.dashCooldownBase .. "s")
        currentState = State.IDLE
    end
end

-- ── ANTICIPATE CHARGE ─────────────────────────────────────────────────────
local function UpdateAntChg(self, dt, plPos)
    anticipateTimer = anticipateTimer + dt
    RequestBrakeXZ()
    ApplyMoveVelocity(dt, self.public.brakeDecel)
    FaceTargetSmooth(self, plPos, dt)

    if anticipateTimer < self.public.anticipateChgDur then return end

    local myPos    = self.transform.worldPosition
    local ndx, ndz = NormFlat(plPos.x - myPos.x, plPos.z - myPos.z)
    rb:AddForce(ndx * self.public.chargeForce, 0, ndz * self.public.chargeForce, 2)

    playerHitThisChg = false
    chargeTimer      = 0

    PlayAnim(self.public.animCharge, 0.05)
    currentState = State.CHARGE
    Engine.Log("[Boss] ANTICIPATE_CHG → CHARGE (embestida!)")
end

-- ── CHARGE / EMBESTIDA (active) ───────────────────────────────────────────
local function UpdateCharge(self, dt)
    chargeTimer = chargeTimer + dt

    -- Hit check — charge deals heavy damage + knockback on first contact
    if not playerHitThisChg and playerGO then
        local pp = playerGO.transform.position
        if pp and DistFlat(pp, self.transform.worldPosition) <= self.public.chargeHitRadius then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                playerHitThisChg                   = true
                _PlayerController_pendingDamage    = self.public.chargeDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end

    if chargeTimer >= self.public.chargeDur then
        HardBrakeXZ()
        playerHitThisChg = false

        canCharge      = false
        chargeCooldown = self.public.chargeCooldownBase
        chargeTimer    = 0

        Engine.Log("[Boss] CHARGE done → cooldown " .. self.public.chargeCooldownBase .. "s")
        currentState = State.IDLE
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- START
-- ─────────────────────────────────────────────────────────────────────────

function Start(self)
    hp           = self.public.maxHp
    isDead       = false
    pendingDeath = false
    isStunned    = false
    stunTimer    = 0

    canAttack      = true
    canDash        = true
    canCharge      = true
    attackCooldown = 0
    dashCooldown   = 0
    chargeCooldown = 0

    anticipateTimer   = 0
    attackTimer       = 0
    lungeStopTimer    = 0
    dashTimer         = 0
    chargeTimer       = 0
    navRefreshTimer   = 0

    playerHitThisAtk  = false
    playerHitThisDash = false
    playerHitThisChg  = false
    alreadyHit        = false

    targetVelX = 0
    targetVelZ = 0
    currentYaw = (self.transform.worldRotation and self.transform.worldRotation.y) or 0
    currentState = State.IDLE

    nav       = self.gameObject:GetComponent("Navigation")
    rb        = self.gameObject:GetComponent("Rigidbody")
    anim      = self.gameObject:GetComponent("Animation")
    attackCol = self.gameObject:GetComponent("Box Collider")

    attackSource = GameObject.Find("Boss_AttackSource")
    dieSource    = GameObject.Find("Boss_DieSource")
    hurtSource   = GameObject.Find("Boss_HurtSource")
    if attackSource then Boss.attackSFX = attackSource:GetComponent("Audio Source") end
    if dieSource    then Boss.dieSFX    = dieSource:GetComponent("Audio Source")    end
    if hurtSource   then Boss.hurtSFX   = hurtSource:GetComponent("Audio Source")   end

    PlayAnim(self.public.animIdle, 0.0)
    Engine.Log("[Boss] Start OK  HP=" .. hp)
end

-- ─────────────────────────────────────────────────────────────────────────
-- UPDATE
-- ─────────────────────────────────────────────────────────────────────────

function Update(self, dt)
    if isDead then return end

    -- ── Death flush ───────────────────────────────────────────────────────
    if pendingDeath then
        if nav then nav:StopMovement() end
        if rb  then HardBrakeXZ() end
        if attackCol then attackCol:Disable() end
        currentState = State.DEAD
        isDead       = true
        PlayAnim(self.public.animDeath, 0.05)
        Engine.Log("[Boss] DEAD")
        self:Destroy()
        return
    end

    -- ── Pending damage from external table ────────────────────────────────
    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
        if isDead or pendingDeath then return end
    end

    -- ── Stun ──────────────────────────────────────────────────────────────
    if isStunned then
        stunTimer = stunTimer - dt
        HardBrakeXZ()
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Boss] Stun over")
        end
        return
    end

    -- ── Tick cooldowns ────────────────────────────────────────────────────
    TickCooldowns(dt)

    -- ── Component safety re-fetch ─────────────────────────────────────────
    if not nav or not rb then
        nav = self.gameObject:GetComponent("Navigation")
        rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not playerGO then
        playerGO = GameObject.Find("Player")
        if not playerGO then
            RequestBrakeXZ()
            ApplyMoveVelocity(dt, self.public.brakeDecel)
            return
        end
    end

    -- ── Player attack polling (Mode A — polling global) ───────────────────
    local lastAtk = _PlayerController_lastAttack
    if lastAtk ~= nil and lastAtk ~= "" then
        if not alreadyHit then
            local myPos = self.transform.worldPosition
            local pp    = playerGO.transform.position
            if pp and DistFlat(myPos, pp) <= self.public.attackRange + 1.8 then
                alreadyHit = true
                if     lastAtk == "light"  then TakeDamage(self, 10, pp)
                elseif lastAtk == "heavy" or lastAtk == "charge" then TakeDamage(self, 25, pp)
                end
                if isDead or pendingDeath then return end
            end
        end
    else
        alreadyHit = false
    end

    -- ── Gather positions for this frame ───────────────────────────────────
    local myPos = self.transform.worldPosition
    local plPos = playerGO.transform.worldPosition
    local dist  = DistFlat(myPos, plPos)

    -- ── State dispatch ────────────────────────────────────────────────────
    if     currentState == State.IDLE           then UpdateIdle(self, dt, dist, plPos)
    elseif currentState == State.WALK           then UpdateWalk(self, dt, dist, plPos)
    elseif currentState == State.RETREAT        then UpdateRetreat(self, dt, dist, plPos)
    elseif currentState == State.ANTICIPATE_ATK then UpdateAntAtk(self, dt, plPos)
    elseif currentState == State.ATTACK         then UpdateAttack(self, dt, plPos)
    elseif currentState == State.ANTICIPATE_DSH then UpdateAntDsh(self, dt, plPos)
    elseif currentState == State.DASH           then UpdateDash(self, dt)
    elseif currentState == State.ANTICIPATE_CHG then UpdateAntChg(self, dt, plPos)
    elseif currentState == State.CHARGE         then UpdateCharge(self, dt)
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- TRIGGER EVENTS
-- ─────────────────────────────────────────────────────────────────────────

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then

        -- ── Player hits the boss ─────────────────────────────────────────
        if not alreadyHit then
            local atk = _PlayerController_lastAttack
            if atk ~= nil and atk ~= "" then
                alreadyHit = true
                local ap = other.transform.worldPosition
                if     atk == "light"  then TakeDamage(self, 10, ap)
                elseif atk == "heavy" or atk == "charge" then TakeDamage(self, 25, ap)
                end
                if isDead or pendingDeath then return end
            end
        end

        -- ── Boss hits the player (only during active abilities) ───────────
        local pending = _PlayerController_pendingDamage or 0
        if pending == 0 then
            if currentState == State.ATTACK and not playerHitThisAtk then
                playerHitThisAtk                   = true
                _PlayerController_pendingDamage    = self.public.attackDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition

            elseif currentState == State.DASH and not playerHitThisDash then
                playerHitThisDash                  = true
                _PlayerController_pendingDamage    = self.public.dashDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition

            elseif currentState == State.CHARGE and not playerHitThisChg then
                playerHitThisChg                   = true
                _PlayerController_pendingDamage    = self.public.chargeDamage
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end
    end
end

function OnTriggerExit(self, other) end