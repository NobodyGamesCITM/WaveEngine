-- ============================================================
--  EnemyBase.lua  –  Tunic-style enemy
--
--  State machine:
--    IDLE ──► PATROL ──► CHASE ──► ORBIT ──► ANTICIPATE ──► ATTACK
--               ▲           ▲        │                         │
--               │           └────────┘  (player escapes)       │
--               └──────────────────────────────────────────────┘
--                              (cooldown → ORBIT if still close, else CHASE)
--
--  ORBIT sub-phases (no navmesh, pure physics):
--    NEUTRAL  – standard strafe + radial sine pulse
--    PRESSURE – player idle/slow → close in, tighter radius
--    RETREAT  – player just swung → backpedal fast, then punish if swing ends
--    FEINT    – fake wind-up to bait a roll, then resume orbit
--
--  The enemy reads _PlayerController_lastAttack and estimates player speed
--  from frame-to-frame position to decide which sub-phase to use.
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

-- ── States ───────────────────────────────────────────────────────────────
local State = {
    IDLE       = "Idle",
    PATROL     = "Patrol",
    CHASE      = "Chase",
    ORBIT      = "Orbit",
    DODGE      = "Dodge",      -- predictive sidestep before the player hits
    ANTICIPATE = "Anticipate",
    ATTACK     = "Attack",
    DEAD       = "Dead",
}

-- ── Orbit sub-phases ─────────────────────────────────────────────────────
local OrbitPhase = {
    NEUTRAL  = "Neutral",   -- standard circling + sine pulse
    PRESSURE = "Pressure",  -- player slow/idle → close in
    RETREAT  = "Retreat",   -- player attacked  → backpedal
    FEINT    = "Feint",     -- fake wind-up     → bait roll
}

-- ── Global interop ────────────────────────────────────────────────────────
_EnemyDamage_skeleton = 20

-- ── Public parameters ─────────────────────────────────────────────────────
public = {
    maxHp           = 30,

    -- Movement
    -- Player walks 15 m/s, sprints 25. Enemy chaseSpeed of 6.5 closes on an
    -- idle/walking player but cannot outrun a sprinting one → forces orbit.
    patrolSpeed     = 1.5,
    chaseSpeed      = 3.5,
    lungeForce      = 11.0,
    moveAccel       = 18.0,
    brakeDecel      = 14.0,
    rotationSpeed   = 4.0,

    -- NavMesh
    navRefreshRate  = 0.18,

    -- Detection
    aggroRadius     = 8.0,
    deaggroRadius   = 14.0,
    attackRange     = 2.0,    -- hitbox polling radius

    -- ── Orbit base ────────────────────────────────────────────────────────
    -- Player walks at 15 m/s so the orbit entry is generous.
    -- orbitRadius (3.2) sits just outside the player's polling range
    -- (attackRange + 1.5 = 3.5) so the player has to close in to hit.
    orbitTriggerDist  = 5.0,
    orbitRadius       = 3.2,
    orbitSpeed        = 2.2,
    orbitCorrSpeed    = 5.0,
    orbitCorrMaxFrac  = 0.6,
    orbitDurMin       = 1.2,
    orbitDurMax       = 2.5,
    orbitDirFlipMin   = 0.5,
    orbitDirFlipMax   = 1.5,
    orbitDirFlipChance= 0.40,

    -- ── PRESSURE (player idle / slow) ────────────────────────────────────
    -- Player velocity is either ~0 (idle) or 15+ (walking). A threshold of
    -- 5.0 cleanly catches idle without triggering on walking.
    -- exitSpeed of 8.0 cancels pressure as soon as the player takes even
    -- a few steps (walk = 15 >> 8).
    pressureSpeedThresh = 5.0,
    pressureRadius      = 1.8,
    pressureSpeed       = 2.5,
    pressureEnterTime   = 0.4,
    pressureExitSpeed   = 8.0,

    retreatSpeed     = 3.5,
    retreatDur       = 0.9,
    punishWindow     = 0.3,

    -- ── FEINT ─────────────────────────────────────────────────────────────
    -- feintDur (0.18) is ~40 % of real anticipateDur (0.45) — a consistent,
    -- learnable difference for an attentive player.
    feintDur         = 0.18,
    feintCoolMin     = 4.0,
    feintCoolMax     = 7.0,
    feintChance      = 0.15,

    -- ── Dodge (predictive) ────────────────────────────────────────────────
    -- Player walk = 15 m/s, sprint = 25. Approach threshold of 10 triggers
    -- when the player is moving directly at the enemy at any speed (walk or
    -- sprint), but NOT on glancing passes.
    -- dodgeDur (0.28) is about ¼ of player rollDuration (1.0), feeling snappy
    -- rather than a full evasion.
    -- dodgeCooldown (2.5) lets the player land 3-4 attacks between dodges.
    dodgeChance         = 0.15,
    dodgeApproachThresh = 10.0,
    dodgeThreatDist     = 4.5,
    dodgeImpulse        = 12.0,
    dodgeSideRatio      = 0.75,
    dodgeDur            = 0.28,
    dodgeCooldown       = 2.5,
    dodgeInvincible     = false,
    animDodge           = "Roll",

    -- ── Attack timing ─────────────────────────────────────────────────────
    -- anticipateDur (0.4) < player attackDuration (0.8): the enemy commits
    -- before the player can safely finish their own swing.
    -- stunDuration (0.45) ≈ player attackDuration (0.8 / 2 + buffer): enemy
    -- stays stunned long enough for the player to land exactly one follow-up
    -- hit before the enemy recovers.
    -- cooldownBase (1.8) gives the player ~3 full attack cycles to punish.
    anticipateDur   = 0.75,
    attackDur       = 0.45,
    attackColDelay  = 0.18,
    lungeStopDelay  = 0.30,
    cooldownBase    = 3.0,
    cooldownRage    = 2.0,

    attackDamage    = 20,
    knockbackForce  = 6.0,
    stunDuration    = 0.80,
    hitReactDelay   = 0.15,   -- seconds between detecting player attack and applying damage

    -- Patrol
    patrolWaitMin   = 1.0,
    patrolWaitMax   = 2.8,

    -- Anims
    animIdle        = "Idle",
    animWalk        = "Walk",
    animAnticipate  = "Anticipate",
    animAttack      = "Attack",
    animHit         = "Hit",
    animDeath       = "Death",
}

