local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

local GRAVITY = 14.0

--States
local State = {
    HIDE     = "Hide",
    IDLE     = "Idle",
    WINDUP   = "WindUp",   -- telegrafía el disparo antes de lanzar
    COOLDOWN = "Cooldown",
    DEAD     = "Dead",
}

-- Internal state
local Mortar = {
    currentState = nil,
    rb           = nil,
    anim         = nil,
    playerGO     = nil,
    currentY     = 0,    -- ángulo Y actual (para rotación suave hacia el player)
    targetY      = 0,    -- ángulo Y deseado
}

-- Variables de vida y daño
local isDead         = false
local pendingDestroy = false
local alreadyHit     = false
local hp

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

_EnemyDamage_mortar = 30

-- Internal timers
local windUpTimer   = 0
local cooldownTimer = 0


local activeShells = {}

-- gameobjects containing audiosources
local singSource 
local dieSource 
local hurtSource 
local dipSource 

-- audio source components
local singSFX = nil
local deathSFX = nil
local hurtSFX = nil
local dipSFX = nil

local hasDeathPlayed = false
local hasHurtPlayed = false
local isSinging = false

local hideCooldownTimer = 0
local hideDurationTimer = 0
local HIDE_MAX_DURATION = 1.0
local HIDE_COOLDOWN     = 2.5  
local EVADE_CHANCE      = 0.6  

local deathTimer = 2.5

-- Public
public = {
    maxHp            = 50,
    knockbackForce   = 3.0,

    detectRange      = 22.0,   -- distancia máxima para disparar
    minRange         = 5.0,    -- punto ciego: si el player está muy cerca no dispara

    windUpTime       = 1.6,    -- segundos de telegrafía antes del disparo
    flightTime       = 4.0,    -- duración del arco en el aire
    cooldownTime     = 4.5,    -- espera entre disparos

    blastRadius      = 3.5,    -- radio de daño en el impacto
    attackDamage     = 30,     -- daño máximo (en el centro de la explosión)

    barrelOffsetY    = 1.8,    -- altura del punto de disparo sobre el pivot
    rotationSpeed    = 6.0,    -- velocidad de giro para encarar al player

    projectilePrefab = "Sirena_Bullet",  -- nombre del prefab del proyectil
    maxLifetime      = 10.0,
}

local finalPath  = Engine.GetAssetsPath() .. "/Prefabs/Sirena_Bullet.prefab"

-- Helpers
local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function ChangeState(newState)
    Mortar.currentState = newState
    Engine.Log("[Siren State] -> " .. newState)
end

-- Calcula la velocidad inicial para un arco parabólico dado origen, destino y tiempo de vuelo.
local function ComputeLaunchVelocity(sx, sy, sz, tx, ty, tz)
    local dx = tx - sx
    local dz = tz - sz
    local dy = ty - sy
    local distXZ = sqrt(dx*dx + dz*dz)

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

-- TakeDamage
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    if Mortar.currentState == State.HIDE then
        if Mortar.currentState == State.HIDE then
            Engine.Log("[Mortar] ¡Esquivado! La sirena está bajo el agua.")
        end
        hasDeathPlayed = true
        return 
    end
    hp = hp - amount
    Engine.Log("[Mortar] HP: " .. hp .. "/" .. self.public.maxHp)

    if hurtSFX then 
        if singSFX then singSFX:StopAudioEvent() end
        hurtSFX:PlayAudioEvent() 
        isSinging = false    
    end
    
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
        Mortar.currentState = State.DEAD

        if singSFX then singSFX:StopAudioEvent() end
        if dipSFX then dipSFX:StopAudioEvent() end

        if not hasDeathPlayed then
			if deathSFX then deathSFX:PlayAudioEvent() end
			hasDeathPlayed = true
		end

        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07

        for _, shell in ipairs(activeShells) do
            SafeDestroyShell(shell)
        end
        activeShells = {}

        Engine.Log("[Mortar] DEAD")
    end
end

-- FacePlayer: gira suavemente hacia la posición del player
local function FacePlayer(self, playerPos, dt)
    local myPos = self.transform.position
    local dx    = playerPos.x - myPos.x
    local dz    = playerPos.z - myPos.z
    Mortar.targetY = atan2(dx, dz) * (180.0 / pi)

    local diff = shortAngleDiff(Mortar.currentY, Mortar.targetY)
    Mortar.currentY = Mortar.currentY + diff * self.public.rotationSpeed * dt
    self.transform:SetRotation(0, Mortar.currentY, 0)
