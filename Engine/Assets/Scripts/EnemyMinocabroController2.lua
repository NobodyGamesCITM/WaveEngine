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

-- Public variables
public = {
    maxHp           = 60,
    detectRange     = 15.0,
    tooCloseRange   = 3.5,
    chargeRange     = 12.0,

    preparationTime = 1.5,
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

    enemyDamageMin=5,
    enemyDamageMax=35,

    predictionTime = 0.4, 

}

-- Internal variables
local currentState = State.IDLE
local hp           = 0
local isDead       = false
local deathTimer = 3.5
local alreadyHit   = false
local attackCol    = nil
local playerAttackHandled = false

local smoothDx = 0
local smoothDz = 0
local wallStunTimer = 0

local rb       = nil
local anim     = nil
local playerGO = nil

local preparationTimer = 0
local chargeTimer      = 0
local currentYaw       = 0

local chargeDirX = 0
local chargeDirZ = 1

-- Inertia after charge (sliding)
local slideVelX = 0
local slideVelZ = 0

_EnemyDamage_minocabro = 35

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

local cameFromWall   = false
local pendingWallHit = false

-- Sounds
local voiceSFX = nil
local stepSFX  = nil
local stepSource        = nil
local voiceSource       = nil
local stepTimer = 0

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

local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

local function Dist(a, b)
    local dx, dz = a.x - b.x, a.z - b.z
    return sqrt(dx*dx + dz*dz)
end

local function RotateTowards(self, dirX, dirZ, speed, dt)
    if abs(dirX) < 0.01 and abs(dirZ) < 0.01 then return end
    local targetAngle = atan2(dirX, dirZ) * (180.0 / pi)
    local diff = shortAngleDiff(currentYaw, targetAngle)
    currentYaw = currentYaw + diff * speed * dt
    rb:SetRotation(0, currentYaw, 0)
end 

local function StopMovement()
    if not rb then return end
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y, 0)
    smoothDx, smoothDz = 0, 0
end


local function ChangeState(newState)
    currentState = newState
    Engine.Log("[Minocabro] -> " .. newState)

    if newState == State.CHARGE then
        if voiceSFX then  voiceSFX:StopAudioEvent() voiceSFX:SelectPlayAudioEvent("SFX_MinoCharge") end
    elseif newState == State.WALL then
        if voiceSFX then voiceSFX:StopAudioEvent() voiceSFX:SelectPlayAudioEvent("SFX_MinoStun") end
    elseif newState == State.ANTICIPATION then
        if voiceSFX then voiceSFX:StopAudioEvent() voiceSFX:SelectPlayAudioEvent("SFX_MinoRoar") end
    elseif newState == State.DEAD then
        if voiceSFX then voiceSFX:StopAudioEvent() voiceSFX:SelectPlayAudioEvent("SFX_MinoDeath") end
    end
end

local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    hp = hp - amount
    Engine.Log("[Minocabro] HP: " .. hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx/len; dz = dz/len end
        rb:AddForce((dx * self.public.knockbackForce) / 10, 0, (dz * self.public.knockbackForce) / 10, 2)
    end

    if hp <= 0 then
        if anim then anim:Play("Death") end
        ChangeState(State.DEAD)
    else
        
        if voiceSFX then voiceSFX:SelectPlayAudioEvent("SFX_MinoHurt") end
        anim:Play("Hurt")
        StopMovement()

        wallStunTimer = self.public.hurtStunTime
        wallStunTimer = wallStunTimer - dt
        if wallStunTimer <= 0 then
            ChangeState(State.RECOVERY)
        end

    end
end

-- State functions
function UpdateIdle(self, dist)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle")
    end
    if dist <= self.public.detectRange then
        ChangeState(State.CHASE)
    end
end

function UpdateChase(self, myPos, pp, dist, dt)
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end
    
    
    if dist < self.public.tooCloseRange then
        ChangeState(State.REPOSITION)
    
    elseif dist <= self.public.chargeRange then
        chargeDirX       = dx
        chargeDirZ       = dz
        preparationTimer = 0
        StopMovement()
        ChangeState(State.ANTICIPATION)
    
    else
        Engine.Log("updatecombat andar")
        if anim and not anim:IsPlayingAnimation("Walk") then anim:Play("Walk", 0.2) end
      
        if stepTimer >= 0.5 then
            stepTimer = 0
            if stepSFX then stepSFX:PlayAudioEvent() end
        end

        local vel = self.public.moveSpeed
        local cv = rb:GetLinearVelocity()
        RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)

        rb:SetLinearVelocity(dx * vel, cv.y, dz * vel)

    end
end

function UpdateReposition(self, myPos, pp, dist, dt)
    if anim and not anim:IsPlayingAnimation("Idle") then anim:Play("Idle") end

    -- Opposite direction to the player
    local dx = myPos.x - pp.x
    local dz = myPos.z - pp.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    local lookDx = pp.x - myPos.x
    local lookDz = pp.z - myPos.z

    local vel = self.public.moveSpeed

    local currentVel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(dx*vel,currentVel.y,dz*vel)

    RotateTowards(self, lookDx, lookDz, self.public.rotationSpeed, dt)


    if dist >= self.public.tooCloseRange + 0.5 then
        StopMovement()
        ChangeState(State.CHASE)
    end
