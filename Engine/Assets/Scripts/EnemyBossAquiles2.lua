local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- States
local State = {
    IDLE        = "Idle",
    COMBAT_MOVE      = "COMBAT_MOVE", --Searching and walking to player
    LANCE_360       = "Lance360", 
    ANTICIPATION = "Anticipation", -- Waiting before charging
    CHARGE      = "Charge", -- Running to hit
    WALL        = "Wall", --Stunned because hit a wall
    RECOVERY = "Recovery", --Recovering after charge
    STUN        = "Stun", 
    DEAD        = "Dead",
}

-- Public variables
public = {
    maxHp           = 300,
    maxPosture      = 100,

    -- Ranges
    detectRange     = 15.0,
    Lance360Range   = 3.5,
    chargeRange     = 15.0,
    dashApproachRange = 7.0,
    --Movement
    moveSpeed       = 10.0,
    rotationSpeed   = 3.0,
    stopSmoothing   = 8.0,
    

    --Lace 360
    lanceDuration       = 0.5, 
    lanceCooldown       = 1.5,
    lanceDamage         = 15,

    --tooCloseRange   = 3.5,

    preparationTime = 1.5,
    chargeSpeed     = 18.0,
    chargeDuration  = 0.8,
    wallStunTime    = 5.0,
    wallSpeedThresh = 1.5,
    afterStunTime   = 3.0,
    chargeCooldown  = 3.5,  -- cooldown entre embestidas
    chargeDamage    = 30,
    stepInterval    = 0.75,

    -- Receive damage
    knockbackForce  = 8.0,


    stunDuration        = 8.0, 

    hurtStunTime = 0.6,
    

    predictionTime = 0.4, 

    opportunityDamageMultiplier = 1.0,

    recoveryLance = 1.0,
    recoveryCharge = 1.8,
}

-- Internal variables
local currentState = State.IDLE
local hp           = 0
local posture       = 0     
local isDead       = false
local deathTimer = 3.5

local rb       = nil
local anim     = nil
local playerGO = nil
local attackCol    = nil

local alreadyHit   = false
local playerAttackHandled = false

local currentYaw       = 0
local smoothDx = 0
local smoothDz = 0

local preparationTimer = 0
local chargeTimer      = 0
local chargeDirX = 0
local chargeDirZ = 1


-- Inertia after charge (sliding)
local slideVelX = 0
local slideVelZ = 0
local wallStunTimer = 0
local cameFromWall =false 

--Timers
local lanceTimer    = 0 
local lanceCDTimer  = 0   
local chargeCDTimer = 0
local stunTimer     = 0   
local hurtTimer = 0

local inOpportunity = false
local pendingWallHit = false

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

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

    if attackCol then
        if newState == State.CHARGE or newState == State.LANCE_360 then
            attackCol:Enable()
        else
            attackCol:Disable()
        end
    end

    inOpportunity = (newState == State.WALL or newState == State.STUN)

end

local function TakeDamage(self, amount, attackerPos)
    if isDead then return end


    _PlayerController_triggerCameraShake = true

    if rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx/len; dz = dz/len end
        rb:AddForce((dx * self.public.knockbackForce) / 10, 0, (dz * self.public.knockbackForce) / 10, 2)
    end

    -- Damge Oportunity
    if inOpportunity then
        hp = hp - amount
        Engine.Log("[Aquiles] Daño directo HP: " .. hp .. "/" .. self.public.maxHp)
        if hp <= 0 then
            ChangeState(State.DEAD)
            if anim then anim:Play("Death") end
            return
        end
    else
        -- Damage Posture
        posture = posture + amount
        Engine.Log("[Aquiles] Postura: " .. posture .. "/" .. self.public.maxPosture)
        if posture >= self.public.maxPosture then
            posture = 0
            StopMovement()
            stunTimer = self.public.stunDuration
            ChangeState(State.STUN)
            if anim then anim:Play("Stun") end
            return
        end
 
        -- Stun receive damage
        if currentState == State.COMBAT_MOVE or currentState == State.RECOVERY then
            StopMovement()
            hurtTimer = self.public.hurtStunTime
        end
    end
