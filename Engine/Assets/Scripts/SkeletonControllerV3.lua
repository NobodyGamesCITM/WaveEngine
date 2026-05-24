--skeleton script v3 (v2 with audio and hit/death anims)

local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local abs   = math.abs

local playerGO = nil

local State = {
    IDLE       = "Idle",
    PATROL     = "Patrol",
    CHASE      = "Chase",
    ATTACK     = "Attack",
    GUARD      = "Guard",
    DEAD       = "Dead",
    HIT        = "Hit",
    DODGE      = "Dodge"
}
local States = {}

local Skeleton = {
    currentState    = nil,
    rb              = nil,
    nav             = nil,
    navRefreshTimer = 0,
    hp              = 30,
    isDead          = false,
    initPos         = nil,
    bonesPS         = nil,
    bonePS          = nil,
    teethPS         = nil,
}

public = {
    maxHp           = 30,
    patrolSpeed     = 1.5,
	lockOnSize      = 4.0, -- partícula de fijado, no tocar.
    chaseSpeed      = 6.5,
    navRefreshRate  = 0.18,
    attackDur       = 1.0,
    attackColDelay  = 0.9,
    attackAnimaAnticip  = 0.3,

    detectDist      = 10.0,
    nearDist        = 3.0,
    nearYDist       = 1.0,
    offset          = 1.0,

    patrolWaitMin   = 2.0,
    patrolWaitMax   = 2.8,
    deathTime       = 3.5,
    
    activeGuard     = false,

    camDuration     = 0.5,
    camMagnitud     = 1.0,
    camFrequency    = 20.0,

    level2          = false,
    dodgeChance     = 30.0,

    stunTime    = 0.3,
}
local OnStartPos = false

local patrolWait = 0
local alreadyHit = false
local hitCooldown = 0
local attackTimer = 0
local pendingDeath = false
local stepTimer = 0.5
local deathTimer = 0
local revive = false

local targetVelX = 0
local targetVelZ = 0
local currentYaw = 0 

local hitGiven = false
local BaseMat = nil

local setAlive = false
local setDead = false

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
        return math.abs(pos.x - playerPos.x) < dist and math.abs(pos.z - playerPos.z) < dist and math.abs(pos.y - playerPos.y) < self.public.nearYDist
    else
        return math.abs(pos.x - playerPos.x) > dist or math.abs(pos.z - playerPos.z) > dist or math.abs(pos.y - playerPos.y) > self.public.nearYDist
    end
end

local function ApplyMoveVelocity(dt, accelRate)
    local vel = Skeleton.rb:GetLinearVelocity()
    Skeleton.rb:SetLinearVelocity(targetVelX * accelRate,vel.y,targetVelZ * accelRate)
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

local function ChangeState(self, newState)
    --Engine.Log("[Skeleton] CHANGING STATE: " .. tostring(newState))
    if Skeleton.currentState and States[Skeleton.currentState].Exit then
        States[Skeleton.currentState].Exit(self)
    end
    Skeleton.currentState = newState
    if States[newState].Enter then
        States[newState].Enter(self)
    end
end

local function TakeDamage(self, amount, attackerPos)
    if  Skeleton.isDead or not Skeleton.hp then return end
    local anim = self.gameObject:GetComponent("Animation")
    Skeleton.hp = Skeleton.hp - amount

    if _G.TriggerCameraShake then
        _G.TriggerCameraShake(0.1, 0.5, 5.0)
    end

    if  Skeleton.hp <= 0 and Skeleton.currentState ~= State.DEAD then
        if  Skeleton.nav then  Skeleton.nav:StopMovement()  end
        if self.dieSFX then self.dieSFX:PlayAudioEvent() end
        Game.SetTimeScale(0.3)
        _impactFrameTimer = 0.2
        ChangeState(self, State.DEAD)
    else
        --hitGiven = false
        if self.hurtSFX then self.hurtSFX:PlayAudioEvent() end
        ChangeState(self, State.HIT)
    end
