--Siren Controller

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

-- -- Internal state
-- local Mortar = {
--     currentState = nil,
--     rb           = nil,
--     anim         = nil,
--     playerGO     = nil,
--     currentY     = 0,    -- ángulo Y actual (para rotación suave hacia el player)
--     targetY      = 0,    -- ángulo Y deseado
-- }

-- -- Variables de vida y daño
-- local isDead         = false
-- local pendingDestroy = false
-- local alreadyHit     = false
-- local hp

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

_EnemyDamage_mortar = 30

-- -- Internal timers
-- local windUpTimer   = 0
-- local cooldownTimer = 0


-- local activeShells = {}

-- -- gameobjects containing audiosources
-- local singSource 
-- local dieSource 
-- local hurtSource 
-- local dipSource 

-- -- audio source components
-- local singSFX = nil
-- local deathSFX = nil
-- local hurtSFX = nil
-- local dipSFX = nil

-- local hasDeathPlayed = false
-- local hasHurtPlayed = false
-- local isSinging = false


local HIDE_MAX_DURATION = 1.0
local HIDE_COOLDOWN     = 2.5  
local EVADE_CHANCE      = 0.6  



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
local finalPath_Feedback  = Engine.GetAssetsPath() .. "/Prefabs/Sirenfeedback.prefab"

-- Helpers
local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function ChangeState(self, newState)
    self.currentState = newState
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


    if self.isDead then return end

    if self.currentState == State.HIDE then
        if self.currentState == State.HIDE then
            Engine.Log("[Mortar] ¡Esquivado! La sirena está bajo el agua.")
        end
        self.hasDeathPlayed = true
        return 
    end
    self.hp = self.hp - amount
    Engine.Log("[Mortar] HP: " .. self.hp .. "/" .. self.public.maxHp)

    if self.hurtSFX then 
        if self.singSFX then self.singSFX:StopAudioEvent() end
        self.hurtSFX:PlayAudioEvent() 
        Engine.Log("[SIREN AUDIO] Hurt SFX Played")
        self.isSinging = false    
    end
    
    _PlayerController_triggerCameraShake = true

    -- Knockback
    if self.rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx * dx + dz * dz)
        if len > 0.001 then dx = dx / len; dz = dz / len end
        self.rb:AddForce(dx * self.public.knockbackForce, 0,
                           dz * self.public.knockbackForce, 2)
    end

    if self.hp <= 0 then
        self.isDead              = true
        self.currentState = State.DEAD

        if self.singSFX then self.singSFX:StopAudioEvent() end
        if self.dipSFX then self.dipSFX:StopAudioEvent() end

        if not self.hasDeathPlayed then
			if self.deathSFX then self.deathSFX:PlayAudioEvent() end
			self.hasDeathPlayed = true
		end

        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07

        for _, shell in ipairs(self.activeShells) do
            if shell.shadowGo then pcall(function() GameObject.Destroy(shell.shadowGo) end) end
            SafeDestroyShell(shell)
        end
        self.activeShells = {}

        Engine.Log("[Mortar] DEAD")
    end
end

