local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- States
local State = {
    IDLE        = "Idle",
    COMBAT      = "Combat",
    REPOSITION  = "Reposition",
    PREPARATION = "Preparation",
    CHARGE      = "Charge",
    WALL        = "Wall",
    DEAD        = "Dead",
}

-- Public variables
public = {
    maxHp           = 60,
    detectRange     = 15.0,
    tooCloseRange   = 3.5,
    chargeRange     = 12.0,
    preparationTime = 1.2,
    chargeSpeed     = 18.0,
    chargeDuration  = 0.8,
    repositionSpeed = 4.0,
    attackDamage    = 25,
    knockbackForce  = 8.0,
    rotationSpeed   = 5.0,
    wallStunTime    = 2.5,
    wallSpeedThresh = 1.5,
    moveSpeed       = 5.0,
    dirSmoothing    = 10.0,
    stopSmoothing   = 8.0,
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

_EnemyDamage_minocabro = 35

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
    self.transform:SetRotation(0, currentYaw, 0)
end

local function StopMovement()
    if not rb then return end
    local vel = rb:GetLinearVelocity()
    rb:SetLinearVelocity(0, vel.y, 0)
    smoothDx, smoothDz = 0, 0
end

local function MoveTowards(self, dirX, dirZ, speed, dt)
    if not rb then return end

    local t = min(1.0, dt * self.public.dirSmoothing)
    smoothDx = smoothDx + (dirX - smoothDx) * t
    smoothDz = smoothDz + (dirZ - smoothDz) * t

    local mag = sqrt(smoothDx*smoothDx + smoothDz*smoothDz)
    if mag > 0.01 then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(
            (smoothDx / mag) * speed,
            vel.y,
            (smoothDz / mag) * speed
        )
        RotateTowards(self, smoothDx, smoothDz, self.public.rotationSpeed, dt)
    end
end

local function ChangeState(newState)
    currentState = newState
    Engine.Log("[Minocabro] -> " .. newState)
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
        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 then
        if anim then anim:Play("Death") end
        ChangeState(State.DEAD)
    else
        PlayAnim("Hurt", 0.5)
    end
end

-- State functions
function UpdateIdle(self, dist)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle")
    end
    if dist <= self.public.detectRange then
        ChangeState(State.COMBAT)
    end
end

function UpdateCombat(self, myPos, pp, dist, dt)
    if anim and not anim:IsPlayingAnimation("Walk") then anim:Play("Walk") end

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
        ChangeState(State.PREPARATION)
    else
        MoveTowards(self, dx, dz, self.public.moveSpeed, dt)
    end
end

function UpdateReposition(self, myPos, pp, dist, dt)
    if anim and not anim:IsPlayingAnimation("Walk") then anim:Play("Walk") end

    -- Opposite direction to the player
    local dx = myPos.x - pp.x
    local dz = myPos.z - pp.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    local lookDx = pp.x - myPos.x
    local lookDz = pp.z - myPos.z

    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(
            dx * self.public.repositionSpeed,
            vel.y,
            dz * self.public.repositionSpeed
        )
        RotateTowards(self, lookDx, lookDz, self.public.rotationSpeed, dt)
    end

    if dist >= self.public.tooCloseRange + 0.5 then
        StopMovement()
        ChangeState(State.COMBAT)
    end
end

function UpdatePreparation(self, pp, dt)
    local myPos = self.transform.worldPosition
    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
    StopMovement()

    if anim and not anim:IsPlayingAnimation("PreCharge") then
        PlayAnim("PreCharge")
    end

    preparationTimer = preparationTimer + dt
    if preparationTimer >= self.public.preparationTime then
        -- Recalculate final direction
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            chargeDirX, chargeDirZ = dx/len, dz/len
        end
        chargeTimer = 0
        ChangeState(State.CHARGE)
    end
end

function UpdateCharge(self, dt)
    if anim and not anim:IsPlayingAnimation("Charge") then
        PlayAnim("Charge")
    end

    chargeTimer = chargeTimer + dt

    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(chargeDirX * self.public.chargeSpeed, vel.y, chargeDirZ * self.public.chargeSpeed)

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
        StopMovement()
        ChangeState(State.COMBAT)
    end
end

function UpdateWall(self, dt)
    if anim and not anim:IsPlayingAnimation("wall") then
        PlayAnim("wall")
    end
    wallStunTimer = wallStunTimer - dt
    if wallStunTimer <= 0 then
        ChangeState(State.COMBAT)
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

    if anim then anim:Play("Idle") end

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then
        attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

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

    local myPos = self.transform.worldPosition
    local pp    = playerGO.transform.worldPosition
    if not pp then return end

    local dist = Dist(myPos, pp)

    -- State machine
    if     currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif currentState == State.COMBAT       then UpdateCombat(self, myPos, pp, dist, dt)
    elseif currentState == State.REPOSITION   then UpdateReposition(self, myPos, pp, dist, dt)
    elseif currentState == State.PREPARATION  then UpdatePreparation(self, pp, dt)
    elseif currentState == State.CHARGE       then UpdateCharge(self, dt)
    elseif currentState == State.WALL         then UpdateWall(self, dt)
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
        if currentState == State.CHARGE and not alreadyHit and (_PlayerController_pendingDamage == 0 or _PlayerController_pendingDamage == nil) then
            alreadyHit  = true
            _PlayerController_pendingDamage    =  _EnemyDamage_minocabro
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            _PlayerController_triggerCameraShake = true
            
            if attackCol then attackCol:Disable() end

            StopMovement()
            ChangeState(State.COMBAT)
            Engine.Log("[Minocabro] Impacto! Dano: " .. _EnemyDamage_minocabro)
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 
    end
end