end

-- State functions
function UpdateIdle(self, dist)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle")
    end
    if dist <= self.public.detectRange then
        ChangeState(State.COMBAT_MOVE)
    end
end

function UpdateCombatMove(self, myPos, pp, dist, dt)
    if hurtTimer > 0 then
        hurtTimer = hurtTimer - dt
        return
    end

    if lanceCDTimer > 0 then lanceCDTimer = lanceCDTimer - dt end
    if chargeCDTimer > 0 then chargeCDTimer = chargeCDTimer - dt end

    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end


    if dist < self.public.Lance360Range then -- Lance
        if lanceCDTimer <= 0 then
            StopMovement()
            lanceTimer = 0
            ChangeState(State.LANCE_360)
            return
        else
           
            StopMovement()
            if anim and not anim:IsPlayingAnimation("Idle") then anim:Play("Idle", 0.2) end
        end
    
    elseif dist < self.public.dashApproachRange then --dash
        MovementWalk(self, dx, dz, dt, self.public.moveSpeed * 1.5)

    elseif dist <= self.public.chargeRange then --Charge
        if chargeCDTimer <= 0 then
            StopMovement()
            chargeDirX = dx
            chargeDirZ = dz
            preparationTimer = 0
            chargeCDTimer = self.public.chargeCooldown
            ChangeState(State.ANTICIPATION)
            return 
        else
            MovementWalk(self, dx, dz, dt)
        end

    else
        MovementWalk(self, dx, dz, dt)
    end
end

function MovementWalk(self, dx, dz, dt, speedOverride)
    if anim and not anim:IsPlayingAnimation("Walk") then 
        anim:Play("Walk", 0.2) 
    end
    local vel = speedOverride or self.public.moveSpeed
    local cv = rb:GetLinearVelocity()
    RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
    rb:SetLinearVelocity(dx * vel, cv.y, dz * vel)
end

function UpdateLance360(self, myPos, pp, dt)

    currentYaw = currentYaw + 720.0 * dt
    if currentYaw >= 360 then currentYaw = currentYaw - 360 end
    rb:SetRotation(0, currentYaw, 0)

    lanceTimer = lanceTimer + dt
    if lanceTimer >= self.public.lanceDuration then
        if attackCol then attackCol:Disable() end
        lanceCDTimer = self.public.lanceCooldown
        wallStunTimer = self.public.recoveryLance
        ChangeState(State.RECOVERY)
    end
end

function UpdateAnticipation(self, pp, dt)
    local myPos = self.transform.worldPosition
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
   
    if anim and not anim:IsPlayingAnimation("PreCharge") then
        anim:Play("PreCharge", 0.2) 
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
        self.chargeFeedbackGO.transform:SetScale(0.4, 0.05, indicatorLength)
    end

    preparationTimer = preparationTimer + dt

    if rb and preparationTimer < (self.public.preparationTime * 0.5) then
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            local backDx = -(dx / len)
            local backDz = -(dz / len)
            local vel = rb:GetLinearVelocity()
            rb:SetLinearVelocity(backDx * 5.0, vel.y, backDz * 5.0)
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
end

function UpdateCharge(self, dt)

    chargeTimer = chargeTimer + dt

    if rb then
        rb:SetLinearVelocity(chargeDirX * self.public.chargeSpeed, 0, chargeDirZ * self.public.chargeSpeed)
    end


    if chargeTimer >= self.public.chargeDuration then
        --Save direction for after
        slideVelX = chargeDirX * 8.0
        slideVelZ = chargeDirZ * 8.0
        wallStunTimer = self.public.recoveryCharge
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
        anim:Play("Wall")
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

    local friction = self.public.stopSmoothing
    slideVelX = slideVelX + (0 - slideVelX) * min(1.0, dt * friction)
    slideVelZ = slideVelZ + (0 - slideVelZ) * min(1.0, dt * friction)
 
    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(slideVelX, vel.y, slideVelZ)
    end

    wallStunTimer = wallStunTimer - dt
    
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle", 0.2)
    end

    if wallStunTimer <= 0 then
        lanceCDTimer=self.public.lanceCooldown
        chargeCDTimer=self.public.chargeCooldown
        cameFromWall = false
        ChangeState(State.COMBAT_MOVE)
    end
