-- SkeletonController.lua

local atan2  = math.atan
local pi     = math.pi
local sqrt   = math.sqrt
local min    = math.min
local abs    = math.abs

local hp
local isDead = false
local alreadyHit = false

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

-- States
local State = {
    IDLE   = "Idle",
    WANDER = "Wander",
    DEAD   = "Dead"
}

local Enemy = {
    currentState    = nil,
    rb              = nil,
    nav             = nil,
    startPos        = nil,
    targetPos       = {x=0, y=0, z=0},
    nextWanderTimer = 0,
    currentY        = 0,
    smoothDx        = 0,
    smoothDz        = 0
}

public = {
    maxHp           = 30,
    patrolRadius    = 5.0,
    idleWaitTime    = 3.0,
    moveSpeed       = 10.0,
    rotationSpeed   = 15.0,
    dirSmoothing    = 12.0,
    stopSmoothing   = 10.0,
    knockbackForce  = 5.0
}

-- HELPERS

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

-- DAMAGE SYSTEM
local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    hp = hp - amount
    Engine.Log("[Enemy] HP left: " .. hp .. "/" .. self.public.maxHp)

    _PlayerController_triggerCameraShake = true

    local rb = self.gameObject:GetComponent("Rigidbody")
    if rb and attackerPos then
        local enemyPos = self.transform.worldPosition

        local dx = enemyPos.x - attackerPos.x
        local dz = enemyPos.z - attackerPos.z

        local len = math.sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            dx = dx / len
            dz = dz / len
        end

        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 then
        isDead = true
        Enemy.currentState = State.DEAD
        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
    end
end

-- MOVEMENT FUNCTION

local function Movement(self, dt) 
    if not Enemy.nav or not Enemy.rb then return false, 0 end

    local vel = Enemy.rb:GetLinearVelocity()
    local vy = (vel and vel.y) or 0
    
    local isMoving  = Enemy.nav:IsMoving()
    local dx, dz    = Enemy.nav:GetMoveDirection(0.3)
    local hasFreshDir = (dx ~= 0 or dz ~= 0)

    -- Direction and Normalization
    if hasFreshDir then
        local mag = sqrt(dx * dx + dz * dz)
        dx, dz = dx / mag, dz / mag
    end
    -- Direction Smoothing
    if not isMoving then
        Enemy.smoothDx = lerp(Enemy.smoothDx, 0, dt * self.public.stopSmoothing)
        Enemy.smoothDz = lerp(Enemy.smoothDz, 0, dt * self.public.stopSmoothing)
        
        if abs(Enemy.smoothDx) < 0.01 and abs(Enemy.smoothDz) < 0.01 then
            Enemy.smoothDx, Enemy.smoothDz = 0, 0
            Enemy.rb:SetLinearVelocity(0, vy, 0)
        end

    elseif hasFreshDir then
        local t = min(1.0, dt * self.public.dirSmoothing)
        Enemy.smoothDx = Enemy.smoothDx + (dx - Enemy.smoothDx) * t
        Enemy.smoothDz = Enemy.smoothDz + (dz - Enemy.smoothDz) * t
    end
    -- Rotation
    if Enemy.smoothDx ~= 0 or Enemy.smoothDz ~= 0 then
        local targetAngle = atan2(Enemy.smoothDx, Enemy.smoothDz) * (180.0 / pi)
        local diff = shortAngleDiff(Enemy.currentY, targetAngle)
        Enemy.currentY = Enemy.currentY + diff * self.public.rotationSpeed * dt
        self.transform:SetRotation(0, Enemy.currentY, 0)
    end
    -- Apply Final Position
    local sMag = sqrt(Enemy.smoothDx * Enemy.smoothDx + Enemy.smoothDz * Enemy.smoothDz)
    if sMag > 0.01 then
        local speed = self.public.moveSpeed
        local vX = (Enemy.smoothDx / sMag) * speed
        local vZ = (Enemy.smoothDz / sMag) * speed
        local pos = self.transform.position
        self.transform:SetPosition(pos.x + vX * dt, pos.y, pos.z + vZ * dt)
    end
    
    return isMoving, sMag
end


function Start(self)
    hp = self.public.maxHp
    Enemy.nav = self.gameObject:GetComponent("Navigation")
    Enemy.rb  = self.gameObject:GetComponent("Rigidbody")
    
    local pos = self.transform.position
    Enemy.startPos = { x = pos.x, y = pos.y, z = pos.z }
    
    Enemy.currentState = State.IDLE
    Enemy.nextWanderTimer = self.public.idleWaitTime
end

function Update(self, dt)
    if isDead then return end

    local isMoving, speed = Movement(self, dt)

    -- State Machine
    if Enemy.currentState == State.IDLE then
        Enemy.nextWanderTimer = Enemy.nextWanderTimer - dt
        
        if Enemy.nextWanderTimer <= 0 then
            local angle = math.random() * pi * 2
            local dist = math.random() * self.public.patrolRadius
            
            Enemy.targetPos.x = Enemy.startPos.x + math.cos(angle) * dist
            Enemy.targetPos.z = Enemy.startPos.z + math.sin(angle) * dist
            
            if Enemy.nav then
                Enemy.nav:SetDestination(Enemy.targetPos.x, Enemy.startPos.y, Enemy.targetPos.z)
                Enemy.currentState = State.WANDER
                Engine.Log("[SKELETON] Buscando nuevo punto...")
            end
        end

    elseif Enemy.currentState == State.WANDER then
        -- Return to IDLE if Navigation stopped AND physical inertia has settled
        if not isMoving and speed < 0.05 then
            Enemy.nextWanderTimer = self.public.idleWaitTime
            Enemy.currentState = State.IDLE
            Engine.Log("[SKELETON] He llegado. Descansando.")
        end
    end
end

function OnTriggerEnter(self, other)
    if isDead then return end
    if alreadyHit then return end

    if other:CompareTag("Player") then
        local attack = _PlayerController_lastAttack
        if attack == "" then return end

        alreadyHit = true
        local attackerPos = other.transform.worldPosition

        if attack == "light" then
            TakeDamage(self, DAMAGE_LIGHT, attackerPos)
        elseif attack == "heavy" then
            TakeDamage(self, DAMAGE_HEAVY, attackerPos)
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end