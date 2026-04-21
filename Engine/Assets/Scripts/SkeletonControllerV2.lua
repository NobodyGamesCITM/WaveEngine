local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

local playerGO = nil

local State = {
    IDLE       = "Idle",
    PATROL     = "Patrol",
    CHASE      = "Chase",
    ORBIT      = "Orbit",
    DODGE      = "Dodge",
    ANTICIPATE = "Anticipate",
    ATTACK     = "Attack",
    DEAD       = "Dead",
}
local States = {}

local Skeleton = {
    currentState    = nil,
    rb              = nil,
    nav             = nil,
    navRefreshTimer = 0,
    hp              = 30,
    isDead          = false
}
public = {
    maxHp           = 30,
    patrolSpeed     = 1.5,
    chaseSpeed      = 3.5,
    navRefreshRate  = 0.18,
    attackDur       = 1.0,
    attackColDelay  = 1.5,
    attackAnimaAnticip  = 0.3,
    nearDist        = 2,
    nearYDist       = 1.0,

    patrolWaitMin   = 1.0,
    patrolWaitMax   = 2.8,
}
local patrolWait = 0
local alreadyHit = false
local attackTimer = 0
local pendingDeath = false
local currentYaw = 0 

local BaseMat = nil

local function Lerp(a, b, t)  return a + (b-a)*t  end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function CheckDistance(self, dist, near)
    local obj = GameObject.Find("Player")
    local playerPos = obj.transform.position
    local pos = self.transform.position
    
   -- Engine.Log("[Skeleton] NOT NEAR ENOUGH: " .. tostring(dist))
    if near == true then 
        return math.abs(pos.x - playerPos.x) < dist and math.abs(pos.z - playerPos.z) < dist --and math.abs(pos.y - playerPos.y) < self.public.nearYDist
    else
        return math.abs(pos.x - playerPos.x) > dist or math.abs(pos.z - playerPos.z) > dist-- or math.abs(pos.y - playerPos.y) > self.public.nearYDist
    end
end

local function ApplyMoveVelocity(dt, accelRate)
    local vel = Skeleton.rb:GetLinearVelocity()
    Skeleton.rb:SetLinearVelocity(Lerp(vel.x, targetVelX, dt * accelRate),vel.y,
                         Lerp(vel.z, targetVelZ, dt * accelRate))
end

local function FaceTargetSmooth(self, target, dt)
    local p  = self.transform.worldPosition
    local dx = target.x - p.x
    local dz = target.z - p.z

    if abs(dx) < 0.001 and abs(dz) < 0.001 then return end

    local desiredYaw = atan2(dx, dz) * (180 / pi)
    local delta      = desiredYaw - currentYaw
    delta = delta - math.floor((delta + 180) / 360) * 360

    local turn = Clamp(delta,-4.0 * dt * 60,4.0 * dt * 60)
    currentYaw = currentYaw + turn
    Skeleton.rb:SetRotation(0, currentYaw, 0)
end

local function TakeDamage(self, amount, attackerPos)
    if  Skeleton.isDead or not Skeleton.hp then return end

    Skeleton.hp = Skeleton.hp - amount
    --Engine.Log("[Skeleton] HP: " .. Skeleton.hp .. "/" .. self.public.maxHp)
    _PlayerController_triggerCameraShake = true

    if  Skeleton.hp <= 0 and not pendingDeath then
        --if Enemy.dieSFX then Enemy.dieSFX:PlayAudioEvent() end
        pendingDeath = true
    else
        hitGiven = false
        if  Skeleton.nav then  Skeleton.nav:StopMovement()  end
        --if Enemy.hurtSFX then Enemy.hurtSFX:PlayAudioEvent() end
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
          --  pcall(function() anim:Play("Hit", 0.5) end)
        end
    end
end

local function ChangeState(self, newState)
    --Engine.Log("[Skeleton] CHANGING STATE: " .. tostring(newState))
    
    if Skeleton.currentState and States[Skeleton.currentState].Exit then
        States[Skeleton.currentState].Exit(self)
    end
    Skeleton.currentState = newState
    if newState ~= State.IDLE and newState ~= State.RUNNING 
    and newState ~= State.WALK and newState ~= State.ATTACK_LIGHT then
        attackBuffer = false
    end   
    if States[newState].Enter then
        States[newState].Enter(self)
    end
end

function Start(self)
    currentYaw = (self.transform.worldRotation and self.transform.worldRotation.y) or 0
    playerGO = GameObject.Find("Player")

    Skeleton.rb = self.gameObject:GetComponent("Rigidbody")
    if not Skeleton.rb then
        Skeleton.Log("[Skeleton] No rigidbody found")
    end

    Skeleton.nav = self.gameObject:GetComponent("Navigation")
    if not Skeleton.nav then
        Skeleton.Log("[Skeleton] No Navegation found")
    end

    Skeleton.currentState = State.IDLE
    ChangeState(self, State.IDLE)

    local squeletonMesh = GameObject.FindInChildren(self.gameObject,"Mesh_fixedUVs")
    BaseMat = squeletonMesh:GetComponent("Material")