end
local function FindAudioComponents(self)
    local attackSource = GameObject.FindInChildren(self.gameObject, "SK_KopisSource")
    if not attackSource then Engine.Log("Could not retrieve GameObject containing Skeleton attackSFX")
    else
        self.attackSFX = attackSource:GetComponent("Audio Source")
        if not self.attackSFX then Engine.Log("Could not retrieve Audio Source component to play Skeleton attackSFX") end
    end

    local hurtSource = GameObject.FindInChildren(self.gameObject, "SK_HurtSource")
    if not hurtSource then Engine.Log("Could not retrieve GameObject containing Skeleton hurtSFX")
    else
        self.hurtSFX = hurtSource:GetComponent("Audio Source")
        if not self.hurtSFX then Engine.Log("Could not retrieve Audio Source component to play Skeleton hurtSFX") end
    end

    local dieSource = GameObject.FindInChildren(self.gameObject, "SK_DieSource")
    if not dieSource then Engine.Log("Could not retrieve GameObject containing Skeleton deathSFX")
    else
        self.dieSFX = dieSource:GetComponent("Audio Source")
        if not self.dieSFX then Engine.Log("Could not retrieve Audio Source component to play Skeleton dieSFX") end
    end

    local dodgeSource = GameObject.FindInChildren(self.gameObject, "SK_DodgeSource")
    if not dodgeSource then Engine.Log("Could not retrieve GameObject containing Skeleton dodgeSFX")
    else
        self.dodgeSFX = dodgeSource:GetComponent("Audio Source")
        if not self.dodgeSFX then Engine.Log("Could not retrieve Audio Source component to play Skeleton dodgeSFX") end
    end

    self.stepSFX = self.gameObject:GetComponent("Audio Source")
    if not self.stepSFX then
        Engine.Log("[SKELETON AUDIO] Make sure there's an Audio Source with Steps SFX in the Skeleton's parent GameObject!")
    end
end

local function PlaySFX(audioComp)
    if audioComp then audioComp:PlayAudioEvent()
    else Engine.Log("Could not play configured event in Audio Source " .. tostring(audioComp) .. ", component not found") end
end

local function SelectPlaySFX(audioComp, eventName)
    if audioComp then audioComp:SelectPlayAudioEvent(audioComp, eventName)
    else Engine.Log("Could not play " .. eventName .. ", Audio Source component " .. tostring(audioComp) .. " not found") end
end

function Start(self)
    Skeleton.hp = self.public.maxHp
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

    FindAudioComponents(self)

    Skeleton.currentState = State.IDLE
    ChangeState(self, State.IDLE)

    Skeleton.initPos = self.transform.worldPosition   
    OnStartPos = true
    
    local squeletonMesh = GameObject.FindInChildren(self.gameObject,"Mesh_fixedUVs")
    BaseMat = squeletonMesh:GetComponent("Material")

    self.CheckAlive = function(self)
        return Skeleton.isDead
    end
    self.SetAlive = function(self)
        setAlive = true
        Skeleton.isDead = false
        revive = false
    end
    self.SetDead = function(self)
        setDead = true
        revive = true
    end

    Engine.RequestResource("17109277834976977864")
    Engine.RequestResource("15645066021049183995")
    Engine.RequestResource("13296577326446124640")
    Engine.RequestResource("9184343178901509246")
    Engine.RequestResource("6526428321459400712")
    Engine.RequestResource("10436511945076754837") --new skeleton level2 mat
    if self.public.level2 then BaseMat.SetTexture("10436511945076754837")end

    local vfxBones = GameObject.FindInChildren(self.gameObject, "VFXBones")
    if vfxBones then
        Skeleton.bonesPS = vfxBones:GetComponent("ParticleSystem")
        if Skeleton.bonesPS then Skeleton.bonesPS:Stop() end
        vfxBones:SetActive(false)
    end
    local vfxBone = GameObject.FindInChildren(self.gameObject, "VFXBone")
    if vfxBone then
        Skeleton.bonePS = vfxBone:GetComponent("ParticleSystem")
        if Skeleton.bonePS then Skeleton.bonePS:Stop() end
        vfxBone:SetActive(false)
    end
    local vfxTeeth = GameObject.FindInChildren(self.gameObject, "VFXTeeth")
    if vfxTeeth then
        Skeleton.teethPS = vfxTeeth:GetComponent("ParticleSystem")
        if Skeleton.teethPS then Skeleton.teethPS:Stop() end
        vfxTeeth:SetActive(false)
    end
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
        local plPos = playerGO.transform.worldPosition
        if not self.public.activeGuard then
            if px then
                Skeleton.nav:SetDestination(px, py, pz)
                ChangeState(self, State.PATROL)
            else
                patrolWait = self.public.patrolWaitMin
            end
        elseif not OnStartPos then ChangeState(self, State.GUARD)
        end
        if CheckDistance(self,self.public.detectDist,true) and Skeleton.nav:CheckDestination(plPos.x, plPos.y, plPos.z) and not _G.PlayerInAnim then
            ChangeState(self, State.CHASE)
            return
        end
    end
}

