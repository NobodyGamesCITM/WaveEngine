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
    patrolSpeed     = 2.5,
    chaseSpeed      = 4.8,
    lungeForce      = 18.0,
    moveAccel       = 18.0,
    brakeDecel      = 14.0,
    rotationSpeed   = 9.0,

    -- NavMesh
    navRefreshRate  = 0.18,

    -- Detection
    aggroRadius     = 8.0,
    deaggroRadius   = 14.0,
    attackRange     = 2.0,

    -- ── Orbit base ────────────────────────────────────────────────────────
    orbitTriggerDist  = 4.5,   -- chase → orbit threshold
    orbitRadius       = 2.8,   -- preferred ring radius
    orbitSpeed        = 3.2,   -- tangential strafe speed
    orbitCorrSpeed    = 5.0,   -- radial spring strength
    orbitCorrMaxFrac  = 0.6,   -- radial correction cap (fraction of orbitSpeed)
    orbitDurMin       = 0.6,   -- min seconds before committing to attack
    orbitDurMax       = 1.4,
    orbitDirFlipMin   = 0.6,
    orbitDirFlipMax   = 1.8,
    orbitDirFlipChance= 0.4,

    -- ── PRESSURE sub-phase (player idle / slow) ───────────────────────────
    -- When the player is barely moving, the enemy closes in and speeds up its
    -- strafe to force the player to react.
    pressureSpeedThresh = 2.5,   -- player speed (m/s) below which PRESSURE triggers
    pressureRadius      = 2.0,   -- tighter radius during pressure
    pressureSpeed       = 4.5,   -- faster strafe during pressure
    pressureEnterTime   = 0.4,   -- how long player must be slow before PRESSURE starts
    pressureExitSpeed   = 4.0,   -- player speed above which PRESSURE cancels

    -- ── RETREAT sub-phase (player just attacked) ──────────────────────────
    -- When _PlayerController_lastAttack goes from "" to non-"", the enemy
    -- instantly backpedals.  If the player's attack ends before retreatDur
    -- is over, the enemy gets a short PUNISH window and commits to ANTICIPATE.
    retreatSpeed     = 5.5,    -- how fast to back away
    retreatDur       = 0.55,   -- max retreat duration (cancelled early by punish)
    punishWindow     = 0.25,   -- after attack ends, enemy has this long to punish

    -- ── FEINT sub-phase (fake wind-up) ───────────────────────────────────
    -- The enemy plays the Anticipate animation briefly, then aborts and resets
    -- its orbit timer.  Forces the player to read the full commit, not just react.
    feintDur         = 0.22,   -- how long the fake wind-up lasts
    feintCoolMin     = 3.5,    -- min seconds between feints
    feintCoolMax     = 6.0,
    feintChance      = 0.45,   -- probability of feinting when timer expires

    -- ── Attack timing ─────────────────────────────────────────────────────
    anticipateDur   = 0.45,
    attackDur       = 0.45,
    attackColDelay  = 0.22,
    lungeStopDelay  = 0.25,
    cooldownBase    = 2.0,
    cooldownRage    = 1.2,

    -- Damage
    attackDamage    = 20,
    knockbackForce  = 5.0,
    stunDuration    = 0.35,

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

-- ── NavMesh throttle ──────────────────────────────────────────────────────
local navRefreshTimer = 0

-- ── Hit detection ─────────────────────────────────────────────────────────
local playerAttackHandled = false
local alreadyHit          = false

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

local function TakeDamage(self, amount, attackerPos)
    if isDead or not hp then return end

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

    if not nav or not rb then
        nav = self.gameObject:GetComponent("Navigation")
        rb  = self.gameObject:GetComponent("Rigidbody")
        return
    end

    if not playerGO then
        playerGO = GameObject.Find("Player")
    end

    -- ── Estimate player speed from position delta ─────────────────────────
    -- Used by ORBIT to detect idle (pressure) vs. moving fast (disengage pressure).
    if playerGO then
        local pp   = playerGO.transform.worldPosition
        local rawV = sqrt((pp.x-playerPrevX)^2 + (pp.z-playerPrevZ)^2) / math.max(dt, 0.001)
        playerSpeedEst = Lerp(playerSpeedEst, rawV, dt * 6.0)  -- smooth it
        playerPrevX    = pp.x
        playerPrevZ    = pp.z
    end

    -- ── Player attack polling (Mode A) ────────────────────────────────────
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and playerGO and not isDead then
            local myPos = self.transform.worldPosition
            local pp    = playerGO.transform.position
            if pp then
                local dist = DistFlat(myPos, pp)
                if dist <= self.public.attackRange + 1.5 then
                    playerAttackHandled = true
                    local atk = _PlayerController_lastAttack
                    if     atk == "light"  then TakeDamage(self, 10, pp)
                    elseif atk == "heavy" or atk == "charge" then TakeDamage(self, 25, pp)
                    end
                end
            end
        end
    else
        playerAttackHandled = false
        alreadyHit          = false
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
                alreadyHit = true
                local ap   = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, 10, ap)
                elseif attack == "heavy" or attack == "charge" then
                    TakeDamage(self, 25, ap)
                end
            end
        end

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