end

function UpdateStun(self, dt)

    if anim and not anim:IsPlayingAnimation("Stun") then
        anim:Play("Stun")
    end

    stunTimer = stunTimer - dt
    if stunTimer <= 0 then
        posture = 0
        ChangeState(State.COMBAT_MOVE)
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
        Engine.Log("[Aquiles] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.1
        isDead = true

        self:Destroy()
  
    end
end

          
function Start(self)
    hp           = self.public.maxHp
    posture = self.public.maxPosture
    isDead       = false
    currentState = State.IDLE

    rb   = self.gameObject:GetComponent("Rigidbody")
    anim = self.gameObject:GetComponent("Animation")


    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
    else
        Engine.Log("[Aquiles] ERROR: no se encontró Box Collider")
    end

    if anim then anim:Play("Idle") end
    Engine.Log("[Aquiles] Start OK  HP=" .. hp)
    
    lanceCDTimer    =   0
    chargeCDTimer   =   0

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
                    elseif attack == "charge" or attack == "heavy" then
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

    local myPos = self.transform.worldPosition
    local pp    = playerGO.transform.worldPosition
    if not pp then return end

    local dist = Dist(myPos, pp)

      -- Instantiate/destroy feedback
    if currentState == State.ANTICIPATION then
        if not self.chargeFeedbackGO then
            self.chargeFeedbackGO = Prefab.Instantiate("MinocabroFeedback")
        end
    elseif currentState == State.RECOVERY or currentState == State.WALL then
        if self.chargeFeedbackGO then
            GameObject.Destroy(self.chargeFeedbackGO)
            self.chargeFeedbackGO = nil
        end
    end

    -- State machine
    if     currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif currentState == State.COMBAT_MOVE       then UpdateCombatMove(self, myPos, pp, dist, dt)
    elseif currentState == State.LANCE_360       then UpdateLance360(self, myPos, pp, dt)
    elseif currentState == State.ANTICIPATION  then UpdateAnticipation(self, pp, dt)
    elseif currentState == State.CHARGE       then UpdateCharge(self, dt)
    elseif currentState == State.WALL         then UpdateWall(self, dt)
    elseif currentState == State.RECOVERY then UpdateRecovery(self, dt)
    elseif currentState == State.STUN        then UpdateStun(self, dt)
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

        Engine.Log("[Aquiles] Chocó con pared por TAG")
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
        if (currentState == State.CHARGE or currentState == State.LANCE_360) and not alreadyHit and _PlayerController_pendingDamage == 0 then
            alreadyHit  = true
            local finalDamage

            if currentState == State.CHARGE then
                finalDamage = self.public.chargeDamage
            elseif currentState == State.LANCE_360 then
                finalDamage = self.public.lanceDamage
            end

            _PlayerController_pendingDamage    = finalDamage
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            _PlayerController_triggerCameraShake = true
            
            if attackCol then attackCol:Disable() end
            StopMovement()
            slideVelX = 0
            slideVelZ = 0

            if self.chargeFeedbackGO then
                GameObject.Destroy(self.chargeFeedbackGO)
                self.chargeFeedbackGO = nil
            end

            ChangeState(State.RECOVERY)
            wallStunTimer = self.public.recoveryCharge
            Engine.Log("[Aquiles] Impacto " .. currentState .. ". Daño: " .. (finalDamage or 0))
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 
    end
end