end

-- FireShell: lanza un proyectil parabólico hacia la posición dada
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

-- SafeMoveShell
local function SafeMoveShell(s, x, y, z, t)
    if not s.go then return end
    if s.goInvalid then return end

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
        s.goInvalid = true
        s.go        = nil
    end
end

-- SafeDestroyShell
local function SafeDestroyShell(s)
    if not s.go or s.goInvalid then return end
    pcall(function() GameObject.Destroy(s.go) end)
    s.go = nil
end

-- UpdateShells
local function UpdateShells(self, dt)
    if #activeShells == 0 then return end

    for i = #activeShells, 1, -1 do
        local s = activeShells[i]
        s.age = s.age + dt

        local t = s.age
        local x = s.sx + s.vx * t
        local y = s.sy + s.vy * t - 0.5 * GRAVITY * t * t
        local z = s.sz + s.vz * t

        SafeMoveShell(s, x, y, z, t)

        local impacted = (s.age >= s.flightTime) or (y < -50.0)

        if impacted and not s.hasHit then
            s.hasHit = true

            Engine.Log("[Mortar] Impact at ("
                     .. string.format("%.1f", x) .. ", "
                     .. string.format("%.1f", z) .. ")")

            if Mortar.playerGO then
                local pp = Mortar.playerGO.transform.position
                if pp then
                    local impDx   = pp.x - x
                    local impDz   = pp.z - z
                    local impDist = sqrt(impDx * impDx + impDz * impDz)

                    if impDist <= self.public.blastRadius then
                        local factor = 1.0 - (impDist / self.public.blastRadius) * 0.5
                        local dmg    = math.max(math.floor(self.public.attackDamage * factor), 1)

                        if (_PlayerController_pendingDamage or 0) == 0 then
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


function UpdateHide(self, dt)
      if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Hide") then
            Mortar.anim:Play("Hide")
        end

        hideDurationTimer = hideDurationTimer - dt

        if _PlayerController_lastAttack ~= "" then
            hideDurationTimer = 2 
        end

        if hideDurationTimer <= 0 then
            Mortar.currentState = State.IDLE
            Engine.Log("[Siren] El player paró de atacar. Salgo a contraatacar.")
        end
end

function UpdateIdle(self, dist, dt)

    if dist <= self.public.detectRange and dist >= self.public.minRange then
        Mortar.anim:Play("Look")
        Mortar.currentState = State.WINDUP
        if not isSinging then
            if singSFX then singSFX:PlayAudioEvent() end
            isSinging = true
        end
        windUpTimer = 0
        Engine.Log("[Mortar] Player detectado a dist=" .. string.format("%.1f", dist) .. ". Wind-up...")
        ChangeState(State.WINDUP)
    else
        if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Hide") then
            Mortar.anim:Play("Hide")
        end
    end

end

function UpdateWindUp(self, pp, dist, dt)

    FacePlayer(self, pp, dt)
        windUpTimer = windUpTimer + dt

        if dist > self.public.detectRange or dist < self.public.minRange then
            Mortar.currentState = State.COOLDOWN
            cooldownTimer       = self.public.cooldownTime * 0.4
            Engine.Log("[Mortar] Player fuera de rango. Abortando disparo.")
            return
        end

        if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Charge") then
            Mortar.anim:Play("Charge")
        end

        if windUpTimer >= self.public.windUpTime then
            FireShell(self, pp.x, pp.y, pp.z)
            if Mortar.anim then Mortar.anim:Play("Fire") end
            Mortar.currentState = State.COOLDOWN
            cooldownTimer       = self.public.cooldownTime
            if Mortar.anim then 
                Mortar.anim:Play("Hide") 
            end
            Engine.Log("[Mortar] FIRED! Cooldown=" .. self.public.cooldownTime .. "s")
            ChangeState(State.COOLDOWN)
        end


end

