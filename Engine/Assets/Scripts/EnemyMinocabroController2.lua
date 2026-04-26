local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- States
local State = {
    IDLE        = "Idle",
    CHASE      = "Chase", --Searching and walking to player
    REPOSITION  = "Reposition", -- Getting away if player is too close
    ANTICIPATION = "Anticipation", -- Waiting before charging
    CHARGE      = "Charge", -- Running to hit
    WALL        = "Wall", --Stunned because hit a wall
    RECOVERY = "Recovery", --Recovering after charge
    DEAD        = "Dead",
}

-- Public variables (ahora viven en self.public dentro de Start para evitar conflictos globales)

-- Internal variables





-- Inertia after charge (sliding)

_EnemyDamage_minocabro = 35

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25


local hitCooldown = 0

local BaseMat = nil

-- Helpers
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

local function PlayAnim(self, name, blend)
    if self.anim then self.anim:Play(name, blend or 0.15) end
end

local function Dist(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return sqrt(dx*dx + dz*dz)
end

local function RotateTowards(self, dirX, dirZ, speed, dt)
    if abs(dirX) < 0.01 and abs(dirZ) < 0.01 then return end
    local targetAngle = atan2(dirX, dirZ) * (180.0 / pi)
    local diff = shortAngleDiff(self.currentYaw, targetAngle)
    self.currentYaw = self.currentYaw + diff * speed * dt
    self.rb:SetRotation(0, self.currentYaw, 0)
end 

local function StopMovement(self)
    if not self.rb then return end
    local vel = self.rb:GetLinearVelocity()
    self.rb:SetLinearVelocity(0, vel.y, 0)
    self.smoothDx, self.smoothDz = 0, 0
end


local function ChangeState(self, newState)
    self.currentState = newState
    Engine.Log("[Minocabro] -> " .. newState)

    if newState == State.CHARGE then
        if self.voiceSFX then  self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoCharge") end
    elseif newState == State.WALL then
        if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoStun") end
    elseif newState == State.ANTICIPATION then
        if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoRoar") end
    elseif newState == State.DEAD then
        if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoDeath") end
    end
end

local function TakeDamage(self, amount, attackerPos)
    if self.isDead then return end

    self.hp = self.hp - amount
    Engine.Log("[Minocabro] HP: " .. self.hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if self.rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx/len; dz = dz/len end
        self.rb:AddForce((dx * self.public.knockbackForce) / 10, 0, (dz * self.public.knockbackForce) / 10, 2)
    end

    if self.hp <= 0 then
        if self.anim then self.anim:Play("Death") end
        ChangeState(self, State.DEAD)
    else
        
        if self.voiceSFX then self.voiceSFX:SelectPlayAudioEvent("SFX_MinoHurt") end
        
        if self.anim then self.anim:Play("Hurt") end
        StopMovement(self)

        self.wallStunTimer = self.public.hurtStunTime
        self.wallStunTimer = self.wallStunTimer - dt
        if self.wallStunTimer <= 0 then
            ChangeState(self, State.RECOVERY)
        end

    end
end

-- State functions
local function UpdateIdle(self, dist)
    if dist <= self.public.detectRange then
        ChangeState(self, State.CHASE)
    end
    --if self.anim and not self.anim:IsPlayingAnimation("Idle") then
        --self.anim:Play("Idle")
    --end
end

local function UpdateChase(self, myPos, pp, dist, dt)
    local dx = pp.x - myPos.x
    local dy = pp.y - myPos.y
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    -- Volver a IDLE si el player está muy lejos o en diferente altura (plataforma distinta)
    if dist > self.public.detectRange or abs(dy) > 3.0 then
        StopMovement(self)
        ChangeState(self, State.IDLE)
        return
    end

    if dist < self.public.tooCloseRange then
        ChangeState(self, State.REPOSITION)
    
    elseif dist <= self.public.chargeRange then
        self.chargeDirX       = dx
        self.chargeDirZ       = dz
        self.preparationTimer = 0
        StopMovement(self)
        ChangeState(self, State.ANTICIPATION)
    
    else
        Engine.Log("updatecombat andar")
        if self.anim and not self.anim:IsPlayingAnimation("Walk") then self.anim:Play("Walk", 0.2) end
      
        if self.stepTimer >= 0.5 then
            self.stepTimer = 0
            if self.stepSFX then self.stepSFX:PlayAudioEvent() end
        end

        local vel = self.public.moveSpeed
        local cv = self.rb:GetLinearVelocity()
        RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)

        self.rb:SetLinearVelocity(dx * vel, cv.y, dz * vel)

    end
end

local function UpdateReposition(self, myPos, pp, dist, dt)
    if self.anim and not self.anim:IsPlayingAnimation("Idle") then self.anim:Play("Idle") end

    -- Opposite direction to the player
    local dx = myPos.x - pp.x
    local dz = myPos.z - pp.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    local lookDx = pp.x - myPos.x
    local lookDz = pp.z - myPos.z

    local vel = self.public.moveSpeed

    local currentVel = self.rb:GetLinearVelocity()
    self.rb:SetLinearVelocity(dx*vel,currentVel.y,dz*vel)

    RotateTowards(self, lookDx, lookDz, self.public.rotationSpeed, dt)


    if dist >= self.public.tooCloseRange + 0.5 then
        StopMovement(self)
        ChangeState(self, State.CHASE)
    end
end

local function UpdateAnticipation(self, pp, dt)
    local myPos = self.transform.worldPosition
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
    --StopMovement(self)

    if self.anim and not self.anim:IsPlayingAnimation("PreCharge") then
        PlayAnim(self, "PreCharge")
        if self.voiceSFX then 
            self.voiceSFX:StopAudioEvent()
            self.voiceSFX:SelectPlayAudioEvent("SFX_MinoPrecharge") 
        end

    end

    if self.chargeFeedbackGO then
        --Maximum possible distance
        local maxChargeDistance = self.public.chargeSpeed * self.public.chargeDuration
        
        -- Vcetor distance player
        local vectorToPlayerX = pp.x - myPos.x
        local vectorToPlayerZ = pp.z - myPos.z
        local currentDistToPlayer = sqrt(vectorToPlayerX * vectorToPlayerX + vectorToPlayerZ * vectorToPlayerZ)

        -- Trim the indicator if the player is closer than the max range
        local indicatorLength = maxChargeDistance
        if currentDistToPlayer < maxChargeDistance then
            indicatorLength = currentDistToPlayer
        end

        local distance = sqrt(dx*dx + dz*dz)
        local directionX, directionZ = dx, dz
        if distance > 0.001 then 
            directionX = dx / distance 
            directionZ = dz / distance 
        end

        -- Calculate the center position
        local positionX = myPos.x + directionX * (indicatorLength * 0.5)
        local positionY = pp.y + 0.1
        local positionZ = myPos.z + directionZ * (indicatorLength * 0.5)

        local rotationAngle = atan2(directionX, directionZ) * (180.0 / pi)

        self.chargeFeedbackGO.transform:SetPosition(positionX, positionY, positionZ)
        self.chargeFeedbackGO.transform:SetRotation(0, rotationAngle, 0)
        self.chargeFeedbackGO.transform:SetScale(2.0, 0.05, indicatorLength)
    end


    self.preparationTimer = self.preparationTimer + dt

    if self.rb and self.preparationTimer < (self.public.preparationTime * 0.5) then
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            local backDx = -(dx / len)
            local backDz = -(dz / len)
            local vel = self.rb:GetLinearVelocity()
            self.rb:SetLinearVelocity(backDx * 2.0, vel.y, backDz * 2.0)
        end
    else
        StopMovement(self)
    end

    if self.preparationTimer >= self.public.preparationTime then
        local predictedX = pp.x
        local predictedZ = pp.z

        if self.rb then
            local predictionVel = self.rb:GetLinearVelocity()
            local time = self.public.predictionTime
            predictedX = pp.x + predictionVel.x * time
            predictedZ = pp.z + predictionVel.z * time
        end

        local predictionDx= predictedX - myPos.x
        local predictionDz= predictedZ - myPos.z
        local len = sqrt(predictionDx*predictionDx + predictionDz*predictionDz)
        if len > 0.001 then
            self.chargeDirX, self.chargeDirZ = predictionDx/len, predictionDz/len
        end
        self.chargeTimer = 0
        ChangeState(self, State.CHARGE)
    end

    --if self.preparationTimer >= self.public.preparationTime then
        -- Recalculate final direction
        --local len = sqrt(dx*dx + dz*dz)
        --if len > 0.001 then
            --self.chargeDirX, self.chargeDirZ = dx/len, dz/len
        --end
        --self.chargeTimer = 0
        --ChangeState(self, State.CHARGE)
    --end
end

local function UpdateCharge(self, dt)

    if self.stepTimer >= 0.25 then
        self.stepTimer = 0
        if self.stepSFX then 
            self.stepSFX:PlayAudioEvent() 
        end
    end

    if self.anim and not self.anim:IsPlayingAnimation("Charge") then
        PlayAnim(self, "Charge")

    end

    self.chargeTimer = self.chargeTimer + dt

    if self.rb then
        local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(self.chargeDirX * self.public.chargeSpeed, 0, self.chargeDirZ * self.public.chargeSpeed)

        if self.chargeTimer > 0.2 then
            local actualSpeed = sqrt(vel.x*vel.x + vel.z*vel.z)
            if actualSpeed < self.public.wallSpeedThresh then
                self.alreadyHit = false
                StopMovement(self)
                self.wallStunTimer = self.public.wallStunTime
                ChangeState(self, State.WALL)
                return
            end
        end
    end

    if not self.attackCol then self.attackCol = self.gameObject:GetComponent("Box Collider") end
    if self.attackCol then self.attackCol:Enable() end

    if self.chargeTimer >= self.public.chargeDuration then
        if self.attackCol then self.attackCol:Disable() end
        --Save direction for after
        self.slideVelX = self.chargeDirX * 8.0
        self.slideVelZ = self.chargeDirZ * 8.0
        
        self.wallStunTimer = self.public.afterStunTime

        if self.anim and not self.anim:IsPlayingAnimation("Idle") then
            self.anim:Play("Idle", 0.3)
        end

        ChangeState(self, State.RECOVERY)
    end
end

local function UpdateWall(self, dt)
    if self.rb then
        local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(0, vel.y, 0)
        self.rb:SetRotation(0, self.currentYaw, 0)
    end

    if self.anim and not self.anim:IsPlayingAnimation("Wall") then
        PlayAnim(self, "Wall")
    end

    self.wallStunTimer = self.wallStunTimer - dt
    if self.wallStunTimer <= 0 then
        self.slideVelX = 0
        self.slideVelZ = 0
        self.wallStunTimer = self.public.afterStunTime
        self.cameFromWall = true
        
        if self.anim and not self.anim:IsPlayingAnimation("Idle") then
            self.anim:Play("Idle", 0.3)
        end
        ChangeState(self, State.RECOVERY)
    end
end

local function UpdateRecovery(self, dt)
  
    if self.playerGO and not self.cameFromWall then
        local myPos = self.transform.worldPosition
        local pp = self.playerGO.transform.worldPosition
        local dx = pp.x - myPos.x
        local dz = pp.z - myPos.z
        RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
    end

    local friction = self.public.stopSmoothing
    self.slideVelX = self.slideVelX + (0 - self.slideVelX) * min(1.0, dt * friction)
    self.slideVelZ = self.slideVelZ + (0 - self.slideVelZ) * min(1.0, dt * friction)
 
    if self.rb then
        local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(self.slideVelX, vel.y, self.slideVelZ)
    end

    self.wallStunTimer = self.wallStunTimer - dt
    if self.wallStunTimer <= 0 then
        self.cameFromWall = false
        ChangeState(self, State.CHASE)
    end
end

local function UpdateDeath(self,dt)
    self.deathTimer = self.deathTimer - dt
    
    if self.deathTimer <= 0 then
        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end

        local _rb  = self.rb

        self.rb       = nil
        self.anim     = nil
        self.playerGO = nil
        
        if _rb  then
            local vel = _rb:GetLinearVelocity()
            _rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        Engine.Log("[Minocabro] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.1
        self.isDead = true

        self:Destroy()
  
    end
end

          
function Start(self)
    -- Definimos los datos SOLO para este enemigo (self.public evita conflictos globales)
    self.public = {
        maxHp           = 60,
        detectRange     = 15.0,
        tooCloseRange   = 3.5,
        chargeRange     = 12.0,

        preparationTime = 3.0,
        chargeSpeed     = 18.0,
        chargeDuration  = 0.8,
        knockbackForce  = 8.0,
        wallStunTime    = 5.0,
        wallSpeedThresh = 1.5,

        --Movement
        moveSpeed       = 10.0,
        rotationSpeed   = 3.0,

        stopSmoothing   = 8.0,

        hurtStunTime = 0.8,
        afterStunTime = 2.2,

        enemyDamageMin = 5,
        enemyDamageMax = 35,

        predictionTime = 0.4,
    }

    self.hp               = self.public.maxHp
    self.isDead           = false
    self.currentState     = State.IDLE
    self.deathTimer       = 3.5
    self.alreadyHit       = false
    self.attackCol        = nil
    self.playerAttackHandled = false
    self.smoothDx         = 0
    self.smoothDz         = 0
    self.wallStunTimer    = 0
    self.preparationTimer = 0
    self.chargeTimer      = 0
    self.currentYaw       = 0
    self.chargeDirX       = 0
    self.chargeDirZ       = 1
    self.slideVelX        = 0
    self.slideVelZ        = 0
    self.cameFromWall     = false
    self.pendingWallHit   = false
    self.playerGO         = nil
    self.chargeFeedbackGO = nil
    self.stepTimer        = 0.5

    self.rb   = self.gameObject:GetComponent("Rigidbody")
    self.anim = self.gameObject:GetComponent("Animation")

    self.stepSource = GameObject.FindInChildren(self.gameObject, "MinoStepSource")
    self.voiceSource = GameObject.FindInChildren(self.gameObject, "MinoVoiceSource")
    
   
    if self.stepSource then
        self.stepSFX = self.stepSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for steps not found") end

    if self.voiceSource then
        self.voiceSFX = self.voiceSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for voice not found") end

    self.stepTimer = 0.5

    if self.anim then self.anim:Play("Idle") end

    self.attackCol = self.gameObject:GetComponent("Box Collider")
    if self.attackCol then
        self.attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    Engine.Log("[Minocabro] Start OK  HP=" .. self.hp)

    Prefab.Load("MinocabroFeedback", Engine.GetAssetsPath() .. "/Prefabs/MinocabroFeedback.prefab")
    self.chargeFeedbackGO = nil

    --MinocabrpMesh
    mesh = GameObject.FindInChildren(self.gameObject,"Mesh")
    BaseMat = mesh:GetComponent("Material")
end

function Update(self, dt)
    if not self.gameObject or self.isDead then return end

    -- Defensive nil checks in case Start didn't fully run
    if self.stepTimer      == nil then self.stepTimer      = 0 end
    if self.wallStunTimer  == nil then self.wallStunTimer  = 0 end
    if self.currentState   == nil then self.currentState   = State.IDLE end
    if self.chargeDirX     == nil then self.chargeDirX     = 0 end
    if self.chargeDirZ     == nil then self.chargeDirZ     = 1 end
    if self.slideVelX      == nil then self.slideVelX      = 0 end
    if self.slideVelZ      == nil then self.slideVelZ      = 0 end
    if self.preparationTimer == nil then self.preparationTimer = 0 end
    if self.chargeTimer    == nil then self.chargeTimer    = 0 end
    if self.currentYaw     == nil then self.currentYaw     = 0 end
    if self.cameFromWall   == nil then self.cameFromWall   = false end
    if self.pendingWallHit == nil then self.pendingWallHit = false end
    if self.alreadyHit     == nil then self.alreadyHit     = false end

    if not self.rb   then self.rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not self.anim then self.anim = self.gameObject:GetComponent("Animation")  end

    if Input.GetKey("0") then
        TakeDamage(self, self.hp, self.transform.worldPosition)
        return
    end

        -- Trigger Wall
    if self.pendingWallHit then
        self.pendingWallHit = false
        if self.currentState ~= State.WALL and self.currentState ~= State.RECOVERY then
            StopMovement(self)
            if self.chargeFeedbackGO then
                GameObject.Destroy(self.chargeFeedbackGO)
                self.chargeFeedbackGO = nil
            end
            self.wallStunTimer = self.public.wallStunTime
            ChangeState(self, State.WALL)
        end
    end

    -- Receive Damage
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not self.playerAttackHandled and self.playerGO and not self.isDead then
            local myPos = self.transform.position
            local pp    = self.playerGO.transform.position
            if pp then
                local dx   = pp.x - myPos.x
                local dz   = pp.z - myPos.z
                local dist = sqrt(dx * dx + dz * dz)
                if dist <= (self.public.chargeRange * 0.5) then
                    self.playerAttackHandled = true
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
        self.playerAttackHandled = false
    end

    -- Search Player
    if not self.playerGO then
        self.playerGO = GameObject.Find("Player")
    end
    if not self.playerGO or _G._PlayerController_isDead then return end

    
    if hitCooldown > 0 then
        hitCooldown = hitCooldown - dt
        if hitCooldown <= 0 then
            self.alreadyHit = false
            BaseMat.SetTexture("15634858790036886356")
        end
    end
    
    self.stepTimer = self.stepTimer + dt
    local myPos = self.transform.worldPosition
    local pp    = self.playerGO.transform.worldPosition
    if not pp then return end

    local dist = Dist(myPos, pp)

-- Instantiate/destroy feedback BEFORE calling the state
    if self.currentState == State.ANTICIPATION then
        if not self.chargeFeedbackGO then
            self.chargeFeedbackGO = Prefab.Instantiate("MinocabroFeedback")
        end
    elseif self.currentState == State.RECOVERY then
        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end
    end

    -- State machine
    if     self.currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif self.currentState == State.CHASE       then UpdateChase(self, myPos, pp, dist, dt)
    elseif self.currentState == State.REPOSITION   then UpdateReposition(self, myPos, pp, dist, dt)
    elseif self.currentState == State.ANTICIPATION  then UpdateAnticipation(self, pp, dt)
    elseif self.currentState == State.CHARGE       then UpdateCharge(self, dt)
    elseif self.currentState == State.WALL         then UpdateWall(self, dt)
    elseif self.currentState == State.RECOVERY then UpdateRecovery(self, dt)
    elseif self.currentState == State.DEAD         then UpdateDeath(self, dt)
    end
end

function OnTriggerEnter(self, other)
    if self.isDead then return end         

    if other:CompareTag("Wall") then
        if self.currentState == State.WALL or self.currentState == State.RECOVERY then 
            return 
        end

        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end

        self.pendingWallHit = true
        Engine.Log("[Minocabro] Chocó con la pared")
        return 
    end

    if other:CompareTag("Bullet") then
        -- La bala golpea al esqueleto
        if not self.alreadyHit then
            local ap  = other.transform.worldPosition
            local dmg = 0
            dmg = 15
            self.alreadyHit = true
            hitCooldown = 0.2
            BaseMat.SetTexture("12721768917354180794")
            TakeDamage(self, dmg, ap)
        end
    end


    if other:CompareTag("Player") then
        -- The player hits the enemy
        if not self.alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                self.alreadyHit = true
                BaseMat.SetTexture("12721768917354180794")
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" or attack == "charge" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end

        -- The enemy hits the player
        if self.currentState == State.CHARGE and not self.alreadyHit and _PlayerController_pendingDamage == 0 then
            self.alreadyHit  = true
            
            local timeCharge = self.chargeTimer
            local durationMax = self.public.chargeDuration

            local ratio = timeCharge/durationMax

            local finalDamage = self.public.enemyDamageMin + (self.public.enemyDamageMax - self.public.enemyDamageMin) * ratio

            finalDamage = math.floor(finalDamage)

            _EnemyDamage_minocabro = finalDamage

            _PlayerController_pendingDamage    =  _EnemyDamage_minocabro
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            _PlayerController_triggerCameraShake = true
            
            if self.attackCol then self.attackCol:Disable() end
            StopMovement(self)
            self.slideVelX=0
            self.slideVelZ= 0
            if self.chargeFeedbackGO then
                GameObject.Destroy(self.chargeFeedbackGO)
                self.chargeFeedbackGO = nil
            end
            ChangeState(self, State.RECOVERY)
            Engine.Log("[Minocabro] Impacto tras " .. timeCharge .. "s. Daño: " .. _EnemyDamage_minocabro)        
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        self.alreadyHit = false 
        BaseMat.SetTexture("15634858790036886356")
    end
end