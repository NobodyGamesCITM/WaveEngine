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
    chargeRange     = 12.0,

    --Movement
    moveSpeed       = 10.0,
    rotationSpeed   = 3.0,
    stopSmoothing   = 8.0,

    --Lace 360
    lanceDuration       = 0.5, 
    lanceCooldown       = 0.5,
    lanceDamage         = 15,

    --tooCloseRange   = 3.5,

    preparationTime = 1.5,
    chargeSpeed     = 18.0,
    chargeDuration  = 0.8,
    wallStunTime    = 5.0,
    wallSpeedThresh = 1.5,
    afterStunTime   = 2.2,
    chargeCooldown  = 2.0,  -- cooldown entre embestidas
    chargeDamage    = 30,

    -- Receive damage
    knockbackForce  = 8.0,


    stunDuration        = 4.0, 

    hurtStunTime = 0.8,
    

    predictionTime = 0.4, 

    opportunityDamageMultiplier = 1.0,
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

    if newState == State.CHARGE or newState == State.LANCE_360 then
        if attackCol then attackCol:Enable() end
    else
        if attackCol then attackCol:Disable() end
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
        Engine.Log("[Aquiles] HP: " .. hp .. "/" .. self.public.maxHp)
        if hp <= 0 then
            ChangeState(State.DEAD)
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

    -- Cooldown lance 360
    if lanceTimer>0 then
        lanceCDTimer=lanceCDTimer-dt
    end

    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end
    
    --Player muy cerca → Lance360
    if dist < self.public.Lance360Range and lanceCDTimer <= 0 then
        StopMovement()
        lanceTimer = 0
        ChangeState(State.LANCE_360)
    
    elseif dist <= self.public.chargeRange then --Preparar embestida
        chargeDirX       = dx
        chargeDirZ       = dz
        preparationTimer = 0
        chargeCDTimer    = self.public.chargeCooldown
        StopMovement()
        ChangeState(State.ANTICIPATION)
    
    else --walk
        local vel = self.public.moveSpeed
        local cv = rb:GetLinearVelocity()
        RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)

        rb:SetLinearVelocity(dx * vel, cv.y, dz * vel)

    end
end

function UpdateLance360(self, myPos, pp, dt)

    -- Gira sobre si mismo a gran velocidad (ataque 360)
    currentYaw = currentYaw + 720.0 * dt
    if currentYaw >= 360 then currentYaw = currentYaw - 360 end
    rb:SetRotation(0, currentYaw, 0)

    lanceTimer = lanceTimer + dt
    if lanceTimer >= self.public.lanceDuration then
        if attackCol then attackCol:Disable() end
        lanceCDTimer = self.public.lanceCooldown
        ChangeState(State.COMBAT_MOVE)
    end
end

function UpdateAnticipation(self, pp, dt)
    local myPos = self.transform.worldPosition
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
   

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
end

function UpdateCharge(self, dt)

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
        ChangeState(State.COMBAT_MOVE)
    end
end

function UpdateStun(self, dt)

    stunTimer = stunTimer - dt
    if stunTimer <= 0 then
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
        Engine.Log("[Minocabro] DEAD")
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
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    if anim then anim:Play("Idle") end
    Engine.Log("[Minocabro] Start OK  HP=" .. hp)
end

function Update(self, dt)
    if not self.gameObject or isDead then return end

    if not rb   then rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not anim then anim = self.gameObject:GetComponent("Animation")  end

    if Input.GetKey("0") then
        TakeDamage(self, hp, self.transform.worldPosition)
        return
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
            ChangeState(State.RECOVERY)
            Engine.Log("[Aquiles] Impacto " .. currentState .. ". Daño: " .. (finalDamage or 0))
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 
    end
end