function UpdateCooldown(self, dist, dt)

    if cooldownTimer < (self.public.cooldownTime - 0.4) then
        if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Hide") then
            Mortar.anim:Play("Hide")
        end
    end

    cooldownTimer = cooldownTimer - dt

    if cooldownTimer <= 0 then
        Mortar.currentState = State.IDLE
        if Mortar.anim and not Mortar.anim:IsPlayingAnimation("Look") then
            Mortar.anim:Play("Look")
        end
        if dist <= self.public.detectRange and dist >= self.public.minRange then
            Mortar.currentState = State.WINDUP
            windUpTimer         = 0
            Engine.Log("[Mortar] Cooldown listo. Nuevo wind-up.")
        else
            if isSinging then
                if singSFX then singSFX:StopAudioEvent() end
                isSinging = false
            end
            Engine.Log("[Mortar] Cooldown listo. Volviendo a IDLE.")
            ChangeState(State.IDLE)
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

    singSource = GameObject.FindInChildren(self.gameObject, "SingSource")
    dieSource = GameObject.FindInChildren(self.gameObject, "SirenDieSource")
    hurtSource = GameObject.FindInChildren(self.gameObject, "SirenHurtSource")
    dipSource = GameObject.FindInChildren(self.gameObject,"DipSource")

    singSFX  = singSource:GetComponent("Audio Source")
    deathSFX = dieSource:GetComponent("Audio Source")
    hurtSFX  = hurtSource:GetComponent("Audio Source")
    dipSFX   = dipSource:GetComponent("Audio Source")
    
    if not singSFX then
		Engine.Log("[SIREN AUDIO] Unable to retrieve SingSource") 
	end
    if not deathSFX then 
		Engine.Log("[SIREN AUDIO] Unable to retrieve SirenDieSource") 
	end
    if not dipSFX then 
		Engine.Log("[SIREN AUDIO] Unable to retrieve DipSource") 
	end

    Prefab.Load("Sirena_Bullet", finalPath)
    if Mortar.rb then
        Mortar.rb:SetLinearVelocity(0, 0, 0)
    end

    Engine.Log("[Mortar] Initialized. HP=" .. hp
             .. " detectRange=" .. self.public.detectRange)
end

-- Update
function Update(self, dt)
    if not self.gameObject then return end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        return
    end

    if isDead then
        deathTimer = deathTimer - dt
        local pos = self.transform.position
        self.transform:SetPosition(pos.x, pos.y - 0.5 * dt, pos.z)
        if deathTimer <= 0 then
            self:Destroy()
        end
        return
    end

    if _PlayerController_lastAttack == nil or _PlayerController_lastAttack == "" then
        alreadyHit = false
    end

    -- Simular proyectiles en vuelo
    UpdateShells(self, dt)

    -- Retry components if missing
    if not Mortar.rb then
        Mortar.rb = self.gameObject:GetComponent("Rigidbody")
    end

    -- Keep the mortar still
    if Mortar.rb then
        local vel = Mortar.rb:GetLinearVelocity()
        if vel then
            Mortar.rb:SetLinearVelocity(0, vel.y, 0)
        end
    end

    -- Search player
    if not Mortar.playerGO then
        Mortar.playerGO = GameObject.Find("Player")
        if Mortar.playerGO then
            Engine.Log("[Mortar] Player encontrado")
        end
    end

    if not Mortar.playerGO then return end

    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
    end

    if hideCooldownTimer > 0 then hideCooldownTimer = hideCooldownTimer - dt end
    local playerAttack = _PlayerController_lastAttack

    local myPos = self.transform.position
    local pp    = Mortar.playerGO.transform.position
    if not pp then return end

    local distX = pp.x - myPos.x
    local distZ = pp.z - myPos.z
    local dist  = sqrt(distX * distX + distZ * distZ)

    if playerAttack ~= "" and hideCooldownTimer <= 0 and Mortar.currentState ~= State.HIDE then
        local currentEvadeChance = EVADE_CHANCE
        if dist < 5.0 then
            currentEvadeChance = 0.9
        end

        if math.random() < currentEvadeChance then
            Mortar.currentState = State.HIDE
            hideDurationTimer = HIDE_MAX_DURATION
            hideCooldownTimer = HIDE_COOLDOWN
            if dipSFX then dipSFX:PlayAudioEvent() end
            Engine.Log("[Siren] ¡Ataque detectado! Sumergiéndose...")
        else
            hideCooldownTimer = 0.5 
        end
    end

    -- State machine

    if     Mortar.currentState == State.HIDE     then UpdateHide(self, dt)
    elseif Mortar.currentState == State.IDLE     then UpdateIdle(self, dist, dt)
    elseif Mortar.currentState == State.WINDUP   then UpdateWindUp(self, pp, dist, dt)
    elseif Mortar.currentState == State.COOLDOWN then UpdateCooldown(self, dist, dt)
    end

    if pendingDestroy then
        self:Destroy()
        pendingDestroy = false
    end
end

-- OnTriggerEnter
function OnTriggerEnter(self, other)
    if isDead or Mortar.currentState == State.HIDE then return end

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

-- OnTriggerExit
function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end
