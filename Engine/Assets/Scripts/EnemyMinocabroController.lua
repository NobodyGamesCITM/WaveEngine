local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- ── States ────────────────────────────────────────────────────────────────
local State = {
    IDLE    = "Idle",
    WANDER  = "Wander",
    CHASE   = "Chase",
    WINDUP  = "Windup",   -- [NEW] Telegraph antes de la embestida
    CHARGE  = "Charge",
    STUMBLE = "Stumble",  -- [NEW] Recuperación pesada tras carga fallida
    DEAD    = "Dead"
}

-- ── Enemy table ────────────────────────────────────────────────────────────
local Enemy = {
    currentState    = nil,
    rb              = nil,
    nav             = nil,
	anim			= nil,
    stepSFX         = nil,
    voiceSFX        = nil,
    startPos        = nil,
    targetPos       = { x = 0, y = 0, z = 0 },
    nextWanderTimer = 0,
    chaseTimer      = 0,
    stepTimer       = 0,
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

local isDead            = false
local pendingDeath      = false   -- hp <= 0, destruir al inicio del siguiente Update
local deathTimer        = 3.5
local alreadyHit        = false
local playerAttackHandled = false
local attackCol         = nil
local stepSource        = nil
local voiceSource       = nil

-- ── Stun ──────────────────────────────────────────────────────────────────
local isStunned     = false
local stunTimer     = 0
local STUN_DURATION = 0.25   -- más corto que el skeleton: es más resistente

-- ── Windup (telegraph de carga) ────────────────────────────────────────────
local windupTimer       = 0
local WINDUP_DURATION   = 0.55   -- tiempo que tarda en "apuntar" antes de salir
local windupLockDirX    = 0      -- dirección bloqueada al inicio del windup
local windupLockDirZ    = 0

-- ── Charge con rampa de velocidad ─────────────────────────────────────────
local chargeSpeedCurrent = 0     -- velocidad actual de la carga (arranca en 0)
local CHARGE_ACCEL       = 90.0  -- unidades/s² de aceleración al inicio

-- ── Stumble post-carga ────────────────────────────────────────────────────
local stumbleTimer      = 0
local STUMBLE_DURATION  = 0.7    -- segundos de recuperación tras carga fallida
local stumbleDecelX     = 0      -- inercia residual al frenar
local stumbleDecelZ     = 0

-- ── Chase weaving (balanceo al perseguir) ─────────────────────────────────
local weavePhase        = 0      -- onda seno para el balanceo lateral
local weaveDir          = 1      -- sentido del balanceo actual
local weaveSwitchTimer  = 0

-- ── Humanized wander ──────────────────────────────────────────────────────
local wanderSpeedMult   = 1.0
local wanderPhase       = 0
local isMicrostopping   = false
local microstopTimer    = 0
local isLookingAround   = false
local lookAroundTimer   = 0
local lookAroundAngle   = 0
local lookAroundSpeed   = 0
local isFidgeting       = false
local fidgetTimer       = 0
local fidgetAngle       = 0
local lastWanderAngle   = 0

-- ── Damage constants ──────────────────────────────────────────────────────
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
    -- [NEW] Windup
    windupRotSpeed  = 25.0,  -- gira MUY rápido durante el windup (apuntando)
    -- [NEW] Weaving al perseguir
    weaveAmplitude  = 2.5,   -- amplitud del balanceo lateral
    weaveFrequency  = 1.8,   -- frecuencia de la onda (balanceos/s)
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

local function RotateTowards(self, dirX, dirZ, speed, dt)
    if abs(dirX) < 0.01 and abs(dirZ) < 0.01 then return end
    local targetAngle = atan2(dirX, dirZ) * (180.0 / pi)
    local diff = shortAngleDiff(Enemy.currentY, targetAngle)
    Enemy.currentY = Enemy.currentY + diff * speed * dt
    self.transform:SetRotation(0, Enemy.currentY, 0)
end

local function PlayAnim(name, blend)
    if Enemy.anim then Enemy.anim:Play(name, blend or 0.15) end
end

-- ── TakeDamage ───────────────────────────────────────────────────────────
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    if not Enemy.anim:IsPlayingAnimation("Hurt") then
        if Enemy.voiceSFX then 
            Enemy.voiceSFX:StopAudioEvent()
            Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoHurt")
        end
        PlayAnim("Hurt", 0.5)
        
    end

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
        -- No destruir aquí: marcar pendingDeath y dejar que Update lo gestione.
        -- Así evitamos que la ejecución continúe tras Destroy() en OnTriggerEnter.
        pendingDeath = true

        if not Enemy.anim:IsPlayingAnimation("Death") then
            PlayAnim("Death", 0.5)
            if Enemy.voiceSFX then 
                Enemy.voiceSFX:StopAudioEvent()
                Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoDie") 
            end
        end
        
        Engine.Log("[Minocabro] HP agotado, muerte pendiente")
    else
        -- Stun: interrumpir windup o cualquier otra acción
        -- (no interrumpe la carga ya lanzada — el minocabro tiene inercia)

        if Enemy.currentState ~= State.CHARGE then
            isStunned  = true
            stunTimer  = STUN_DURATION
            windupTimer = 0
            if Enemy.nav then Enemy.nav:StopMovement() end
            Engine.Log("[Minocabro] STUN " .. STUN_DURATION .. "s")
        end
    end
end

-- ── Movement (patrulla / chase) ───────────────────────────────────────────
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

        RotateTowards(self, Enemy.smoothDx, Enemy.smoothDz, self.public.rotationSpeed, dt)
    end

    local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
    return isMoving, sMag
end

-- ── BeginWindup: inicio del telegraph de carga ────────────────────────────
local function BeginWindup(self)
    if not Enemy.playerGO then return end

    local myPos = self.transform.worldPosition
    local pp    = Enemy.playerGO.transform.worldPosition
    if not pp then return end

    local dx  = pp.x - myPos.x
    local dz  = pp.z - myPos.z
    local len = sqrt(dx * dx + dz * dz)
    if len < 0.001 then return end

    -- Bloquear la dirección al inicio del windup
    windupLockDirX = dx / len
    windupLockDirZ = dz / len
    windupTimer    = 0

    Enemy.smoothDx = 0
    Enemy.smoothDz = 0
    if Enemy.nav then Enemy.nav:StopMovement() end

    Enemy.currentState = State.WINDUP
    
    Engine.Log("[Minocabro] WINDUP — apuntando al player")
end

-- ── LaunchCharge: lanzar la carga real tras el windup ─────────────────────
local function LaunchCharge(self)
    -- Recalcular dirección con la posición actual del player (más justo)
    if Enemy.playerGO then
        local myPos = self.transform.worldPosition
        local pp    = Enemy.playerGO.transform.worldPosition
        if pp then
            local dx  = pp.x - myPos.x
            local dz  = pp.z - myPos.z
            local len = sqrt(dx * dx + dz * dz)
            if len > 0.001 then
                -- Mezcla 70% dirección bloqueada + 30% posición actual
                -- Da una ventana de esquive pero no es totalmente predecible
                Enemy.chargeDirX = windupLockDirX * 0.7 + (dx / len) * 0.3
                Enemy.chargeDirZ = windupLockDirZ * 0.7 + (dz / len) * 0.3
                local cl = sqrt(Enemy.chargeDirX^2 + Enemy.chargeDirZ^2)
                if cl > 0.001 then
                    Enemy.chargeDirX = Enemy.chargeDirX / cl
                    Enemy.chargeDirZ = Enemy.chargeDirZ / cl
                end
            end
        end
    else
        Enemy.chargeDirX = windupLockDirX
        Enemy.chargeDirZ = windupLockDirZ
    end

    Enemy.chargeTimer     = self.public.chargeDuration
    Enemy.hitDuringCharge = false
    chargeSpeedCurrent    = 0   -- arranca desde 0, aceleración gradual

    local targetAngle = atan2(Enemy.chargeDirX, Enemy.chargeDirZ) * (180.0 / pi)
    Enemy.currentY = targetAngle
    self.transform:SetRotation(0, Enemy.currentY, 0)



    Enemy.currentState = State.CHARGE
    Engine.Log("[Minocabro] ¡EMBESTIDA!")
end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    hp         = self.public.maxHp
    isDead     = false
    alreadyHit = false
    stepSource = GameObject.FindInChildren(self.gameObject, "MinoStepSource")
    voiceSource = GameObject.FindInChildren(self.gameObject, "MinoVoiceSource")

    Enemy.nav = self.gameObject:GetComponent("Navigation")
    Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
	Enemy.anim = self.gameObject:GetComponent("Animation")

    if stepSource then
        Enemy.stepSFX = stepSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for steps not found") end

    if voiceSource then
        Enemy.voiceSFX = voiceSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for voice not found") end


    local pos = self.transform.position
    Enemy.startPos = { x = pos.x, y = pos.y, z = pos.z }

    if not Enemy.startPos then 
        Engine.Log("[Minocabro] WARNING: startPos not found")
    end

    Enemy.currentState    = State.IDLE
    Enemy.nextWanderTimer = self.public.idleWaitTime
    Enemy.chaseTimer      = 0
    Enemy.cooldownTimer   = 0
    Enemy.playerGO        = nil
    Enemy.stepTimer       = 0.5

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    Engine.Log("[Minocabro] Start OK - HP: " .. hp)
end

-- ── Update ────────────────────────────────────────────────────────────────
function Update(self, dt)
    if isDead then return end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        
    end

    Enemy.stepTimer = Enemy.stepTimer + dt

    -- Muerte diferida: destruir aquí, nunca desde TakeDamage ni OnTriggerEnter
    if pendingDeath then
        deathTimer = deathTimer - dt
      
        if deathTimer <= 0 then
            isDead = true
              
            local _nav = Enemy.nav
            local _rb  = Enemy.rb

            attackCol      = nil
            Enemy.nav      = nil
            Enemy.rb       = nil
            Enemy.anim     = nil
            Enemy.playerGO = nil
            Enemy.stepSFX  = nil
            Enemy.voiceSFX = nil

            if _nav then _nav:StopMovement() end
            if _rb  then
                local vel = _rb:GetLinearVelocity()
                _rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
            end

            Enemy.currentState = State.DEAD

            Engine.Log("[Minocabro] DEAD")
            Game.SetTimeScale(0.2)
            _impactFrameTimer = 0.1

            self:Destroy()
        end
        return
    end

    if not Enemy.nav or not Enemy.rb or not Enemy.anim then
        Enemy.nav = self.gameObject:GetComponent("Navigation")
        Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
        Enemy.anim = self.gameObject:GetComponent("Animation")
        return
    end

    if not Enemy.playerGO then
        Enemy.playerGO = GameObject.Find("Player")
        if Enemy.playerGO then Engine.Log("[Minocabro] Player encontrado") end
    end

    if Enemy.cooldownTimer > 0 then
        Enemy.cooldownTimer = Enemy.cooldownTimer - dt
    end

    -- ── Stun ─────────────────────────────────────────────────────────────
    if isStunned then
        stunTimer = stunTimer - dt
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        if Enemy.rb then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        if stunTimer <= 0 then
            isStunned = false
            Engine.Log("[Minocabro] Stun terminado")
        end
        return
    end

    -- ── Detectar golpe del player (sistema dual, igual que skeleton) ──────
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and Enemy.playerGO and not isDead then
            local myPos = self.transform.position
            local pp    = Enemy.playerGO.transform.position
            if pp then
                local dx   = pp.x - myPos.x
                local dz   = pp.z - myPos.z
                local dist = sqrt(dx * dx + dz * dz)
                if dist <= (self.public.chargeRange * 0.5) then
                    playerAttackHandled = true
                    local attack = _PlayerController_lastAttack
                    if attack == "light" then
                        TakeDamage(self, DAMAGE_LIGHT, pp)
                    elseif attack == "charge" then
                        TakeDamage(self, DAMAGE_HEAVY, pp)
                    end
                end
            end
        end
    else
        playerAttackHandled = false
        alreadyHit          = false
    end

    -- ── WINDUP: telegraph de carga ────────────────────────────────────────
    -- El minocabro se planta y apunta al player antes de salir disparado.
    if Enemy.currentState == State.WINDUP then
        windupTimer = windupTimer + dt

        -- Parar
        Enemy.smoothDx = 0
        Enemy.smoothDz = 0
        if Enemy.rb then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end

        -- Girar muy rápido hacia la dirección bloqueada (tensión visual)
        RotateTowards(self, windupLockDirX, windupLockDirZ, self.public.windupRotSpeed, dt)

        if windupTimer >= WINDUP_DURATION then
            LaunchCharge(self)
        end
        return
    end

    -- ── CHARGE: embestida con rampa de aceleración ────────────────────────
    if Enemy.currentState == State.CHARGE then
       Enemy.chargeTimer = Enemy.chargeTimer - dt
       
       
        if Enemy.stepTimer >= 0.25 then
            Enemy.stepTimer = 0
            if Enemy.stepSFX then 
                Enemy.stepSFX:PlayAudioEvent() 
            end
        end

        if attackCol and not pendingDeath then attackCol:Enable() end

        -- Rampa: acelerar hasta chargeSpeed
        chargeSpeedCurrent = min(
            self.public.chargeSpeed,
            chargeSpeedCurrent + CHARGE_ACCEL * dt
        )

        if Enemy.rb then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(
                Enemy.chargeDirX * chargeSpeedCurrent,
                vel.y,
                Enemy.chargeDirZ * chargeSpeedCurrent
            )
        end

        if Enemy.chargeTimer <= 0 then
            -- Carga fallida: entrar en stumble
            --if attackCol then attackCol:Disable() end
            attackCol = nil 

            -- Guardar la inercia residual para el stumble
            stumbleDecelX = Enemy.chargeDirX * chargeSpeedCurrent * 0.5
            stumbleDecelZ = Enemy.chargeDirZ * chargeSpeedCurrent * 0.5
            stumbleTimer  = STUMBLE_DURATION

            Enemy.cooldownTimer = self.public.chargeCooldown
            Enemy.currentState  = State.STUMBLE
            Engine.Log("[Minocabro] Embestida fallida — stumble")
        end

        

        if not Enemy.anim:IsPlayingAnimation("Charge") then
            PlayAnim("Charge", 0.5)
            if Enemy.voiceSFX then 
                Enemy.voiceSFX:StopAudioEvent()
                Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoCharge") 
            end
        end

        return
    end

    -- ── STUMBLE: recuperación pesada tras carga fallida ───────────────────
    -- El minocabro frena con inercia y queda vulnerable.
    if Enemy.currentState == State.STUMBLE then
        stumbleTimer = stumbleTimer - dt

        -- Desacelerar progresivamente la inercia residual
        local t = 1.0 - (stumbleTimer / STUMBLE_DURATION)   -- 0→1 durante el stumble
        local decel = lerp(1.0, 0.0, t * 1.5)
        if Enemy.rb then
            local vel = Enemy.rb:GetLinearVelocity()
            Enemy.rb:SetLinearVelocity(
                stumbleDecelX * decel,
                vel.y,
                stumbleDecelZ * decel
            )
        end

        -- Giro lento de recuperación (como un toro desorientado)
        local wobble = math.sin(stumbleTimer * 12.0) * 15.0 * decel
        Enemy.currentY = Enemy.currentY + wobble * dt
        self.transform:SetRotation(0, Enemy.currentY, 0)

        if not Enemy.anim:IsPlayingAnimation("Wall") then
            PlayAnim("Wall", 0.5)
            if Enemy.voiceSFX then 
                Enemy.voiceSFX:StopAudioEvent()
                Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoCrash") 
            end
        end


        if stumbleTimer <= 0 then
            if Enemy.rb then
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            end
            Enemy.currentState = State.CHASE
            Enemy.chaseTimer   = 0   -- forzar SetDestination inmediato en el siguiente frame
            Engine.Log("[Minocabro] Recuperado del stumble")
        end
        return
    end

    -- ── Detección de distancia al player ─────────────────────────────────
    local myPos       = self.transform.worldPosition
    local playerPos   = nil
    local dist        = 999
    local inChaseRange  = false
    local inChargeRange = false

    if Enemy.playerGO then
        playerPos = Enemy.playerGO.transform.worldPosition
        if playerPos then
            local dx = playerPos.x - myPos.x
            local dz = playerPos.z - myPos.z
            dist = sqrt(dx * dx + dz * dz)
            inChaseRange  = dist < self.public.chaseRange
            inChargeRange = dist <= self.public.chargeRange
        end
    end

    if inChaseRange and playerPos then
        -- Dentro del rango de carga y cooldown listo: iniciar windup
        if inChargeRange and Enemy.cooldownTimer <= 0 then
            if not Enemy.anim:IsPlayingAnimation("PreCharge") then
                PlayAnim("PreCharge", 0.5)
                if Enemy.voiceSFX then 
                    Enemy.voiceSFX:StopAudioEvent()
                    Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoPreCharge") 
                end
            end
            BeginWindup(self)
            return
        end

        -- Chase con weaving: perseguir con balanceo lateral
        Enemy.currentState = State.CHASE

        Enemy.chaseTimer = Enemy.chaseTimer - dt
        if Enemy.chaseTimer <= 0 then
            Enemy.chaseTimer = self.public.chaseUpdateRate

            -- Calcular punto de destino con desplazamiento lateral (weaving)
            weavePhase = weavePhase + dt * self.public.weaveFrequency

            -- Cambio de sentido aleatorio ocasional
            weaveSwitchTimer = weaveSwitchTimer - dt
            if weaveSwitchTimer <= 0 then
                weaveSwitchTimer = math.random() * 1.5 + 0.8
                if math.random() < 0.35 then
                    weaveDir = -weaveDir
                end
            end

            -- Vector perpendicular a la dirección al player
            local dx    = playerPos.x - myPos.x
            local dz    = playerPos.z - myPos.z
            local dlen  = math.max(0.001, sqrt(dx * dx + dz * dz))
            local perpX = -dz / dlen   -- perpendicular en XZ
            local perpZ =  dx / dlen

            local weaveMag = math.sin(weavePhase) * self.public.weaveAmplitude * weaveDir

            local destX = playerPos.x + perpX * weaveMag
            local destZ = playerPos.z + perpZ * weaveMag

            if Enemy.nav then
                Enemy.nav:SetDestination(destX, playerPos.y, destZ)
            end
        end

    else
        -- Perdió al player
        if Enemy.currentState == State.CHASE then
            if Enemy.rb then
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            end
            Enemy.currentState    = State.IDLE
            
            Enemy.nextWanderTimer = self.public.idleWaitTime
            Engine.Log("[Minocabro] Perdí al player")
        end
    end

    -- ── Movimiento ────────────────────────────────────────────────────────
    -- Aplicar velocidad de wander si corresponde
    local _wanderSine = 1.0
    if Enemy.currentState == State.WANDER and not isMicrostopping then
        wanderPhase = wanderPhase + dt * 0.9
        _wanderSine = 0.70 + 0.30 * math.sin(wanderPhase)
        self.public.moveSpeed = self.public.moveSpeed * wanderSpeedMult * _wanderSine

    end
    local isMoving, speed = Movement(self, dt)
    -- Restaurar moveSpeed
    if _wanderSine ~= 1.0 then
        self.public.moveSpeed = self.public.moveSpeed / (wanderSpeedMult * _wanderSine)


        if Enemy.stepTimer >= 0.5 then
            Enemy.stepTimer = 0
            if Enemy.stepSFX then Enemy.stepSFX:PlayAudioEvent() end
        end
        PlayAnim("Walk", 0.5)
    end

    -- ── IDLE humanizado ───────────────────────────────────────────────────
    if Enemy.currentState == State.IDLE then

        if not Enemy.anim:IsPlayingAnimation("Idle") then
            PlayAnim("Idle", 0.5)
            if Enemy.voiceSFX then 
                Enemy.voiceSFX:StopAudioEvent()
                Enemy.voiceSFX:SelectPlayAudioEvent("SFX_MinoIdle") 
            end
        end

        Enemy.nextWanderTimer = Enemy.nextWanderTimer - dt

        -- Fidgeting: pequeños giros mientras espera
        -- Más lentos que el skeleton (criatura más pesada)
        if not isFidgeting and math.random() < dt * 0.25 then
            isFidgeting  = true
            fidgetTimer  = math.random() * 0.8 + 0.4
            local sign   = (math.random() < 0.5) and 1 or -1
            fidgetAngle  = Enemy.currentY + sign * (10 + math.random() * 25)
        end
        if isFidgeting then
            fidgetTimer = fidgetTimer - dt
            local diff  = shortAngleDiff(Enemy.currentY, fidgetAngle)
            -- Giro más lento y pesado que el skeleton
            Enemy.currentY = Enemy.currentY + diff * 2.5 * dt
            self.transform:SetRotation(0, Enemy.currentY, 0)
            if fidgetTimer <= 0 then isFidgeting = false end
        end

        if Enemy.nextWanderTimer <= 0 then
            if not isLookingAround then
                isLookingAround  = true
                lookAroundTimer  = math.random() * 0.9 + 0.4   -- más lento que el skeleton
                local sign       = (math.random() < 0.5) and 1 or -1
                lookAroundAngle  = Enemy.currentY + sign * (30 + math.random() * 50)
                lookAroundSpeed  = 40 + math.random() * 30     -- giro más lento, pesado
                isFidgeting      = false
            else
                lookAroundTimer = lookAroundTimer - dt
                local diff      = shortAngleDiff(Enemy.currentY, lookAroundAngle)
                Enemy.currentY  = Enemy.currentY + diff * (lookAroundSpeed / 90.0) * dt
                self.transform:SetRotation(0, Enemy.currentY, 0)

                if lookAroundTimer <= 0 then
                    isLookingAround = false

                    -- Sesgo direccional: 60% seguir dirección similar
                    local angle
                    if math.random() < 0.60 and lastWanderAngle ~= 0 then
                        local spread = (math.random() - 0.5) * 2 * (pi * 45 / 180)
                        angle = lastWanderAngle + spread
                    else
                        angle = math.random() * pi * 2
                    end
                    lastWanderAngle = angle

                    local minR = self.public.patrolRadius * 0.3
                    local maxR = self.public.patrolRadius
                    local d    = minR + math.random() * (maxR - minR)

                    Enemy.targetPos.x = Enemy.startPos.x + math.cos(angle) * d
                    Enemy.targetPos.z = Enemy.startPos.z + math.sin(angle) * d

                    -- Velocidad por tramo (más lenta base que skeleton)
                    local roll = math.random()
                    if roll < 0.50 then
                        wanderSpeedMult = 0.30 + math.random() * 0.15   -- paso pesado
                    elseif roll < 0.85 then
                        wanderSpeedMult = 0.50 + math.random() * 0.20   -- trote suave
                    else
                        wanderSpeedMult = 0.75 + math.random() * 0.20   -- paso rápido
                    end

                    if Enemy.nav then
                        Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                        Enemy.currentState = State.WANDER
                        isMicrostopping    = false
                        Engine.Log("[Minocabro] Nuevo destino, vel x" .. string.format("%.2f", wanderSpeedMult))
                    end
                end
            end
        end

    -- ── WANDER humanizado ─────────────────────────────────────────────────
    elseif Enemy.currentState == State.WANDER then

        if isMicrostopping then
            microstopTimer = microstopTimer - dt
            Enemy.smoothDx = lerp(Enemy.smoothDx, 0, dt * self.public.stopSmoothing)
            Enemy.smoothDz = lerp(Enemy.smoothDz, 0, dt * self.public.stopSmoothing)
            if Enemy.rb then
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
            end
            -- Giro de curiosidad (más lento que el skeleton)
            local sign = (math.random() < 0.5) and 1 or -1
            Enemy.currentY = Enemy.currentY + sign * 18 * dt
            self.transform:SetRotation(0, Enemy.currentY, 0)

            if microstopTimer <= 0 then
                isMicrostopping = false
                if Enemy.nav then
                    Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                end
            end
        else
            -- Microstop menos frecuente que el skeleton (criatura más grande)
            if isMoving and not isMicrostopping and math.random() < dt * 0.05 then
                isMicrostopping = true
                microstopTimer  = math.random() * 0.6 + 0.3
                if Enemy.nav then Enemy.nav:StopMovement() end
                Engine.Log("[Minocabro] Microstop")
            end
        end

        -- Llegó al destino
        if not isMoving and speed < 0.05 and not isMicrostopping then
            if Enemy.rb then
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            end
            -- Tiempo de espera variable con sesgo hacia pausas largas (criatura pesada)
            local roll = math.random()
            local wait
            if roll < 0.25 then
                wait = 0.5 + math.random() * 0.5
            elseif roll < 0.70 then
                wait = self.public.idleWaitTime * (0.7 + math.random() * 0.5)
            else
                wait = self.public.idleWaitTime * (1.3 + math.random() * 1.0)  -- pausa larga
            end
            Enemy.nextWanderTimer = wait
            Enemy.currentState    = State.IDLE
            isFidgeting           = false
            Engine.Log("[Minocabro] Descansando " .. string.format("%.1f", wait) .. "s")
        end
    end
end

-- ── OnTriggerEnter ────────────────────────────────────────────────────────
function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then

        -- El player golpea al minocabro
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "charge" then

                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end

        -- El minocabro golpea al player durante la carga
        if Enemy.currentState == State.CHARGE
           and not Enemy.hitDuringCharge
           and _PlayerController_pendingDamage == 0 then

            Enemy.hitDuringCharge              = true
            _PlayerController_pendingDamage    = _EnemyDamage_minocabro
            _PlayerController_pendingDamagePos = self.transform.worldPosition

            attackCol = nil
            if Enemy.rb then
                local vel = Enemy.rb:GetLinearVelocity()
                Enemy.rb:SetLinearVelocity(0, vel.y, 0)
            end
            Enemy.chargeTimer   = 0
            Enemy.cooldownTimer = self.public.chargeCooldown
            Enemy.currentState  = State.CHASE
            Enemy.chaseTimer    = 0   -- forzar SetDestination inmediato

            Engine.Log("[Minocabro] ¡Impacto! Daño: " .. _EnemyDamage_minocabro)
        end
    end
end

-- ── OnTriggerExit ─────────────────────────────────────────────────────────
-- alreadyHit y playerAttackHandled se resetean en Update cuando el ataque termina.
function OnTriggerExit(self, other)
end