States[State.GUARD] = {
    Enter = function(self)
        playerGO = GameObject.Find("Player")

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Walk", 0.5) end)
        end
        Skeleton.nav:SetDestination(Skeleton.initPos.x, Skeleton.initPos.y, Skeleton.initPos.z)
    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        local dx, dz = Skeleton.nav:GetMoveDirection(0.3)
        targetVelX = dx * self.public.patrolSpeed
        targetVelZ = dz * self.public.patrolSpeed
        ApplyMoveVelocity(dt, 1.0)
        
        if abs(dx) > 0.001 or abs(dz) > 0.001 then
            local p = self.transform.worldPosition
            FaceTargetSmooth(self, {x=p.x+dx, y=p.y, z=p.z+dz}, dt)
        end
        if not Skeleton.nav:IsMoving() then
            ChangeState(self, State.IDLE)
            OnStartPos = true
            return
        end
        if CheckDistance(self,self.public.detectDist,true) and Skeleton.nav:CheckDestination(plPos.x, plPos.y, plPos.z) and not _G.PlayerInAnim then
            ChangeState(self, State.CHASE)
            return
        end
    end
}

States[State.PATROL] = {
    tempPos = nil,
    timeA = 0.0,
    Enter = function(self)
        playerGO = GameObject.Find("Player")
        States[State.PATROL].tempPos = self.transform.position
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Walk", 0.5) end)
        end
    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        local dx, dz = Skeleton.nav:GetMoveDirection(self.public.offset)
        targetVelX = dx * self.public.patrolSpeed
        targetVelZ = dz * self.public.patrolSpeed
        ApplyMoveVelocity(dt, 1.5)
        
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
        if CheckDistance(self,self.public.detectDist,true) and Skeleton.nav:CheckDestination(plPos.x, plPos.y, plPos.z) and not _G.PlayerInAnim then
            ChangeState(self, State.CHASE)
            return
        end

        if States[State.PATROL].timeA >= 4.0 then
            local pos = self.transform.position
            States[State.PATROL].timeA = 0.0
            if math.abs(pos.x - States[State.PATROL].tempPos.x) < 0.8 and math.abs(pos.z - States[State.PATROL].tempPos.z) < 0.8 then
                patrolWait   = self.public.patrolWaitMin
                    + math.random() * (self.public.patrolWaitMax - self.public.patrolWaitMin)
                ChangeState(self, State.IDLE)
            else 
                States[State.PATROL].timeA = 0.0
                States[State.PATROL].tempPos = pos
            end
        else   
            States[State.PATROL].timeA = States[State.PATROL].timeA + 0.1
        end

    end
}

States[State.CHASE] = {
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Run", 0.2) end)
        end

    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        local cantChase = true
        
        Skeleton.navRefreshTimer = Skeleton.navRefreshTimer - dt
        if Skeleton.navRefreshTimer <= 0 then
            cantChase = Skeleton.nav:SetDestination(plPos.x, plPos.y, plPos.z)
            Skeleton.navRefreshTimer = self.public.navRefreshRate
        end

        if CheckDistance(self,self.public.nearDist,true) then
            ChangeState(self, State.ATTACK)
            return
        end
        if CheckDistance(self,self.public.detectDist+3,false) or not cantChase then
            if not self.public.activeGuard then ChangeState(self, State.IDLE)
            else  
                OnStartPos = false
                ChangeState(self, State.GUARD) 
            end
            return
        end

        local dx, dz = Skeleton.nav:GetMoveDirection(0.3)
        targetVelX = dx * self.public.chaseSpeed
        targetVelZ = dz * self.public.chaseSpeed
        ApplyMoveVelocity(dt, 1.5)
        FaceTargetSmooth(self, plPos, dt)
    end
}

States[State.ATTACK] = {
    attacking = false,
    Enter = function(self)
        Skeleton.nav:StopMovement()
        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Orbit", 0.5) end)
        end
    end,
    Update = function(self, dt)
        local plPos = playerGO.transform.worldPosition
        attackTimer = attackTimer + dt
        if CheckDistance(self,self.public.nearDist, false) and not States[State.ATTACK].attacking then
            ChangeState(self, State.CHASE)
            hitGiven = false
            attackTimer = 0
            return
        end
        --Engine.Log(tostring(attackTimer))
        if attackTimer >= self.public.attackColDelay - self.public.attackAnimaAnticip and not hitGiven then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                local anim = self.gameObject:GetComponent("Animation")
                if anim then 
                    pcall(function() anim:Play("Attack", 0.0) end)
                end
            end
            States[State.ATTACK].attacking = true
        end

        if attackTimer >= self.public.attackColDelay and not hitGiven and not CheckDistance(self,self.public.nearDist, false) then
            local pending = _PlayerController_pendingDamage or 0
            if pending == 0 then
                PlaySFX(self.attackSFX)
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
            States[State.ATTACK].attacking = false
        end

        if _G.PlayerInAnim then 
            ChangeState(self, State.IDLE)
        end
        FaceTargetSmooth(self, plPos, dt)
        Skeleton.rb:SetLinearVelocity(0, 0, 0)
    end
}