end

function UpdateAnticipation(self, pp, dt)
    local myPos = self.transform.worldPosition
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
    --StopMovement()

    if anim and not anim:IsPlayingAnimation("PreCharge") then
        PlayAnim("PreCharge")

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
        local positionY = myPos.y +0.15
        local positionZ = myPos.z + directionZ * (indicatorLength * 0.5)

        local rotationAngle = atan2(directionX, directionZ) * (180.0 / pi)

        self.chargeFeedbackGO.transform:SetPosition(positionX, positionY, positionZ)
        self.chargeFeedbackGO.transform:SetRotation(0, rotationAngle, 0)
        self.chargeFeedbackGO.transform:SetScale(2.0, 0.05, indicatorLength)
    end


    preparationTimer = preparationTimer + dt

    if rb and preparationTimer < (self.public.preparationTime * 0.5) then
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            local backDx = -(dx / len)
            local backDz = -(dz / len)
            local vel = rb:GetLinearVelocity()
            rb:SetLinearVelocity(backDx * 2.0, vel.y, backDz * 2.0)
        end
    else
        StopMovement()
    end

    if preparationTimer >= self.public.preparationTime then
        local predictedX = pp.x
        local predictedZ = pp.z

        if rb then
            local predictionVel = rb:GetLinearVelocity()
            local time = self.public.predictionTime
            predictedX = pp.x + predictionVel.x * time
            predictedZ = pp.z + predictionVel.z * time
        end

        local predictionDx= predictedX - myPos.x
        local predictionDz= predictedZ - myPos.z
        local len = sqrt(predictionDx*predictionDx + predictionDz*predictionDz)
        if len > 0.001 then
            chargeDirX, chargeDirZ = predictionDx/len, predictionDz/len
        end
        chargeTimer = 0
        ChangeState(State.CHARGE)
    end

    --if preparationTimer >= self.public.preparationTime then
        -- Recalculate final direction
        --local len = sqrt(dx*dx + dz*dz)
        --if len > 0.001 then
            --chargeDirX, chargeDirZ = dx/len, dz/len
        --end
        --chargeTimer = 0
        --ChangeState(State.CHARGE)
    --end
end

function UpdateCharge(self, dt)

    if stepTimer >= 0.25 then
        stepTimer = 0
        if stepSFX then 
            stepSFX:PlayAudioEvent() 
        end
    end

    if anim and not anim:IsPlayingAnimation("Charge") then
        PlayAnim("Charge")

    end

    chargeTimer = chargeTimer + dt

    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(chargeDirX * self.public.chargeSpeed, 0, chargeDirZ * self.public.chargeSpeed)

        if chargeTimer > 0.2 then
            local actualSpeed = sqrt(vel.x*vel.x + vel.z*vel.z)
            if actualSpeed < self.public.wallSpeedThresh then
                alreadyHit = false
                StopMovement()
                wallStunTimer = self.public.wallStunTime
                ChangeState(State.WALL)
                return
            end
        end
    end

    if not attackCol then attackCol = self.gameObject:GetComponent("Box Collider") end
    if attackCol then attackCol:Enable() end

    if chargeTimer >= self.public.chargeDuration then
        if attackCol then attackCol:Disable() end
        --Save direction for after
        slideVelX = chargeDirX * 8.0
        slideVelZ = chargeDirZ * 8.0
        
        wallStunTimer = self.public.afterStunTime

        ChangeState(State.RECOVERY)
    end
end

function UpdateWall(self, dt)
    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(0, vel.y, 0)
        rb:SetRotation(0, currentYaw, 0)
    end

    if anim and not anim:IsPlayingAnimation("Wall") then
        PlayAnim("Wall")
    end

    wallStunTimer = wallStunTimer - dt
    if wallStunTimer <= 0 then
        slideVelX = 0
        slideVelZ = 0
        wallStunTimer = self.public.afterStunTime
        cameFromWall = true
        ChangeState(State.RECOVERY)
    end
end

function UpdateRecovery(self, dt)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle", 0.3)
    end

    if playerGO and not cameFromWall then
        local myPos = self.transform.worldPosition
        local pp = playerGO.transform.worldPosition
        local dx = pp.x - myPos.x
        local dz = pp.z - myPos.z
        RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
    end

    local friction = self.public.stopSmoothing
    slideVelX = slideVelX + (0 - slideVelX) * min(1.0, dt * friction)
    slideVelZ = slideVelZ + (0 - slideVelZ) * min(1.0, dt * friction)
 
    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(slideVelX, vel.y, slideVelZ)
    end

    wallStunTimer = wallStunTimer - dt
    if wallStunTimer <= 0 then
        cameFromWall = false
        ChangeState(State.CHASE)
    end
end