-- FacePlayer: gira suavemente hacia la posición del player
local function FacePlayer(self, playerPos, dt)
    local myPos = self.transform.position
    local dx    = playerPos.x - myPos.x
    local dz    = playerPos.z - myPos.z
    self.targetY = atan2(dx, dz) * (180.0 / pi)

    local diff = shortAngleDiff(self.currentY, self.targetY)
    self.currentY = self.currentY + diff * self.public.rotationSpeed * dt
    self.transform:SetRotation(0, self.currentY, 0)
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
        local FeedbackAsset = Prefab.Instantiate("Sirenfeedback")

        table.insert(self.activeShells, {
            go         = shell,
            shadowGo = FeedbackAsset,
            age        = 0,
            flightTime = T,
            sx = sx, sy = sy, sz = sz,
            vx = vx, vy = vy, vz = vz,
            targetX    = tx,
            targetY    = ty,
            targetZ    = tz,
            hasHit     = false,
            feedbackSet = false,
        })
        
        --Engine.Log("[Mortar] FIRE! Dist=" .. string.format("%.1f", sqrt((tx-sx)^2+(tz-sz)^2)) .. " T=" .. string.format("%.2f", T))
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
    if not self.activeShells or #self.activeShells == 0 then return end

    for i = #self.activeShells, 1, -1 do
        local s = self.activeShells[i]

        if s.shadowGo and not s.feedbackSet then
            local tr = s.shadowGo.transform
            if tr then
                tr:SetPosition(s.targetX, s.targetY + 0.1, s.targetZ)
                s.feedbackSet = true
                Engine.Log("[Feedback] Posicionado correctamente en el suelo")
            end
        end
        
        s.age = s.age + dt

        local t = s.age
        local x = s.sx + s.vx * t
        local y = s.sy + s.vy * t - 0.5 * GRAVITY * t * t
        local z = s.sz + s.vz * t

        SafeMoveShell(s, x, y, z, t)

        local impacted = (s.age >= s.flightTime) or (y < -50.0)

        if impacted and not s.hasHit then
            s.hasHit = true

            if s.shadowGo then
                pcall(function() GameObject.Destroy(s.shadowGo) end)
            end

            Engine.Log("[Mortar] Impact at ("
                     .. string.format("%.1f", x) .. ", "
                     .. string.format("%.1f", z) .. ")")

            if self.playerGO then
                local pp = self.playerGO.transform.position
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
            table.remove(self.activeShells, i)
        end
    end
end


function UpdateHide(self, dt)
    if self.anim and not self.anim:IsPlayingAnimation("Hide") then
        self.anim:Play("Hide")
        if self.dipSFX then self.dipSFX:PlayAudioEvent() end
    end

    self.hideDurationTimer = (self.hideDurationTimer or 0) - dt

    if _PlayerController_lastAttack ~= "" then
        self.hideDurationTimer = 2 
    end

    if self.hideDurationTimer <= 0 then
        self.currentState = State.IDLE
        Engine.Log("[Siren] El player paró de atacar. Salgo a contraatacar.")
    end
end

function UpdateIdle(self, dist, dt)

    if dist <= self.public.detectRange and dist >= self.public.minRange then

        -- Engine.Log("[SIREN] Player in range? "..tostring(self.playerInRange))
        -- if self.anim and not self.anim:IsPlayingAnimation("Show") and not self.playerInRange then
        --     self.anim:Play("Show")
        --     --Engine.Log("[SIREN ANIM] Playing Show Anim")
        --     if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        --     self.playerInRange = true
        -- end

        if self.anim and not self.anim:IsPlayingAnimation("Look") then
            self.anim:Play("Look")
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        end

        self.currentState = State.WINDUP
        if not self.isSinging then
            if self.singSFX then self.singSFX:PlayAudioEvent() end
            self.isSinging = true
        end
        self.windUpTimer = 0
        --Engine.Log("[Mortar] Player detectado a dist=" .. string.format("%.1f", dist) .. ". Wind-up...")
        ChangeState(self, State.WINDUP)
    else
        if self.anim and not self.anim:IsPlayingAnimation("Hide") then
            self.anim:Play("Hide")
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
            --self.playerInRange = false
        end
    end

end

function UpdateWindUp(self, pp, dist, dt)

    FacePlayer(self, pp, dt)
        self.windUpTimer = self.windUpTimer + dt

        if dist > self.public.detectRange or dist < self.public.minRange then
            self.currentState = State.COOLDOWN
            self.cooldownTimer       = self.public.cooldownTime * 0.4
            Engine.Log("[Mortar] Player fuera de rango. Abortando disparo.")
            return
        end

        --NOTE: no charging animation for siren
        -- if self.anim and not self.anim:IsPlayingAnimation("Charge") then
        --     self.anim:Play("Charge")
        -- end

        if self.windUpTimer >= self.public.windUpTime then
            FireShell(self, pp.x, pp.y, pp.z)
            if self.anim then self.anim:Play("Fire") end
            self.currentState = State.COOLDOWN
            self.cooldownTimer       = self.public.cooldownTime
            if self.anim then 
                self.anim:Play("Hide") 
                if self.dipSFX then self.dipSFX:PlayAudioEvent() end
            end
            Engine.Log("[Mortar] FIRED! Cooldown=" .. self.public.cooldownTime .. "s")
            ChangeState(self, State.COOLDOWN)
        end