States[State.HIT] = {
cnt = 0.0,
    Enter = function(self)
        alreadyHit = true
        attackTimer = 0
        States[State.HIT].cnt = 0.0
        hitCooldown = self.public.stunTime
        Skeleton.nav:StopMovement()
        BaseMat.SetTexture("17109277834976977864")

        local randNum = math.random(1,3)
        if Skeleton.bonesPS and randNum == 1 then Skeleton.bonesPS:Play() end
        if Skeleton.bonePS and randNum == 2 then Skeleton.bonePS:Play() end
        if Skeleton.teethPS and randNum == 3 then Skeleton.teethPS:Play() end

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Hit", 0.0) end)
        end
    end,
    Update = function(self, dt)
        States[State.HIT].cnt = States[State.HIT].cnt + dt
        if States[State.HIT].cnt >= hitCooldown then 
            ChangeState(self, State.ATTACK)
        end
    end,
    Exit = function(self)
        alreadyHit = false
        if Skeleton.hp >= 15 then
            --if self.public.level2 then BaseMat.SetTexture("15645066021049183995")
            if self.public.level2 then BaseMat.SetTexture("10436511945076754837")
            else BaseMat.SetTexture("13296577326446124640") end
        else 
            if self.public.level2 then BaseMat.SetTexture("9184343178901509246")
            else BaseMat.SetTexture("6526428321459400712") end
        end
    end
}
local function NormFlat(dx, dz)
    local len = sqrt(dx*dx + dz*dz)
    if len < 0.001 then return 0, 0 end
    return dx/len, dz/len
end

States[State.DODGE] = {
    cnt = 0.0,
    dur = 0.2,
    Enter = function(self)
        States[State.DODGE].cnt = 0.0
        attackTimer = 0
        Skeleton.nav:StopMovement()

        local playerPos = playerGO.transform.position
        local myPos = self.transform.position
        local rdx, rdz = NormFlat(myPos.x - playerPos.x, myPos.z - playerPos.z)

        local latX1, latZ1 =  rdz, -rdx
        local latX2, latZ2 = -rdz,  rdx

        local pvX = playerPos.x 
        local pvZ = playerPos.z 
        local dot1 = pvX * latX1 + pvZ * latZ1
        local dot2 = pvX * latX2 + pvZ * latZ2

        local lx, lz
        if dot1 <= dot2 then lx, lz = latX1, latZ1
        else                  lx, lz = latX2, latZ2  end

        local s  = 0.8
        local bx = lx * s + (-rdx) * (1 - s)
        local bz = lz * s + (-rdz) * (1 - s)
        local bl = sqrt(bx * bx + bz * bz)
        if bl > 0.001 then bx = bx / bl; bz = bz / bl end
        targetVelX = bx * 10
        targetVelZ = bz * 10

        local anim = self.gameObject:GetComponent("Animation")
        if anim then 
            pcall(function() anim:Play("Dodge", 0.0) end)
        end

        if self.dodgeSFX then 
            self.dodgeSFX:PlayAudioEvent() 
            --Engine.Log("[SKELETON] Played DodgeSFX")
        else
            --Engine.Log("[SKELETON] Couldn't play DodgeSFX")
        end
    end,
    Update = function(self, dt)
        States[State.DODGE].cnt =  States[State.DODGE].cnt + dt
        if States[State.DODGE].cnt >= States[State.DODGE].dur then 
            ChangeState(self, State.ATTACK)
        else 
            ApplyMoveVelocity(dt, -1.5)
        end
    end
}

