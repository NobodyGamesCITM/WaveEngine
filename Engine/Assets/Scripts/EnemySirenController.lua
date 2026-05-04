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

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

_EnemyDamage_mortar = 30

local HIDE_MAX_DURATION = 1.0
local HIDE_COOLDOWN     = 2.5  
local EVADE_CHANCE      = 0.6  
local hitCooldown = 0

local BaseMat = nil

public = {
    level2 = false,
}

-- Public (movido a self.public dentro de Start para evitar conflictos entre enemigos)

local finalPath  = Engine.GetAssetsPath() .. "/Prefabs/Sirena_Bullet.prefab"
local finalPath_Feedback  = Engine.GetAssetsPath() .. "/Prefabs/Sirenfeedback.prefab"

-- Helpers
local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function ChangeState(self, newState)  -- local: no interfiere con otros scripts
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

    self.hp = self.hp - amount
    Engine.Log("[Mortar] HP: " .. self.hp .. "/" .. self.public.maxHp)

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
        self.pendingDestroy = true

        if self.singSFX then self.singSFX:StopAudioEvent() end
        if self.dipSFX then self.dipSFX:StopAudioEvent() end

        if self.anim then
        	if not self.anim:IsPlayingAnimation("Die") then
				if self.deathSFX then 
                    Engine.Log("Played Siren DeathSFX")
                    self.deathSFX:PlayAudioEvent() 
                end
            	if self.anim then self.anim:Play("Die") end
			end
		end

        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07

        for _, shell in ipairs(self.activeShells) do
            if shell.shadowGo then pcall(function() GameObject.Destroy(shell.shadowGo) end) end
            SafeDestroyShell(shell)
        end
        self.activeShells = {}

        Engine.Log("[Mortar] DEAD")
    else
        if self.hurtSFX then 
            if self.singSFX then self.singSFX:StopAudioEvent() end
            if self.hurtSFX then self.hurtSFX:PlayAudioEvent() end
            Engine.Log("[SIREN AUDIO] Hurt SFX Played")
            self.isSinging = false    
            if self.anim then self.anim:Play("Hurt") end
        end
    
       
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

        local feedback = self.windupFeedback
        self.windupFeedback = nil
        self.windupFeedbackSet = false

        table.insert(self.activeShells, {
            go         = shell,
            shadowGo         = feedback,
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

local function SyncCollider(self)
    if not self.colliderRoot then return end

    local mesh = GameObject.FindInChildren(self.gameObject, "SirenMesh")
    if not mesh then return end

    local meshTr = mesh.transform
    local colTr  = self.colliderRoot.transform

    colTr:SetPosition(
        meshTr.position.x,
        meshTr.position.y,
        meshTr.position.z
    )

    colTr:SetRotation(
        meshTr.rotation.x,
        meshTr.rotation.y,
        meshTr.rotation.z
    )
end

local function UpdateHeight(self, targetOffset, dt)
    self.currentYOffset = self.currentYOffset + (targetOffset - self.currentYOffset) * dt * self.public.riseSpeed
    
    local pos = self.transform.position
    pos.y = self.baseY + self.currentYOffset
    self.transform:SetPosition(pos.x, pos.y, pos.z)
    if self.currentYOffset < 0.2 then
        if not self.isFullyHidden then
            self.isFullyHidden = true
            -- Engine.Log("[Siren] Sumergida: Invulnerable")
        end
    else
        if self.isFullyHidden then
            self.isFullyHidden = false
            -- Engine.Log("[Siren] Visible: Vulnerable")
        end
    end
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
                local scale = self.public.blastRadius
                tr:SetScale(scale*2, 0.03, scale*2)
                s.feedbackSet = true

            end
        end
        
        s.age = s.age + (dt*2)

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
                    local impDx   = pp.x - s.targetX
                    local impDz   = pp.z - s.targetZ
                    local impDist = sqrt(impDx * impDx + impDz * impDz)

                    if impDist <= self.public.blastRadius then
                        local factor = 1.0 - (impDist / self.public.blastRadius) * 0.5
                        local dmg    = math.max(math.floor(self.public.attackDamage * factor), 1)
                        if not _G._PlayerController_isDead then
                            if (_PlayerController_pendingDamage or 0) == 0 then
                                _PlayerController_pendingDamage    = dmg
                                _PlayerController_pendingDamagePos = { x =  s.targetX, y = y, z =  s.targetZ }
                                Engine.Log("[Mortar] HIT PLAYER for " .. dmg
                                        .. " (dist=" .. string.format("%.2f", impDist) .. ")")
                                Engine.Log("[Mortar] targetX=" .. string.format("%.2f", s.targetX) 
                                .. " x=" .. string.format("%.2f", x)
                                .. " targetZ=" .. string.format("%.2f", s.targetZ)
                                .. " z=" .. string.format("%.2f", z)
                                .. " playerDist=" .. string.format("%.2f", impDist)
                                .. " blastRadius=" .. string.format("%.2f", self.public.blastRadius))
                            end
                        end
                    end
                end
            end

            SafeDestroyShell(s)
            table.remove(self.activeShells, i)
        end
    end
end


local function UpdateHide(self, dt)
    UpdateHeight(self, 0, dt)
    if self.anim and not self.anim:IsPlayingAnimation("Hide") then
        self.anim:Play("Hide")
        if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        self.isFullyHidden = false
        self.hideAnimTimer = 0
    end

    if not self.isFullyHidden then
        self.hideAnimTimer = (self.hideAnimTimer or 0) + dt
        if self.hideAnimTimer >= 0.2 then
            self.isFullyHidden = true
            Engine.Log("[Siren] Completamente escondida. Ahora es invulnerable.")
        end
    end



    self.hideDurationTimer = (self.hideDurationTimer or 0) - dt

    if _PlayerController_lastAttack ~= "" then
        self.hideDurationTimer = 2 
    end

    if self.hideDurationTimer <= 0 then
        self.isFullyHidden = false
        self.hideAnimTimer = 0
        self.currentState = State.IDLE
        Engine.Log("[Siren] El player paró de atacar. Salgo a contraatacar.")
    end
end

local function UpdateIdle(self, dist, dt)
    
    if _G.PlayerInMountain == true then
        if anim and not anim:IsPlayingAnimation("Idle") then
            anim:Play("Idle", 0.2)
        end
        return
    end
        
    UpdateHeight(self, 0, dt)
    if dist <= self.public.detectRange and dist >= self.public.minRange then

        if not self.isShowing and not self.playerInRange then
            if self.anim then 
                self.anim:Play("Show")
                Engine.Log("[SIREN] Ejecutando Show")
            end
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
            
            self.isShowing = true
            self.playerInRange = true
            
            return 
        end

        if self.playerInRange then
            Engine.Log("Triggering Combat Music from Siren detection range")
            _G.TriggerCombatMusic()
        end

        if self.isShowing then
            self.isShowing = false 
            
            if self.anim then self.anim:Play("Look") end
            
            if not self.isSinging then
                if self.singSFX then self.singSFX:PlayAudioEvent() end
                self.isSinging = true
            end
            
            self.windUpTimer = 0
            ChangeState(self, State.WINDUP)
        end

        

    else
        if self.playerInRange then

            
            if self.anim and not self.anim:IsPlayingAnimation("Hide") then
                self.anim:Play("Hide")
                if self.dipSFX then self.dipSFX:PlayAudioEvent() end
            end
            self.playerInRange = false
            self.isShowing = false
            if self.isSinging then
                if self.singSFX then self.singSFX:StopAudioEvent() end
                self.isSinging = false
            end

            if self.windupFeedback then
                pcall(function() GameObject.Destroy(self.windupFeedback) end)
                self.windupFeedback = nil
                self.windupFeedbackSet = false
            end

        end
    end 
end

local function UpdateWindUp(self, pp, dist, dt)
    UpdateHeight(self, self.public.riseHeight, dt)
    FacePlayer(self, pp, dt)
    self.windUpTimer = self.windUpTimer + dt

    if not self.windupFeedback then
        Prefab.Load("Sirenfeedback", finalPath_Feedback)
        self.windupFeedback = Prefab.Instantiate("Sirenfeedback")
        self.windupFeedbackSet = false
    end

    if self.windupFeedback then
        pcall(function()
            local scale = self.public.blastRadius * 2
            self.windupFeedback.transform:SetPosition(pp.x, pp.y + 0.3, pp.z)
            self.windupFeedback.transform:SetScale(scale, 0.03, scale)
            self.windupFeedbackSet = true
        end)
    end


    if dist > self.public.detectRange or dist < self.public.minRange then
        if self.windupFeedback then
            pcall(function() GameObject.Destroy(self.windupFeedback) end)
            self.windupFeedback = nil
            self.windupFeedbackSet = false
        end

        self.currentState = State.COOLDOWN
        self.cooldownTimer       = self.public.cooldownTime * 0.4
        Engine.Log("[Mortar] Player fuera de rango. Abortando disparo.")
        return
    end

    if self.windUpTimer >= self.public.windUpTime then
        FireShell(self, pp.x, pp.y, pp.z)
        if self.anim then self.anim:Play("Shoot") end
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

local function UpdateCooldown(self, dist, dt)
    UpdateHeight(self, 0, dt)
    if self.cooldownTimer < (self.public.cooldownTime - 0.4) then
        if self.anim and not self.anim:IsPlayingAnimation("Hide") then
            self.anim:Play("Hide")
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        end
    end

    self.cooldownTimer = self.cooldownTimer - dt

    if self.cooldownTimer <= 0 then
        self.currentState = State.IDLE
        self.isShowing = false

        ChangeState(self, State.IDLE)

        if self.anim and not self.anim:IsPlayingAnimation("Show") then
            self.anim:Play("Show")
            if self.dipSFX then self.dipSFX:PlayAudioEvent() end
        end
        if dist <= self.public.detectRange and dist >= self.public.minRange then
            self.currentState = State.WINDUP
            self.windUpTimer         = 0
            Engine.Log("[Mortar] Cooldown listo. Nuevo wind-up.")
        end
    end
end

local function FindSirenAudioComponents(self)  -- local: no interfiere con otros scripts
    Engine.Log("[SIREN AUDIO] Searching in: " .. tostring(self.gameObject.name))
    
    local singSource = GameObject.FindInChildren(self.gameObject, "SingSource")
    Engine.Log("[SIREN AUDIO] SingSource found: " .. tostring(singSource ~= nil))
    
    local dieSource = GameObject.FindInChildren(self.gameObject, "SirenDieSource")
    Engine.Log("[SIREN AUDIO] DieSource found: " .. tostring(dieSource ~= nil))
    
    local hurtSource = GameObject.FindInChildren(self.gameObject, "SirenHurtSource")
    Engine.Log("[SIREN AUDIO] HurtSource found: " .. tostring(hurtSource ~= nil))
    
    local dipSource = GameObject.FindInChildren(self.gameObject, "DipSource")
    Engine.Log("[SIREN AUDIO] DipSource found: " .. tostring(dipSource ~= nil))


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

-- Start
function Start(self)
    Game.SetTimeScale(1.0)
     local isLevel2 = self.public.level2

    self.public = {
        maxHp            = 50,
        knockbackForce   = 3.0,

        detectRange      = 22.0,   -- distancia máxima para disparar
        minRange         = 5.0,    -- punto ciego: si el player está muy cerca no dispara

        windUpTime       = 1.6,    -- segundos de telegrafía antes del disparo
        flightTime       = 4.0,    -- duración del arco en el aire
        cooldownTime     = 4.5,    -- espera entre disparos

        blastRadius      = 3.0,   -- radio de daño en el impacto
        attackDamage     = 30,     -- daño máximo (en el centro de la explosión)

        barrelOffsetY    = 1.8,    -- altura del punto de disparo sobre el pivot
        rotationSpeed    = 6.0,    -- velocidad de giro para encarar al player

        projectilePrefab = "Sirena_Bullet",  -- nombre del prefab del proyectil
        maxLifetime      = 10.0,
        riseHeight       = 1.0,
        riseSpeed        = 3.0,
        level2 = isLevel2,
    }

    self.hp             = self.public.maxHp
    self.isDead         = false
    self.playerInRange  = false
    self.pendingDestroy = false
 

    self.isFullyHidden = false
    self.hideAnimTimer = 0

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
    self.deathTimer     = 2.5
    self.deathTime = 2.5
    self.activeShells  = {}

    self.hasDeathPlayed = false
    self.hasHurtPlayed = false
    self.isSinging = false
    self.isShowing = false
    self.alreadyHit = false

    self.windupFeedback = nil
    self.windupFeedbackSet = false

    Prefab.Load("Sirena_Bullet", finalPath)
    Prefab.Load("Sirenfeedback", finalPath_Feedback)

    if self.rb then
        self.rb:SetLinearVelocity(0, 0, 0)
    end

    Engine.Log("[Mortar] Initialized. HP=" .. self.hp
             .. " detectRange=" .. self.public.detectRange)
    
   self.anim:Play("Hide")

    sirenMesh = GameObject.FindInChildren(self.gameObject,"SirenMesh")
    BaseMat = sirenMesh:GetComponent("Material")

    if self.public.level2 then
        BaseMat.SetTexture("10973116870485554369")
    else
        BaseMat.SetTexture("8896541361096085563")
    end

    self.baseY = self.transform.position.y
    self.currentYOffset = 0
end

-- Update
function Update(self, dt)
    if not self.gameObject then return end


    if self.pendingDestroy and self.deathTimer <= 0 then
        self.deathTimer = 2.5
        Engine.Log("Destroyed Siren")
        _G.TriggerExplorationMusic()
        self:Destroy() 

        return  
    end

    if Input.GetKey("0") then
        TakeDamage(self, self.hp, self.transform.worldPosition)
        return
    end


    if self.isDead then
        if self.windupFeedback then
            pcall(function() GameObject.Destroy(self.windupFeedback) end)
            self.windupFeedback = nil
            self.windupFeedbackSet = false
        end
        self.deathTimer = self.deathTimer - dt
        local pos = self.transform.position
        self.transform:SetPosition(pos.x, pos.y - 0.5 * dt, pos.z)

        if self.deathTimer <= 0 then
            Engine.Log("Siren pending to destroy")
            self.pendingDestroy = true
            
        end
        return
    end

    if _PlayerController_lastAttack == nil or _PlayerController_lastAttack == "" then
        self.alreadyHit = false
    end

    if _G._PlayerController_isDead then
        UpdateShells(self, dt)
        return
    end

    if hitCooldown > 0 then
        hitCooldown = hitCooldown - dt
        if hitCooldown <= 0 then
            self.alreadyHit = false
            if self.public.level2 then
                BaseMat.SetTexture("10973116870485554369")
            else
                BaseMat.SetTexture("8896541361096085563")
            end
        end
    end

    
    -- Proyectules
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

    if not sirenMesh then 
        sirenMesh = GameObject.FindInChildren(self.gameObject,"SirenMesh")
    end

    if not BaseMat then
        if sirenMesh then BaseMat = sirenMesh:GetComponent("Material") end
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
    local pp    = self.playerGO.transform.worldPosition
    if not pp then return end

    local distX = pp.x - myPos.x
    local distZ = pp.z - myPos.z
    local dist  = sqrt(distX * distX + distZ * distZ)

    -- State machine

    if     self.currentState == State.HIDE     then UpdateHide(self, dt)
    elseif self.currentState == State.IDLE     then UpdateIdle(self, dist, dt)
    elseif self.currentState == State.WINDUP   then UpdateWindUp(self, pp, dist, dt)
    elseif self.currentState == State.COOLDOWN then UpdateCooldown(self, dist, dt)
    end


end

-- OnTriggerEnter
function OnTriggerEnter(self, other)
    if  self.isDead or self.currentState == State.HIDE or self.currentState == State.COOLDOWN then return end

	if not other then Engine.Log("[SIREN] other was nil"); return end

    if other:CompareTag("Player") then
        if not self.alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                self.alreadyHit = true
                if BaseMat then
                    BaseMat.SetTexture("1496995762458507062")
                else
                    Engine.Log("BaseMat not found in Siren")
                end
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end
    end

    if other:CompareTag("Bullet") then
        -- La bala golpea a la sirena
        if not alreadyHit then
            local ap  = other.transform.worldPosition
            self.alreadyHit = true
            hitCooldown = 0.2
            if BaseMat then 
                BaseMat.SetTexture("1496995762458507062")
            else
                Engine.Log("BaseMat not found in Siren")
            end
            TakeDamage(self, self.hp, ap)
        end
    end
end

-- OnTriggerExit
function OnTriggerExit(self, other)
	if not other then Engine.Log("[SIREN] other was nil"); return end

    if other:CompareTag("Player") then
        if self.public.level2 then
            BaseMat.SetTexture("10973116870485554369")
        else
            BaseMat.SetTexture("8896541361096085563")
        end
    end
end