end

function UpdateCooldown(self, dist, dt)

    if self.cooldownTimer < (self.public.cooldownTime - 0.4) then
        if self.anim and not self.anim:IsPlayingAnimation("Hide") then
            self.anim:Play("Hide")
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        end
    end

    self.cooldownTimer = self.cooldownTimer - dt

    if self.cooldownTimer <= 0 then
        self.currentState = State.IDLE
        if self.anim and not self.anim:IsPlayingAnimation("Look") then
            self.anim:Play("Look")
        end
        if dist <= self.public.detectRange and dist >= self.public.minRange then
            self.currentState = State.WINDUP
            self.windUpTimer         = 0
            Engine.Log("[Mortar] Cooldown listo. Nuevo wind-up.")
        else
            if self.isSinging then
                if self.singSFX then self.singSFX:StopAudioEvent() end
                self.isSinging = false
            end
            Engine.Log("[Mortar] Cooldown listo. Volviendo a IDLE.")
            ChangeState(self, State.IDLE)
        end
    end
end

local function FindSirenAudioComponents(self)
    Engine.Log("[SIREN AUDIO] Searching in: " .. tostring(self.gameObject.name))
    
    local singSource = GameObject.FindInChildren(self.gameObject, "SingSource")
    Engine.Log("[SIREN AUDIO] SingSource found: " .. tostring(singSource ~= nil))
    
    local dieSource = GameObject.FindInChildren(self.gameObject, "SirenDieSource")
    Engine.Log("[SIREN AUDIO] DieSource found: " .. tostring(dieSource ~= nil))
    
    local hurtSource = GameObject.FindInChildren(self.gameObject, "SirenHurtSource")
    Engine.Log("[SIREN AUDIO] HurtSource found: " .. tostring(hurtSource ~= nil))
    
    local dipSource = GameObject.FindInChildren(self.gameObject, "DipSource")
    Engine.Log("[SIREN AUDIO] DipSource found: " .. tostring(dipSource ~= nil))

    -- singSource = GameObject.Find("SingSource")
    -- dieSource = GameObject.Find("SirenDieSource")
    -- hurtSource = GameObject.Find("SirenHurtSource")
    -- dipSource = GameObject.Find("DipSource")

    self.singSFX  = singSource:GetComponent("Audio Source")
    self.deathSFX = dieSource:GetComponent("Audio Source")
    self.hurtSFX  = hurtSource:GetComponent("Audio Source")
    self.dipSFX   = dipSource:GetComponent("Audio Source")
    
    if not self.singSFX then
		Engine.Log("[SIREN AUDIO] Unable to retrieve SingSource") 
	end
    if not self.hurtSFX then
        Engine.Log("[SIREN AUDIO] Unable to retrieve SirenHurtSource") 
    end
    if not self.deathSFX then 
		Engine.Log("[SIREN AUDIO] Unable to retrieve SirenDieSource") 
	end
    if not self.dipSFX then 
		Engine.Log("[SIREN AUDIO] Unable to retrieve DipSource") 
	end


end

-- ── Start ─────────────────────────────────────────────────────────────────
function Start(self)
    Game.SetTimeScale(1.0)

    self.hp             = self.public.maxHp
    self.isDead         = false
    self.playerInRange  = false
    self.alreadyHit     = false
    self.pendingDestroy = false
    self.deathTimer     = 2.5

    self.currentState = State.IDLE
    self.currentY     = 0
    self.targetY      = 0
    self.playerGO     = nil
    self.rb           = self.gameObject:GetComponent("Rigidbody")
    self.anim         = self.gameObject:GetComponent("Animation")

-- -- audio source components
    self.singSFX = nil
    self.deathSFX = nil
    self.hurtSFX = nil
    self.dipSFX = nil

    FindSirenAudioComponents(self)

    self.windUpTimer   = 0
    self.cooldownTimer = 0
    self.hideCooldownTimer = 0
    self.hideDurationTimer = 0
    self.activeShells  = {}

    self.hasDeathPlayed = false
    self.hasHurtPlayed = false
    self.isSinging = false

    Prefab.Load("Sirena_Bullet", finalPath)
    Prefab.Load("Sirenfeedback", finalPath_Feedback)

    if self.rb then
        self.rb:SetLinearVelocity(0, 0, 0)
    end

    Engine.Log("[Mortar] Initialized. HP=" .. self.hp
             .. " detectRange=" .. self.public.detectRange)