States[State.DEAD] = {
    deadAnim = false,
    Enter = function(self)
        local anim = self.gameObject:GetComponent("Animation")
        Skeleton.nav:StopMovement()
        pendingDeath = true
        if anim then 
            pcall(function() anim:Play("Hit", 0.0) end)
        end
        if revive then States[State.DEAD].deadAnim = true  
        else States[State.DEAD].deadAnim = false end
    end,
    Update = function(self, dt)
        if not Skeleton.isDead  then
            Skeleton.isDead = true
            local colision = self.gameObject:GetComponent("Box Collider")
            if colision then 
                colision:Disable()
                Skeleton.rb:SetUseGravity(false)
            else  Engine.Log("Sphere not found") end

            if self.public.level2 then BaseMat.SetTexture("9184343178901509246")
            else BaseMat.SetTexture("6526428321459400712") end

            local anim = self.gameObject:GetComponent("Animation")
            if anim then 
                pcall(function() anim:Play("Death", 0.5) end)
            end
        elseif not States[State.DEAD].deadAnim then
            deathTimer = deathTimer + dt
            if deathTimer >= self.public.deathTime then 
                States[State.DEAD].deadAnim = true 
            elseif deathTimer >= self.public.deathTime/2 then
               Skeleton.rb:SetLinearVelocity(0,-2.0, 0)
               if _G.TriggerExplorationMusic then _G.TriggerExplorationMusic() end
            else 
                Skeleton.rb:SetLinearVelocity(0,0, 0) 
            end
        else 
            Skeleton.rb:SetLinearVelocity(0, 0, 0) 
        end
    end,
    Exit = function(self)
        Skeleton.isDead = false
        local colision = self.gameObject:GetComponent("Box Collider")
        if colision then 
            colision:Enable()
            Skeleton.rb:SetUseGravity(true)
        else  Engine.Log("Sphere not found") end
    end
}

function Update(self, dt)    
    if not Skeleton.nav then
        Skeleton.nav = self.gameObject:GetComponent("Navigation")
    end
    if not Skeleton.rb then
        Skeleton.rb = self.gameObject:GetComponent("Rigidbody")
    end

    if not BaseMat then
        local squeletonMesh = GameObject.FindInChildren(self.gameObject,"Mesh_fixedUVs")
        BaseMat = squeletonMesh:GetComponent("Material")
    end

    if not Skeleton.currentState then
        Skeleton.currentState = nil
        ChangeState(self, State.IDLE, true)
    end

    if not self.hurtSFX or not self.dieSFX or not self.attackSFX or not self.stepSFX then
        FindAudioComponents(self)
    end

    if Skeleton.currentState and States[Skeleton.currentState] then
        States[Skeleton.currentState].Update(self, dt)
    end

    if Skeleton.currentState == State.PATROL or Skeleton.currentState == State.CHASE
    or Skeleton.currentState == State.ORBIT  or Skeleton.currentState == State.DODGE then
        stepTimer = stepTimer + dt
        if stepTimer >= 0.5 then
            stepTimer = 0
            PlaySFX(self.stepSFX)
        end
    else
        stepTimer = 0
    end

    if setAlive then
        ChangeState(self, State.IDLE)
        setAlive = false
    end
    if setDead then
        ChangeState(self, State.DEAD)
        setDead = false
    end

    if CheckDistance(self,self.public.detectDist,true) then
        --Engine.Log("Triggering Combat Music from Skeleton Detection Range")
        if _G.TriggerCombatMusic then _G.TriggerCombatMusic() end
    end
end

function OnTriggerEnter(self, other)
    if Skeleton.isDead then return end
    if Skeleton.currentState ~= State.DEAD or Skeleton.currentState ~= State.HIT or Skeleton.currentState ~= State.DODGE then 
        if other:CompareTag("Player") then
            if not alreadyHit then
                local attack = _PlayerController_lastAttack
                if attack ~= nil and attack ~= "" then
                    local ap  = other.transform.worldPosition
                    local dmg = 0
                    if     attack == "light"  then dmg = 10
                    elseif attack == "heavy" or attack == "charge" then dmg = 25 end
                    if dmg > 0 then
                        if  math.random(1,100) < self.public.dodgeChance and self.public.level2 then
                            ChangeState(self,State.DODGE)
                        else TakeDamage(self, dmg, ap) end
                    end
                end
            end
        end

        if other:CompareTag("Bullet") then
            -- La bala golpea al esqueleto
            if not alreadyHit then
                local ap  = other.transform.worldPosition
                local dmg = 15
                TakeDamage(self, dmg, ap)
            end
        end
    else 
        return
    end
end

function OnTriggerExit(self, other)
    if Skeleton.isDead then return end
    if Skeleton.currentState ~= State.DEAD or Skeleton.currentState ~= State.HIT or Skeleton.currentState ~= State.DODGE then 
        if other:CompareTag("Player") then
            --ChangeState(self, State.ATTACK)
        end
    end
end