-- ── Runtime state ─────────────────────────────────────────────────────────
local currentState = State.IDLE
local hp           = 0

local isDead       = false
local pendingDeath = false

local isStunned = false
local stunTimer = 0

local patrolWait = 0

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

-- Sub-phase
local orbitSubPhase    = OrbitPhase.NEUTRAL
local retreatTimer     = 0       -- countdown for RETREAT duration
local punishTimer      = 0       -- countdown for punish window
local feintTimer       = 0       -- countdown for FEINT duration
local feintCooldown    = 0       -- countdown until next feint check

-- Pressure accumulator (player must be slow for pressureEnterTime before entering)
local pressureAccum  = 0

-- ── Player reading ────────────────────────────────────────────────────────
local playerSpeedEst    = 0      -- smoothed estimate of player speed (m/s)
local playerPrevX       = 0
local playerPrevZ       = 0
local playerWasAttacking = false -- state of _PlayerController_lastAttack last frame

-- ── Dodge runtime ─────────────────────────────────────────────────────────
local dodgeTimer        = 0      -- counts down dodge duration
local dodgeCoolTimer    = 0      -- counts down between-dodge cooldown
local dodgeVelX         = 0      -- locked impulse direction X during dodge
local dodgeVelZ         = 0      -- locked impulse direction Z during dodge
local stateBeforeDodge  = nil    -- state to return to after dodge ends
local playerApproachSpd = 0      -- smoothed player approach speed toward enemy

-- ── NavMesh throttle ──────────────────────────────────────────────────────
local navRefreshTimer = 0

-- ── Hit detection ─────────────────────────────────────────────────────────
local playerAttackHandled = false  -- true once the current player attack has been registered
local alreadyHit          = false  -- true once the trigger path registered this attack

-- ── Delayed player-hit queue ──────────────────────────────────────────────
-- Instead of calling TakeDamage immediately on detection, we wait hitReactDelay
-- seconds so the damage lands in sync with the player's attack animation.
local pendingPlayerDmg    = 0     -- damage amount queued (0 = nothing pending)
local pendingPlayerDmgPos = nil   -- attacker position for knockback
local hitReactTimer       = 0     -- counts down to zero, then damage fires

-- ── Components ────────────────────────────────────────────────────────────
local nav       = nil
local rb        = nil
local anim      = nil
local attackCol = nil
local playerGO  = nil

local targetVelX = 0
local targetVelZ = 0
local currentYaw = 0

local Enemy = { attackSFX=nil, dieSFX=nil, hurtSFX=nil, stepSFX=nil }

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

-- Returns true if the player (at playerPos, facing playerYawDeg) is looking
-- toward enemyPos within the given dot-product threshold.
--   dotThresh = 0.0  → 90° half-cone (180° total frontal arc)  ← used here
--   dotThresh = 0.5  → 60° half-cone (stricter)
-- Convention: yaw 0 = +Z forward, same as FaceTargetSmooth / rb:SetRotation.
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

local function GetAttackCooldown(self)
    return hp/self.public.maxHp < 0.5 and self.public.cooldownRage or self.public.cooldownBase
end

-- Physics helpers
local function SetTargetVelocity(dx, dz, speed)
    targetVelX = dx * speed
    targetVelZ = dz * speed