end

-- Update
function Update(self, dt)
    if not self.gameObject then return end

    if Input.GetKey("0") then
        TakeDamage(self, self.hp, self.transform.worldPosition)
        return
    end

    if self.isDead then
        self.deathTimer = self.deathTimer - dt
        local pos = self.transform.position
        self.transform:SetPosition(pos.x, pos.y - 0.5 * dt, pos.z)
        if self.deathTimer <= 0 then
            self:Destroy()
        end
        return
    end

    if _PlayerController_lastAttack == nil or _PlayerController_lastAttack == "" then
        self.alreadyHit = false
    end

    -- Simular proyectiles en vuelo
    UpdateShells(self, dt)

    -- Retry components if missing
    if not self.rb then
        self.rb = self.gameObject:GetComponent("Rigidbody")
    end

    if not self.anim then
        self.anim = self.gameObject:GetComponent("Animation")
    end

    if not self.dipSFX or not self.hurtSFX or not self.deathSFX or not self.singSFX then
        FindSirenAudioComponents(self)
    end

    -- Keep the mortar still
    if self.rb then
        local vel = self.rb:GetLinearVelocity()
        if vel then
            self.rb:SetLinearVelocity(0, vel.y, 0)
        end
    end

    -- Search player
    if not self.playerGO then
        self.playerGO = GameObject.Find("Player")
        if self.playerGO then
            Engine.Log("[Mortar] Player encontrado")
        end
    end

    if not self.playerGO then return end

    if _EnemyPendingDamage and _EnemyPendingDamage[self.gameObject.name] then
        TakeDamage(self, _EnemyPendingDamage[self.gameObject.name], self.transform.worldPosition)
        _EnemyPendingDamage[self.gameObject.name] = nil
    end

    --just in case hideCooldownTimer is nil
    self.hideCooldownTimer = (self.hideCooldownTimer or 0) - dt

    if self.hideCooldownTimer < 0 then 
        self.hideCooldownTimer = 0 
    end

    local playerAttack = _PlayerController_lastAttack

    local myPos = self.transform.position
    local pp    = self.playerGO.transform.position
    if not pp then return end

    local distX = pp.x - myPos.x
    local distZ = pp.z - myPos.z
    local dist  = sqrt(distX * distX + distZ * distZ)

    if playerAttack ~= "" and self.hideCooldownTimer <= 0 and self.currentState ~= State.HIDE then
        local currentEvadeChance = EVADE_CHANCE
        if dist < 5.0 then
            currentEvadeChance = 0.9
        end

        if math.random() < currentEvadeChance then
            self.currentState = State.HIDE
            self.hideDurationTimer = HIDE_MAX_DURATION
            self.hideCooldownTimer = HIDE_COOLDOWN
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
            Engine.Log("[Siren] ¡Ataque detectado! Sumergiéndose...")
        else
            self.hideCooldownTimer = 0.5 
        end
    end

    -- State machine

    if     self.currentState == State.HIDE     then UpdateHide(self, dt)
    elseif self.currentState == State.IDLE     then UpdateIdle(self, dist, dt)
    elseif self.currentState == State.WINDUP   then UpdateWindUp(self, pp, dist, dt)
    elseif self.currentState == State.COOLDOWN then UpdateCooldown(self, dist, dt)
    end

    --Engine.Log("[Siren] State: " .. tostring(self.currentState) .. " dist: " .. string.format("%.1f", dist))

    if self.pendingDestroy then
        self:Destroy()
        self.pendingDestroy = false
    end
end

-- OnTriggerEnter
function OnTriggerEnter(self, other)
    if self.isDead or self.currentState == State.HIDE then return end

	if not other then Engine.Log("[SIREN] other was nil"); return end

    if other:CompareTag("Player") or other:CompareTag("Bullet") then
        if not self.alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                self.alreadyHit = true
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
	if not other then Engine.Log("[SIREN] other was nil"); return end

    if other:CompareTag("Player") or other:CompareTag("Bullet") then
        self.alreadyHit = false
    end
end