function UpdateDeath(self,dt)
    deathTimer = deathTimer - dt
    
    if deathTimer <= 0 then
        local _rb  = rb

        rb       = nil
        anim     = nil
        playerGO = nil
        
        if _rb  then
            local vel = _rb:GetLinearVelocity()
            _rb:SetLinearVelocity(0, (vel and vel.y) or 0, 0)
        end
        Engine.Log("[Minocabro] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.1
        isDead = true

        self:Destroy()
  
    end
end

          
function Start(self)
    hp           = self.public.maxHp
    isDead       = false
    currentState = State.IDLE

    rb   = self.gameObject:GetComponent("Rigidbody")
    anim = self.gameObject:GetComponent("Animation")

    stepSource = GameObject.FindInChildren(self.gameObject, "MinoStepSource")
    voiceSource = GameObject.FindInChildren(self.gameObject, "MinoVoiceSource")
    
   
    if stepSource then
        stepSFX = stepSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for steps not found") end

    if voiceSource then
        voiceSFX = voiceSource:GetComponent("Audio Source")
    else Engine.Log("[Minocabro] WARNING: Audio Source for voice not found") end

    stepTimer = 0.5

    if anim then anim:Play("Idle") end

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    Engine.Log("[Minocabro] Start OK  HP=" .. hp)

    Prefab.Load("MinocabroFeedback", Engine.GetAssetsPath() .. "/Prefabs/MinocabroFeedback.prefab")
    self.chargeFeedbackGO = nil
end

function Update(self, dt)
    if not self.gameObject or isDead then return end

    if not rb   then rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not anim then anim = self.gameObject:GetComponent("Animation")  end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        return
    end

        -- Trigger Wall
    if pendingWallHit then
        pendingWallHit = false
        if currentState ~= State.WALL and currentState ~= State.RECOVERY then
            StopMovement()
            if self.chargeFeedbackGO then
                GameObject.Destroy(self.chargeFeedbackGO)
                self.chargeFeedbackGO = nil
            end
            wallStunTimer = self.public.wallStunTime
            ChangeState(State.WALL)
        end
    end

    -- Receive Damage
    if _PlayerController_lastAttack ~= nil and _PlayerController_lastAttack ~= "" then
        if not playerAttackHandled and playerGO and not isDead then
            local myPos = self.transform.position
            local pp    = playerGO.transform.position
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
    end

    -- Search Player
    if not playerGO then
        playerGO = GameObject.Find("Player")
    end
    if not playerGO then return end

    stepTimer = stepTimer + dt
    local myPos = self.transform.worldPosition
    local pp    = playerGO.transform.worldPosition
    if not pp then return end

    local dist = Dist(myPos, pp)

-- Instantiate/destroy feedback BEFORE calling the state
    if currentState == State.ANTICIPATION then
        if not self.chargeFeedbackGO then
            self.chargeFeedbackGO = Prefab.Instantiate("MinocabroFeedback")
        end
    elseif currentState == State.RECOVERY then
        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end
    end

    -- State machine
    if     currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif currentState == State.CHASE       then UpdateChase(self, myPos, pp, dist, dt)
    elseif currentState == State.REPOSITION   then UpdateReposition(self, myPos, pp, dist, dt)
    elseif currentState == State.ANTICIPATION  then UpdateAnticipation(self, pp, dt)
    elseif currentState == State.CHARGE       then UpdateCharge(self, dt)
    elseif currentState == State.WALL         then UpdateWall(self, dt)
    elseif currentState == State.RECOVERY then UpdateRecovery(self, dt)
    elseif currentState == State.DEAD         then UpdateDeath(self, dt)
    end
end

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Wall") then
        if currentState == State.WALL or currentState == State.RECOVERY then 
            return 
        end

        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end

        pendingWallHit = true
        Engine.Log("[Minocabro] Chocó con la pared")
        return 
    end


    if other:CompareTag("Player") then
        -- The player hits the enemy
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" or attack == "charge" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end

        -- The enemy hits the player
        if currentState == State.CHARGE and not alreadyHit and _PlayerController_pendingDamage == 0 then
            alreadyHit  = true
            
            local timeCharge = chargeTimer
            local durationMax = self.public.chargeDuration

            local ratio = timeCharge/durationMax

            local finalDamage = self.public.enemyDamageMin + (self.public.enemyDamageMax - self.public.enemyDamageMin) * ratio

            finalDamage = math.floor(finalDamage)

            _EnemyDamage_minocabro = finalDamage

            _PlayerController_pendingDamage    =  _EnemyDamage_minocabro
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            _PlayerController_triggerCameraShake = true
            
            if attackCol then attackCol:Disable() end
            StopMovement()
            slideVelX=0
            slideVelZ= 0
            if self.chargeFeedbackGO then
                GameObject.Destroy(self.chargeFeedbackGO)
                self.chargeFeedbackGO = nil
            end
            ChangeState(State.RECOVERY)
            Engine.Log("[Minocabro] Impacto tras " .. timeCharge .. "s. Daño: " .. _EnemyDamage_minocabro)        
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 
    end
end