end

local function ApplyMoveVelocity(dt, accelRate)
    local vel  = rb:GetLinearVelocity()
    rb:SetLinearVelocity(Lerp(vel.x, targetVelX, dt*accelRate),
                         vel.y,
                         Lerp(vel.z, targetVelZ, dt*accelRate))
end

local function RequestBrakeXZ(self)
    targetVelX = 0;  targetVelZ = 0;  _ = self
end

local function HardBrakeXZ()
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y or 0, 0)
    targetVelX = 0;  targetVelZ = 0
end

-- Smooth rotation
local function FaceTargetSmooth(self, target, dt)
    local p  = self.transform.worldPosition
    local dx = target.x - p.x
    local dz = target.z - p.z
    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end

    local desiredYaw = atan2(dx, dz) * (180/pi)
    local delta      = desiredYaw - currentYaw
    delta = delta - math.floor((delta+180)/360)*360

    local turn = Clamp(delta, -self.public.rotationSpeed*dt*60, self.public.rotationSpeed*dt*60)
    currentYaw = currentYaw + turn
    rb:SetRotation(0, currentYaw, 0)
end

local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

-- ─────────────────────────────────────────────────────────────────────────
-- TAKEDAMAGE
-- ─────────────────────────────────────────────────────────────────────────

-- Queues player-inflicted damage to fire after hitReactDelay seconds.
-- Only one hit can be queued at a time; the alreadyHit / playerAttackHandled
-- flags guarantee this is called at most once per player attack.
local function QueuePlayerDamage(self, amount, attackerPos)
    pendingPlayerDmg    = amount
    pendingPlayerDmgPos = attackerPos
    hitReactTimer       = self.public.hitReactDelay
    Engine.Log("[Enemy] Damage queued: " .. amount .. " (fires in " .. self.public.hitReactDelay .. "s)")
end