end

States[State.IDLE] = {
    Enter = function(self)
        playerGO = GameObject.Find("Player")
        Skeleton.nav:StopMovement()

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Idle", 0.5) end)
        end
    end,
    Update = function(self, dt)
        local px, py, pz = Skeleton.nav:GetRandomPoint()
        if px then
            Skeleton.nav:SetDestination(px, py, pz)
            ChangeState(self, State.PATROL)
        else
            patrolWait = self.public.patrolWaitMin
        end
        if CheckDistance(self,30.0,true) then
            ChangeState(self, State.CHASE)
            return
        end
    end
}
States[State.PATROL] = {
    Enter = function(self)
        playerGO = GameObject.Find("Player")
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Walk", 0.5) end)
        end
    end,
    Update = function(self, dt)
        local dx, dz = Skeleton.nav:GetMoveDirection(0.3)
        targetVelX = dx * self.public.patrolSpeed
        targetVelZ = dz * self.public.patrolSpeed
        ApplyMoveVelocity(dt, 18.0)
        if abs(dx) > 0.001 or abs(dz) > 0.001 then
            local p = self.transform.worldPosition
            FaceTargetSmooth(self, {x=p.x+dx, y=p.y, z=p.z+dz}, dt)
        end

        if not Skeleton.nav:IsMoving() then
            patrolWait   = self.public.patrolWaitMin
                + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)
            ChangeState(self, State.IDLE)
            return
        end
        if CheckDistance(self,30.0,true) then
            ChangeState(self, State.CHASE)
            return
        end
    end
}
States[State.CHASE] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Walk", 0.2) end)
        end
    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        
        if CheckDistance(self,self.public.nearDist,true) then
            ChangeState(self, State.ATTACK)
            return
        end
        if CheckDistance(self,31,false) then
            ChangeState(self, State.IDLE)
            return
        end
        Skeleton.navRefreshTimer = Skeleton.navRefreshTimer - dt
        if Skeleton.navRefreshTimer <= 0 then
            Skeleton.nav:SetDestination(plPos.x, plPos.y, plPos.z)
            Skeleton.navRefreshTimer = self.public.navRefreshRate
        end

        local dx, dz = Skeleton.nav:GetMoveDirection(0.3)
        targetVelX = dx * self.public.chaseSpeed
        targetVelZ = dz * self.public.chaseSpeed
        ApplyMoveVelocity(dt, 18.0)
        FaceTargetSmooth(self, plPos, dt)
    end
}

States[State.ATTACK] = {
    Enter = function(self)
        Skeleton.nav:StopMovement()
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Orbit", 0.5) end)
        end
    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        attackTimer    = attackTimer    + dt

        if attackTimer >= self.public.attackColDelay - self.public.attackAnimaAnticip and not hitGiven and playerGO then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                local anim = self.gameObject:GetComponent("Animation")
                if anim then 
                    pcall(function() anim:Play("Attack", 0.0) end)
                end
            end
        end

        if attackTimer >= self.public.attackColDelay and not hitGiven and playerGO then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                hitGiven = true
                _PlayerController_pendingDamage = 20
                _PlayerController_pendingDamagePos = self.transform.worldPosition
            end
        end

        if attackTimer >= self.public.attackDur or alreadyHit then
            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play("Orbit", 0.5) end)
            end
            hitGiven = false
            attackTimer   = 0
        end
        if CheckDistance(self,self.public.nearDist, false) then
            ChangeState(self, State.CHASE)
            hitGiven = false
            attackTimer = 0
            return
        end
        FaceTargetSmooth(self, plPos, dt)
        Skeleton.rb:SetLinearVelocity(0, 0, 0)
    end
}

function Update(self, dt)
    if not Skeleton.nav then
        Skeleton.nav = self.gameObject:GetComponent("Navigation")
    end
    if not Skeleton.rb then
        Skeleton.rb = self.gameObject:GetComponent("Rigidbody")
    end
    if not Skeleton.currentState then
        Skeleton.currentState = nil
        ChangeState(self, State.IDLE, true)
    end
    if Skeleton.currentState and States[Skeleton.currentState] then
        States[Skeleton.currentState].Update(self, dt)
    end

    if pendingDeath then
        if Skeleton.nav then Skeleton.nav:StopMovement() end
        Skeleton.isDead       = true
        --Engine.Log("[Skeleton] MUERTO")
        --Enemy.dieSFX:PlayAudioEvent()
        self:Destroy()
        return
    end
end

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        -- El jugador golpea al esqueleto
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= nil and attack ~= "" then
                local ap  = other.transform.worldPosition
                local dmg = 0
                if     attack == "light"  then dmg = 10
                elseif attack == "heavy" or attack == "charge" then dmg = 25
                end
                if dmg > 0 then
                    alreadyHit = true
                    BaseMat.SetTexture("17109277834976977864")
                    TakeDamage(self, dmg, ap)
                end
            end
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
        BaseMat.SetTexture("13296577326446124640")
    end
end