local function TakeDamage(self, amount, attackerPos)
    if isDead or not hp then return end
    -- Ignore hits during a successful dodge (invincibility frames)
    if currentState == State.DODGE and self.public.dodgeInvincible then
        Engine.Log("[Enemy] HIT ignored – dodging")
        return
    end

    hp = hp - amount
    Engine.Log("[Enemy] HP: " .. hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if rb and attackerPos then
        local ep      = self.transform.worldPosition
        local dx, dz  = NormFlat(ep.x-attackerPos.x, ep.z-attackerPos.z)
        rb:AddForce(dx*self.public.knockbackForce, 0, dz*self.public.knockbackForce, 2)
    end

    if hp <= 0 and not pendingDeath then
        pendingDeath = true
    else
        isStunned           = true
        stunTimer           = self.public.stunDuration
        isAttacking         = false
        playerHitThisAttack = false
        anticipateTimer     = 0
        lungeStopTimer      = 0
        orbitTimer          = 0
        orbitSubPhase       = OrbitPhase.NEUTRAL

        if attackCol then attackCol:Disable() end
        if nav       then nav:StopMovement()  end
        HardBrakeXZ()
        PlayAnim(self.public.animHit, 0.05)
        Engine.Log("[Enemy] STUNNED " .. self.public.stunDuration .. "s")
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- STATE UPDATES
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
            + math.random()*(self.public.patrolWaitMax - self.public.patrolWaitMin)
        currentState = State.IDLE
        return
    end

    local dx, dz = nav:GetMoveDirection(0.3)
    SetTargetVelocity(dx, dz, self.public.patrolSpeed)
    ApplyMoveVelocity(dt, self.public.moveAccel)
    if abs(dx)>0.001 or abs(dz)>0.001 then
        local p = self.transform.worldPosition
        FaceTargetSmooth(self, {x=p.x+dx, y=p.y, z=p.z+dz}, dt)
    end
end

local function UpdateChase(self, dt)
    if not playerGO then currentState = State.IDLE; return end

    local myPos = self.transform.worldPosition
    local plPos = playerGO.transform.worldPosition
    local dist  = DistFlat(myPos, plPos)

    if dist > self.public.deaggroRadius then
        nav:StopMovement(); RequestBrakeXZ(self)
        PlayAnim(self.public.animIdle, 0.3)
        currentState = State.IDLE
        return
    end

    if dist <= self.public.orbitTriggerDist and not isOnCooldown then
        nav:StopMovement()
        orbitDir      = (math.random() < 0.5) and 1 or -1
        orbitTimer    = 0
        orbitDur      = self.public.orbitDurMin
            + math.random()*(self.public.orbitDurMax - self.public.orbitDurMin)
        orbitDirTimer = self.public.orbitDirFlipMin
            + math.random()*(self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
        orbitSubPhase = OrbitPhase.NEUTRAL
        pressureAccum = 0
        feintCooldown = self.public.feintCoolMin
            + math.random()*(self.public.feintCoolMax - self.public.feintCoolMin)
        PlayAnim(self.public.animWalk, 0.2)
        currentState = State.ORBIT
        Engine.Log("[Enemy] CHASE → ORBIT")
        return
    end

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
-- Four sub-phases, each driven by reading the player:
--
--  NEUTRAL  : Standard strafe + radial sine pulse (organic breathing motion)
--  PRESSURE : Player speed < pressureSpeedThresh for > pressureEnterTime
--             → Tighten radius and speed up strafe to force reaction
--  RETREAT  : _PlayerController_lastAttack just went non-empty (player swung)
--             → Back away fast; if attack ends during retreat → PUNISH commit
--  FEINT    : Random fake anticipate animation; aborts after feintDur
--             → Forces player to read the FULL wind-up, not just react to anim
--
-- All movement is pure physics. NavMesh agent stays stopped.
-- Rigidbody colliders handle wall collisions naturally.
--
local function UpdateOrbit(self, dt)
    if not playerGO then currentState = State.IDLE; return end

    local myPos      = self.transform.worldPosition
    local plPos      = playerGO.transform.worldPosition
    local dist       = DistFlat(myPos, plPos)
    local isAttacking_player = (_PlayerController_lastAttack ~= nil
                                 and _PlayerController_lastAttack ~= "")

    -- ── Always face the player ─────────────────────────────────────────────
    FaceTargetSmooth(self, plPos, dt)

    -- ── Global exit conditions ─────────────────────────────────────────────
    if dist > self.public.deaggroRadius then
        RequestBrakeXZ(self)
        PlayAnim(self.public.animIdle, 0.3)
        currentState = State.IDLE
        Engine.Log("[Enemy] ORBIT → IDLE (deaggro)")
        return
    end

    if dist > self.public.orbitTriggerDist * 1.6 then
        navRefreshTimer = 0
        PlayAnim(self.public.animWalk, 0.2)
        currentState = State.CHASE
        Engine.Log("[Enemy] ORBIT → CHASE (player escaped)")
        return
    end

    -- ── Feint cooldown tick ────────────────────────────────────────────────
    if orbitSubPhase ~= OrbitPhase.FEINT then
        feintCooldown = feintCooldown - dt
    end

    -- ── Sub-phase: RETREAT ─────────────────────────────────────────────────
    -- Triggered when player starts attacking.  Enemy instantly backs away.
    -- If the player's swing ends while we're still retreating, we get a short
    -- PUNISH window (commit to ANTICIPATE immediately).
    if orbitSubPhase == OrbitPhase.RETREAT then
        retreatTimer = retreatTimer - dt

        -- Detect: player attack just ended → punish window
        if playerWasAttacking and not isAttacking_player then
            punishTimer = self.public.punishWindow
        end
        if punishTimer > 0 then
            punishTimer = punishTimer - dt
            if punishTimer > 0 then
                -- Commit! Player left themselves open.
                RequestBrakeXZ(self)
                ApplyMoveVelocity(dt, self.public.brakeDecel)
                anticipateTimer = 0
                PlayAnim(self.public.animAnticipate, 0.05)
                currentState = State.ANTICIPATE
                Engine.Log("[Enemy] ORBIT PUNISH → ANTICIPATE (player attack ended)")
                return
            end
        end

        if retreatTimer <= 0 or not isAttacking_player then
            -- Retreat over: reset orbit timer slightly so enemy circles a bit more
            orbitTimer    = math.max(0, orbitDur - 0.4)
            orbitSubPhase = OrbitPhase.NEUTRAL
            Engine.Log("[Enemy] RETREAT → NEUTRAL")
        else
            -- Back away from the player
            local rdx, rdz = NormFlat(myPos.x - plPos.x, myPos.z - plPos.z)
            targetVelX = rdx * self.public.retreatSpeed
            targetVelZ = rdz * self.public.retreatSpeed
            ApplyMoveVelocity(dt, self.public.moveAccel)
        end

        playerWasAttacking = isAttacking_player
        return
    end

    -- ── Sub-phase: FEINT ──────────────────────────────────────────────────
    -- Freeze and play anticipate anim briefly, then abort.
    if orbitSubPhase == OrbitPhase.FEINT then
        feintTimer = feintTimer - dt
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)

        if feintTimer <= 0 then
            -- Feint over: reset orbit so player gets a bit more circling
            orbitTimer    = 0
            orbitDur      = self.public.orbitDurMin
                + math.random()*(self.public.orbitDurMax - self.public.orbitDurMin)
            feintCooldown = self.public.feintCoolMin
                + math.random()*(self.public.feintCoolMax - self.public.feintCoolMin)
            orbitSubPhase = OrbitPhase.NEUTRAL
            PlayAnim(self.public.animWalk, 0.2)
            Engine.Log("[Enemy] FEINT aborted → NEUTRAL")
        end

        playerWasAttacking = isAttacking_player
        return
    end

    -- ── Detect player attack start → RETREAT ─────────────────────────────
    if isAttacking_player and not playerWasAttacking then
        orbitSubPhase = OrbitPhase.RETREAT
        retreatTimer  = self.public.retreatDur
        punishTimer   = 0
        Engine.Log("[Enemy] Player attacked → RETREAT")
        playerWasAttacking = isAttacking_player
        return
    end

    -- ── Sub-phase: PRESSURE / NEUTRAL decision ────────────────────────────
    if playerSpeedEst < self.public.pressureSpeedThresh then
        pressureAccum = pressureAccum + dt
    else
        pressureAccum = math.max(0, pressureAccum - dt * 2)
    end

    local inPressure = (pressureAccum >= self.public.pressureEnterTime)

    if playerSpeedEst > self.public.pressureExitSpeed then
        -- Player moving fast toward/away → cancel pressure, normal orbit
        pressureAccum = 0
        inPressure    = false
    end

    if inPressure then
        orbitSubPhase = OrbitPhase.PRESSURE
    elseif orbitSubPhase == OrbitPhase.PRESSURE then
        orbitSubPhase = OrbitPhase.NEUTRAL
    end

    -- ── Commit to attack when timer expires ───────────────────────────────
    if orbitTimer >= orbitDur then
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)
        anticipateTimer = 0
        PlayAnim(self.public.animAnticipate, 0.05)
        currentState = State.ANTICIPATE
        Engine.Log("[Enemy] ORBIT → ANTICIPATE (timer)")
        return
    end

    -- ── Feint check ───────────────────────────────────────────────────────
    if feintCooldown <= 0 then
        if math.random() < self.public.feintChance then
            orbitSubPhase = OrbitPhase.FEINT
            feintTimer    = self.public.feintDur
            PlayAnim(self.public.animAnticipate, 0.05)
            Engine.Log("[Enemy] FEINT started")
            playerWasAttacking = isAttacking_player
            return
        end
        -- Chance failed: reset cooldown and try again later
        feintCooldown = self.public.feintCoolMin
            + math.random()*(self.public.feintCoolMax - self.public.feintCoolMin)
    end

    -- ── Occasional direction flip ─────────────────────────────────────────
    orbitDirTimer = orbitDirTimer - dt
    if orbitDirTimer <= 0 then
        if math.random() < self.public.orbitDirFlipChance then
            orbitDir = -orbitDir
        end
        orbitDirTimer = self.public.orbitDirFlipMin
            + math.random()*(self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
    end

    -- ── Velocity composition ──────────────────────────────────────────────
    -- Choose radius and speed based on sub-phase
    local activeRadius = self.public.orbitRadius
    local activeSpeed  = self.public.orbitSpeed
    if orbitSubPhase == OrbitPhase.PRESSURE then
        activeRadius = self.public.pressureRadius
        activeSpeed  = self.public.pressureSpeed
    end

    -- Radial unit vector (enemy away from player)
    local rdx, rdz = NormFlat(myPos.x - plPos.x, myPos.z - plPos.z)

    -- Tangential unit vector
    local tdx, tdz
    if orbitDir > 0 then tdx, tdz = -rdz,  rdx
    else                  tdx, tdz =  rdz, -rdx  end

    -- Radial spring toward activeRadius
    local error   = dist - activeRadius
    local corrMax = activeSpeed * self.public.orbitCorrMaxFrac
    local corrVel = Clamp(-error * self.public.orbitCorrSpeed, -corrMax, corrMax)

    -- Sine pulse: organic in/out breathing (only in NEUTRAL; PRESSURE is more focused)
    local pulse = 0
    if orbitSubPhase == OrbitPhase.NEUTRAL then
        pulse = math.sin(orbitTimer * 5.0) * activeSpeed * 0.4
    end

    local radialTotal = corrVel + pulse
    local blendX      = tdx * activeSpeed + rdx * radialTotal
    local blendZ      = tdz * activeSpeed + rdz * radialTotal

    -- Renormalise to activeSpeed
    local bLen = sqrt(blendX*blendX + blendZ*blendZ)
    if bLen > 0.001 then
        blendX = (blendX/bLen) * activeSpeed
        blendZ = (blendZ/bLen) * activeSpeed
    end

    targetVelX = blendX
    targetVelZ = blendZ
    ApplyMoveVelocity(dt, self.public.moveAccel)

    orbitTimer         = orbitTimer + dt
    playerWasAttacking = isAttacking_player
end

-- ── DODGE ─────────────────────────────────────────────────────────────────
--
-- Pure physics sidestep.  Direction is chosen as the lateral vector
-- perpendicular to the player→enemy axis, biased toward the side that
-- creates more space (i.e. away from the player's movement direction).
-- A small backward component is added so the enemy doesn't just slide
-- along the player's sword arc.
--
-- While dodging the enemy keeps facing the player so it looks intentional.
--
local function UpdateDodge(self, dt)
    dodgeTimer = dodgeTimer - dt

    -- Lock velocity to the pre-computed dodge direction the whole time.
    -- Use a high accel rate so the rigidbody snaps to it immediately.
    targetVelX = dodgeVelX
    targetVelZ = dodgeVelZ
    ApplyMoveVelocity(dt, self.public.moveAccel * 2)

    -- Keep facing the player during the dodge
    if playerGO then
        FaceTargetSmooth(self, playerGO.transform.worldPosition, dt)
    end

    if dodgeTimer <= 0 then
        -- Dodge finished: coast to a stop then resume previous state
        RequestBrakeXZ(self)
        dodgeCoolTimer = self.public.dodgeCooldown

        local resume = stateBeforeDodge or State.ORBIT
        if resume == State.ORBIT then
            -- Re-enter orbit cleanly
            orbitTimer    = 0
            orbitDur      = self.public.orbitDurMin
                + math.random()*(self.public.orbitDurMax - self.public.orbitDurMin)
            orbitSubPhase = OrbitPhase.NEUTRAL
            pressureAccum = 0
        elseif resume == State.CHASE then
            navRefreshTimer = 0
        end

        PlayAnim(self.public.animWalk, 0.15)
        currentState = resume
        Engine.Log("[Enemy] DODGE finished → " .. resume)
    end
end

-- ── TryDodge ──────────────────────────────────────────────────────────────
-- Called once per frame in Update (before state dispatch) when the enemy is
-- in a state where a dodge is meaningful (ORBIT, CHASE, ANTICIPATE).
--
-- Prediction model:
--   approachSpeed = dot(playerVelocity, normalize(enemyPos – playerPos))
--
-- A positive value means the player is closing in on the enemy.
-- When this crosses dodgeApproachThresh and the player is within
-- dodgeThreatDist, we roll dodgeChance to fire the dodge.
--
-- This fires BEFORE any attack lands – it reads intent from movement,
-- exactly as Tunic enemies do.
--
local function TryDodge(self, dt, playerPos, myPos)
    if dodgeCoolTimer > 0 then return false end
    if isDead or isStunned   then return false end

    -- Only dodge from these states
    if currentState ~= State.ORBIT
    and currentState ~= State.CHASE
    and currentState ~= State.ANTICIPATE then
        return false
    end

    local dist = DistFlat(myPos, playerPos)
    if dist > self.public.dodgeThreatDist then return false end

    -- Approach speed: positive = player moving toward enemy
    -- playerApproachSpd is maintained in Update from position delta
    if playerApproachSpd < self.public.dodgeApproachThresh then return false end

    -- Roll the chance
    if math.random() > self.public.dodgeChance then return false end

    -- ── Choose dodge direction ─────────────────────────────────────────────
    -- Lateral axis: perpendicular to the player→enemy vector.
    -- We pick the side that moves away from the player's velocity projection.
    local rdx, rdz = NormFlat(myPos.x - playerPos.x, myPos.z - playerPos.z)

    -- Two candidate lateral directions
    local latX1, latZ1 =  rdz, -rdx   -- left relative to enemy facing player
    local latX2, latZ2 = -rdz,  rdx   -- right

    -- Player velocity direction (from playerPrevPos stored in Update)
    -- Dot with each lateral to find which side the player is NOT heading
    local pvX = playerPos.x - playerPrevX
    local pvZ = playerPos.z - playerPrevZ
    local dot1 = pvX*latX1 + pvZ*latZ1
    local dot2 = pvX*latX2 + pvZ*latZ2

    -- Choose the lateral that the player's velocity is LESS aligned with
    -- (i.e. the "open" side, harder for the player to follow)
    local lx, lz
    if dot1 <= dot2 then lx, lz = latX1, latZ1
    else                  lx, lz = latX2, latZ2  end

    -- Blend lateral + slight backward component
    local s = self.public.dodgeSideRatio
    local bx = lx * s + (-rdx) * (1 - s)   -- lateral + inward-of-player (slight retreat)
    local bz = lz * s + (-rdz) * (1 - s)
    local bl = sqrt(bx*bx + bz*bz)
    if bl > 0.001 then bx = bx/bl; bz = bz/bl end

    -- Lock the velocity for the duration of the dodge
    dodgeVelX       = bx * self.public.dodgeImpulse
    dodgeVelZ       = bz * self.public.dodgeImpulse
    dodgeTimer      = self.public.dodgeDur
    stateBeforeDodge = currentState

    -- Fire an immediate impulse AND lock velocity for the whole dodge arc
    rb:AddForce(bx * self.public.dodgeImpulse * 0.5, 0,
                bz * self.public.dodgeImpulse * 0.5, 2)

    if nav then nav:StopMovement() end
    PlayAnim(self.public.animDodge, 0.05)
    currentState = State.DODGE
    Engine.Log("[Enemy] DODGE triggered (approachSpd="
               .. string.format("%.1f", playerApproachSpd) .. ")")
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

    local myPos    = self.transform.worldPosition
    local plPos    = playerGO and playerGO.transform.worldPosition or myPos
    local ndx, ndz = NormFlat(plPos.x-myPos.x, plPos.z-myPos.z)

    rb:AddForce(ndx*self.public.lungeForce, 0, ndz*self.public.lungeForce, 2)
    targetVelX = ndx * self.public.lungeForce * 0.5
    targetVelZ = ndz * self.public.lungeForce * 0.5

    if attackCol then attackCol:Disable() end
    playerHitThisAttack = false
    isAttacking         = true
    attackTimer         = 0
    lungeStopTimer      = self.public.lungeStopDelay

    PlayAnim(self.public.animAttack, 0.05)
    currentState = State.ATTACK
    Engine.Log("[Enemy] ANTICIPATE → ATTACK (lunge!)")
end

-- ── ATTACK ────────────────────────────────────────────────────────────────
local function UpdateAttack(self, dt)
    attackTimer    = attackTimer    + dt
    lungeStopTimer = lungeStopTimer - dt

    if lungeStopTimer <= 0 then
        RequestBrakeXZ(self)
        ApplyMoveVelocity(dt, self.public.brakeDecel)
    end

    if attackTimer >= self.public.attackColDelay and attackCol then
        attackCol:Enable()
    end

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
        cooldownTimer = GetAttackCooldown(self) + math.random() * 0.8

        -- If still close enough, go straight back to orbit instead of full chase
        local dist = playerGO and DistFlat(self.transform.worldPosition,
                                           playerGO.transform.worldPosition) or 999
        if dist <= self.public.orbitTriggerDist * 1.3 then
            orbitDir      = -orbitDir     -- flip side so it doesn't just repeat
            orbitTimer    = 0
            orbitDur      = self.public.orbitDurMin
                + math.random()*(self.public.orbitDurMax - self.public.orbitDurMin)
            orbitDirTimer = self.public.orbitDirFlipMin
                + math.random()*(self.public.orbitDirFlipMax - self.public.orbitDirFlipMin)
            orbitSubPhase = OrbitPhase.NEUTRAL
            pressureAccum = 0
            PlayAnim(self.public.animWalk, 0.25)
            currentState = State.ORBIT
            Engine.Log("[Enemy] ATTACK → ORBIT (still close)")
        else
            navRefreshTimer = 0
            PlayAnim(self.public.animWalk, 0.25)
            currentState = State.CHASE
            Engine.Log("[Enemy] ATTACK → CHASE (cooldown "
                       .. string.format("%.2f", cooldownTimer) .. "s)")
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
    orbitSubPhase       = OrbitPhase.NEUTRAL
    retreatTimer        = 0
    punishTimer         = 0
    feintTimer          = 0
    feintCooldown       = self.public.feintCoolMin
    pressureAccum       = 0
    playerSpeedEst      = 0
    playerPrevX         = 0
    playerPrevZ         = 0
    playerWasAttacking  = false
    playerApproachSpd   = 0
    dodgeTimer          = 0
    dodgeCoolTimer      = 0
    dodgeVelX           = 0
    dodgeVelZ           = 0
    stateBeforeDodge    = nil
    currentYaw          = (self.transform.worldRotation and self.transform.worldRotation.y) or 0
    currentState        = State.IDLE
    patrolWait          = self.public.patrolWaitMin
        + math.random()*(self.public.patrolWaitMax - self.public.patrolWaitMin)

    nav       = self.gameObject:GetComponent("Navigation")
    rb        = self.gameObject:GetComponent("Rigidbody")
    anim      = self.gameObject:GetComponent("Animation")
    attackCol = self.gameObject:GetComponent("Box Collider")
    Enemy.stepSFX = self.gameObject:GetComponent("Audio Source")

    attackSource = GameObject.Find("Enemy_AttackSource")
    dieSource    = GameObject.Find("Enemy_DieSource")
    hurtSource   = GameObject.Find("Enemy_HurtSource")
    if attackSource then Enemy.attackSFX = attackSource:GetComponent("Audio Source") end
    if dieSource    then Enemy.dieSFX    = dieSource:GetComponent("Audio Source")    end
    if hurtSource   then Enemy.hurtSFX   = hurtSource:GetComponent("Audio Source")   end

    PlayAnim(self.public.animIdle, 0.0)
    Engine.Log("[Enemy] Start OK  HP=" .. hp)
end

-- ─────────────────────────────────────────────────────────────────────────
-- UPDATE
-- ─────────────────────────────────────────────────────────────────────────
function Update(self, dt)
    if isDead then return end

    if pendingDeath then
        isAttacking = false; isOnCooldown = false
        if nav then nav:StopMovement() end
        if rb  then HardBrakeXZ() end
        currentState = State.DEAD
        isDead       = true
        PlayAnim(self.public.animDeath, 0.05)
        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
        return
    end

    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
    end

    -- ── Delayed player-hit flush ──────────────────────────────────────────
    if pendingPlayerDmg > 0 then
        hitReactTimer = hitReactTimer - dt
        if hitReactTimer <= 0 then
            local dmg = pendingPlayerDmg
            local pos = pendingPlayerDmgPos
            pendingPlayerDmg    = 0
            pendingPlayerDmgPos = nil
            TakeDamage(self, dmg, pos)
        end
    end

    if isStunned then
        stunTimer = stunTimer - dt
        HardBrakeXZ()
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Enemy] Stun over")
        end
        return
    end

    if isOnCooldown then
        cooldownTimer = cooldownTimer - dt
        if cooldownTimer <= 0 then
            isOnCooldown = false
            Engine.Log("[Enemy] Cooldown over")
        end
    end

    -- Dodge cooldown tick (independent of attack cooldown)
    if dodgeCoolTimer > 0 then
        dodgeCoolTimer = dodgeCoolTimer - dt
    end

    if not nav or not rb then
        nav = self.gameObject:GetComponent("Navigation")
        rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not playerGO then
        playerGO = GameObject.Find("Player")
    end

    -- ── Player attack polling (Mode A) ────────────────────────────────────
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and playerGO and not isDead then
            local myPos = self.transform.worldPosition
            local pp    = playerGO.transform.position
            if pp then
                local dist = DistFlat(myPos, pp)
                if dist <= self.public.attackRange + 1.5 then
                    local plYaw = playerGO.transform.worldRotation
                                  and playerGO.transform.worldRotation.y or 0
                    if PlayerFacingEnemy(pp, plYaw, myPos, 0.0) then
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
        end
    else
        playerAttackHandled = false
        alreadyHit          = false
    end

    -- ── Estimate player approach speed toward enemy ───────────────────────
    -- Approach speed = dot(playerVelocity, normalize(enemyPos – playerPos)).
    -- Positive means the player is closing in; used by TryDodge for prediction.
    if playerGO then
        local pp   = playerGO.transform.worldPosition
        local myP  = self.transform.worldPosition
        local pvX  = (pp.x - playerPrevX) / math.max(dt, 0.001)
        local pvZ  = (pp.z - playerPrevZ) / math.max(dt, 0.001)
        local edx, edz = NormFlat(myP.x - pp.x, myP.z - pp.z)
        local rawApproach = pvX * edx + pvZ * edz
        -- Smooth to avoid false triggers from single noisy frames
        playerApproachSpd = Lerp(playerApproachSpd, math.max(0, rawApproach), dt * 8.0)

        playerSpeedEst = Lerp(playerSpeedEst,
            sqrt((pp.x-playerPrevX)^2 + (pp.z-playerPrevZ)^2) / math.max(dt,0.001), dt*6.0)
        playerPrevX = pp.x
        playerPrevZ = pp.z

        -- ── Predictive dodge check ────────────────────────────────────────
        -- Runs before state dispatch so it can interrupt ORBIT/CHASE/ANTICIPATE.
        if TryDodge(self, dt, pp, myP) then return end
    end

    -- ── Aggro ─────────────────────────────────────────────────────────────
    if (currentState == State.IDLE or currentState == State.PATROL) and playerGO then
        local dist = DistFlat(self.transform.worldPosition, playerGO.transform.worldPosition)
        if dist <= self.public.aggroRadius then
            nav:StopMovement(); RequestBrakeXZ(self); navRefreshTimer = 0
            PlayAnim(self.public.animWalk, 0.2)
            currentState = State.CHASE
        end
    end

    -- ── State dispatch ────────────────────────────────────────────────────
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
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= nil and attack ~= "" then
                local ap     = other.transform.worldPosition
                local plYaw  = other.transform.worldRotation
                               and other.transform.worldRotation.y or 0
                local myPos  = self.transform.worldPosition
                if PlayerFacingEnemy(ap, plYaw, myPos, 0.0) then
                    alreadyHit = true
                    local dmg  = 0
                    if     attack == "light"  then dmg = 10
                    elseif attack == "heavy" or attack == "charge" then dmg = 25
                    end
                    if dmg > 0 then QueuePlayerDamage(self, dmg, ap) end
                end
            end
        end

        -- ── El Enemy golpea al Player con su propio collider ──────────────
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