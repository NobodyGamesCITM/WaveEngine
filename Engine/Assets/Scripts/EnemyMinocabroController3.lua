local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- States
local State = {
    IDLE        = "Idle",
    PATROL = "Patrol",
    CHASE      = "Chase", --Searching and walking to player
    REPOSITION  = "Reposition", -- Getting away if player is too close
    ANTICIPATION = "Anticipation", -- Waiting before charging
    CHARGE      = "Charge", -- Running to hit
    WALL        = "Wall", --Stunned because hit a wall
    RECOVERY = "Recovery", --Recovering after charge
    DEAD        = "Dead",
}

_EnemyDamage_minocabro = 35

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

local hitCooldown = 0
local deadEn = false
local TILE_SIZE = 3.744

local BaseMat = nil
local lastPPos = {x = 0, z = 0}

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
    --local vel = self.rb:GetLinearVelocity()
    self.rb:SetLinearVelocity(0, 0, 0)
    self.smoothDx, self.smoothDz = 0, 0
    if self.dustPs then self.dustPs:Stop() end
end

local function DestroyChargeFeedback(self)
    if self.chargeFeedbackTiles then
        for i, tile in ipairs(self.chargeFeedbackTiles) do
            if tile and type(tile) ~= "boolean" then 
                GameObject.Destroy(tile) 
            end
        end
        self.chargeFeedbackTiles = {}
    end

    self.chargeFeedbackActive = false
end

local function ChangeState(self, newState)
    self.currentState = newState
    Engine.Log("[Minocabro] -> " .. newState)

    if newState == State.CHARGE then
        if self.voiceSFX then  self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoCharge") end
        if self.hoofPs then self.hoofPs:Stop() end
        if self.dustPs then self.dustPs:Play() end
    elseif newState == State.WALL then
        if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoStun") end
    elseif newState == State.ANTICIPATION then
        if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoRoar") end
    elseif newState == State.DEAD then
        --if self.voiceSFX then self.voiceSFX:StopAudioEvent() self.voiceSFX:SelectPlayAudioEvent("SFX_MinoDie") end
    end
end

local function EnemyIsInTheWay(self, chargeDirX, chargeDirZ)
    local myPos = self.transform.worldPosition
    local enemies = GameObject.FindByTag("Enemy")

    if enemies then
        for i = 1, #enemies do
            local other = enemies[i]

            if other ~= nil or other ~= self.gameObject then

                local otherPos = other.transform.worldPosition

                local canReach = self.nav:SetDestination(otherPos.x, otherPos.y, otherPos.z)
                if canReach then

                    local distX = otherPos.x-myPos.x
                    local distZ = otherPos.z-myPos.z
                    local dist=sqrt(distX*distX + distZ*distZ)

                    if dist < 4.5 then 
                        if other.currentState == State.CHARGE and self.currentState == State.ANTICIPATION then
                            return true
                        end
                        if other.currentState == State.ANTICIPATION and self.currentState == State.ANTICIPATION then
                            if other.preparationTimer > self.preparationTimer then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end
local function TakeDamage(self, amount, attackerPos)
    if self.isDead then return end

    if _G.TriggerCameraShake then
        _G.TriggerCameraShake(0.1, 0.5, 5.0)
    end

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

    if self.hp <= 0 and self.currentState ~= State.DEAD then
        Game.SetTimeScale(0.3)
        _impactFrameTimer = 0.2
    end

    if self.hp <= 0 then
        if self.anim then self.anim:Play("Death") end
        ChangeState(self, State.DEAD)
    else
        
        if self.voiceSFX then self.voiceSFX:SelectPlayAudioEvent("SFX_MinoHurt") end
        
        
        if self.anim then self.anim:Play("Hurt") end
        StopMovement(self)

        if self.thinBloodPs then self.thinBloodPs:Play() end
        if self.wideBloodPs then self.wideBloodPs:Play() end

        self.wallStunTimer = self.public.hurtStunTime
        self.wallStunTimer = self.wallStunTimer - dt
        if self.wallStunTimer <= 0 then
            ChangeState(self, State.RECOVERY)
        end

    end
end

-- State functions
local function UpdateIdle(self, dist)
    if not self.nav then return end

    if self.anim and not self.anim:IsPlayingAnimation("Idle") then
        self.anim:Play("Idle")
    end

    if self.playerGO then
        local pp = self.playerGO.transform.worldPosition
        if self.nav:CheckDestination(pp.x, pp.y, pp.z) then
            self.stayinNavmesh=true
            ChangeState(self, State.CHASE)
            return
        end
    end

    local px, py, pz = self.nav:GetRandomPoint()
    if px ~= nil then
        self.nav:SetDestination(px, py, pz)
        self.stayinNavmesh=false
        ChangeState(self, State.PATROL)
    end
end

local function UpdatePatrol(self, dt)

    if self.dustPs and self.dustPs:IsPlaying() then self.dustPs:Stop() end

    if not self.nav or not self.playerGO then return end

    local myPos = self.transform.worldPosition
    local pp = self.playerGO.transform.worldPosition
    local distanceToPlayer = Dist(myPos, pp) or 999
    local detectionRange = self.public.detectionRange or 15

    if self.nav:CheckDestination(pp.x, pp.y, pp.z) then
        Engine.Log("[Minocabro] Player en el navmesh, persiguiendo")
        self.stayinNavmesh=true

        ChangeState(self, State.CHASE)
        return
    end
     self.stayinNavmesh = false
    

    if self.anim and not self.anim:IsPlayingAnimation("Walk") then
        self.anim:Play("Walk")
    end

    local dx, dz = self.nav:GetMoveDirection(0.3)
    if dx and dz then
        RotateTowards(self, dx, dz, self.public.rotationSpeed or 5, dt)
       -- local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(dx * 4.0, 0, dz * 4.0)
    end

    if not self.nav:IsMoving() then
        StopMovement(self)
        ChangeState(self, State.IDLE)
    end
end

local function UpdateChase(self, myPos, pp, dist, dt)
    if not self.nav or not self.playerGO then return end

    --needs steps
    if self.stepTimer >= 0.5 then
        self.stepTimer = 0
        if self.stepSFX then 
            self.stepSFX:PlayAudioEvent() 
        end
    end

    local chargeRange = self.public.chargeRange or 10
    local moveSpeed = self.public.moveSpeed or 6

    self.navTimer = (self.navTimer or 0) - dt

    if self.navTimer <= 0 then
        local canReach = self.nav:SetDestination(pp.x, pp.y, pp.z)
        self.navTimer = 0.2
        
        if not canReach then
            ChangeState(self, State.PATROL)
            return
        end
    end

    if dist <= chargeRange then
        Engine.Log("Cambiando a ANTICIPATION porque dist es: " .. dist .. " y el rango es: " .. self.public.chargeRange)
        local dx, dz = pp.x - myPos.x, pp.z - myPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            self.chargeDirX, self.chargeDirZ = dx/len, dz/len
        end
        
        StopMovement(self)
        self.preparationTimer = 0
        ChangeState(self, State.ANTICIPATION)
        
    else
        if self.anim and not self.anim:IsPlayingAnimation("Walk") then 
            self.anim:Play("Walk", 0.2) 
        end
        
        local dx, dz = self.nav:GetMoveDirection(0.3)
        if dx and dz then
            RotateTowards(self, dx, dz, self.public.rotationSpeed or 5, dt)
            --local cv = self.rb:GetLinearVelocity()
            self.rb:SetLinearVelocity(dx * moveSpeed, 0, dz * moveSpeed)
        end
    end
end

local function UpdateReposition(self, myPos, pp, dist, dt)
    if self.anim and not self.anim:IsPlayingAnimation("Idle") then self.anim:Play("Idle") end
    if self.dustPs and self.dustPs:IsPlaying() then self.dustPs:Stop() end

    -- Opposite direction to the player
    local dx = myPos.x - pp.x
    local dz = myPos.z - pp.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    local lookDx = pp.x - myPos.x
    local lookDz = pp.z - myPos.z

    local vel = self.public.moveSpeed

    --local currentVel = self.rb:GetLinearVelocity()
    self.rb:SetLinearVelocity(dx*vel,0,dz*vel)

    RotateTowards(self, lookDx, lookDz, self.public.rotationSpeed, dt)


    if dist >= self.public.tooCloseRange + 0.5 then
        StopMovement(self)
        ChangeState(self, State.CHASE)
    end
end

local function UpdateAnticipation(self, pp, dt)

    if not self.playerGO then return end

    local pVelX = (pp.x - lastPPos.x) / dt
    local pVelZ = (pp.z - lastPPos.z) / dt
    lastPPos.x = pp.x
    lastPPos.z = pp.z

    if not self.chargeFeedbackGO then
        self.chargeFeedbackTiles = {}
        self.chargeFeedbackGO = true
    end
    

    local myPos = self.transform.worldPosition
    local timeToPredict = self.public.predictionTime or 0.5

    local pVelX = (pp.x - lastPPos.x) / dt
    local pVelZ = (pp.z - lastPPos.z) / dt

    local predictedX = pp.x + (pVelX * timeToPredict)
    local predictedZ = pp.z + (pVelZ * timeToPredict)

    local dx = predictedX - myPos.x
    local dz = predictedZ - myPos.z
    RotateTowards(self, dx, dz, self.public.rotationSpeed * 3.0, dt)
    --StopMovement(self)

    if self.anim and not self.anim:IsPlayingAnimation("PreCharge") then
        PlayAnim(self, "PreCharge")
        if self.voiceSFX then 
            self.voiceSFX:StopAudioEvent()
            self.voiceSFX:SelectPlayAudioEvent("SFX_MinoPrecharge")
            if self.hoofPs then self.hoofPs:Play() end
        end

    end


    self.preparationTimer = self.preparationTimer + dt

    if self.rb and self.preparationTimer < (self.public.preparationTime * 0.5) then
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            local backDx = -(dx / len)
            local backDz = -(dz / len)
            local vel = self.rb:GetLinearVelocity()
            self.rb:SetLinearVelocity(backDx * 2.0, 0, backDz * 2.0)
        end
    else
        StopMovement(self)
    end

    if self.preparationTimer >= self.public.preparationTime then
        
        local timeToPredict = self.public.predictionTime or 0.5
        
        local predictedX = pp.x + (pVelX * timeToPredict)
        local predictedZ = pp.z + (pVelZ * timeToPredict)

        local pDx = predictedX - myPos.x
        local pDz = predictedZ - myPos.z
        local len = sqrt(pDx*pDx + pDz*pDz)

        if len > 0.1 then
            self.chargeDirX = pDx / len
            self.chargeDirZ = pDz / len
        else
            local rotY = self.transform.worldRotation.y * (pi / 180.0)
            self.chargeDirX = math.sin(rotY)
            self.chargeDirZ = math.cos(rotY)
        end

        if EnemyIsInTheWay(self,self.chargeDirX,self.chargeDirZ) then
            preparationTimer = preparationTimer - 0.1
           return
        end

        self.chargeTimer = 0
        --if self.nav then self.nav.StopMovement() end
        ChangeState(self, State.CHARGE)
        
        --if self.dustPs then self.dustPs:Stop() end
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

    if not self.playerGO then return end

    
    if self.stepTimer >= 0.25 then
        self.stepTimer = 0
        if self.stepSFX then 
            self.stepSFX:PlayAudioEvent() 
        end
    end

    if self.anim and not self.anim:IsPlayingAnimation("Charge") then
        --PlayAnim(self, "Charge")
        self.anim:Play("Charge")
        
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
        --Save direction for after
        self.slideVelX = self.chargeDirX * 8.0
        self.slideVelZ = self.chargeDirZ * 8.0
        
        self.wallStunTimer = self.public.afterStunTime

        if self.anim and not self.anim:IsPlayingAnimation("Idle") then
            self.anim:Play("Idle", 0.3)
            if self.dustPs then self.dustPs:Stop() end
        end

        ChangeState(self, State.RECOVERY)
    end
end

local function UpdateWall(self, dt)

    if self.dustPs then self.dustPs:Stop() end

    if self.rb then
        --local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(0, 0, 0)
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

    if self.dustPs then self.dustPs:Stop() end

    --DestroyChargeFeedback(self)

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
        --local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(self.slideVelX, 0, self.slideVelZ)
    end

    if self.attackCol then self.attackCol:Disable() end

    self.wallStunTimer = self.wallStunTimer - dt
    if self.wallStunTimer <= 0 then
        self.cameFromWall = false
        
        if self.nav and self.playerGO then
            local pp = self.playerGO.transform.worldPosition
            if self.nav:CheckDestination(pp.x, pp.y, pp.z) then --If player is in the navmesh
                ChangeState(self, State.CHASE)
            else
                ChangeState(self, State.PATROL)
            end
        else
            ChangeState(self, State.PATROL)
        end
    end
end

local function UpdateDeath(self, dt)    
    self.deathTimer = self.deathTimer - dt

    if self.dustPs then self.dustPs:Stop() end

    if self.rb then
        self.rb:SetLinearVelocity(0, 0, 0)
        self.rb:SetBody(2)

    end

    if self.voiceSFX then
        if not Audio.IsEventPlaying("SFX_MinoDieCry") and self.deathTimer >= 3.0 then 
            self.voiceSFX:StopAudioEvent()
            self.voiceSFX:SelectPlayAudioEvent("SFX_MinoDieCry") 
            --Engine.Log("[Minocabro] Playing Death SFX Part 1")
        else
            --Engine.Log("[Minocabro] DeathSFX Part 1 already playing!")
        end

        if not Audio.IsEventPlaying("SFX_MinoFall") and self.deathTimer <= 1.75 and self.deathTimer >= 1.5 then 
            self.stepSFX:SelectPlayAudioEvent("SFX_MinoFall") 
            --Engine.Log("[Minocabro] Playing Death SFX Part 2")
        else
            --Engine.Log("[Minocabro] DeathSFX Part2 already playing!")
        end
        
    else
        --Engine.Log("[Minocabro] Unable to retrieve Voice Audio Source component")
    end
    

    if self.deathTimer <= 0 then
    
        if self.targetDeathYisEnter == false then
            Engine.Log("Calculant altura de mort...")
            local currentY = self.transform.position.y
            
            self.targetDeathY = currentY - 5.0 
            self.targetDeathYisEnter = true
            
            local colision = self.gameObject:GetComponent("Box Collider")
            if colision then 
                colision:Disable() 
                self.rb:SetUseGravity(false)
            end
        end
        
        local pos = self.transform.position
        
        if pos.y > self.targetDeathY then
            self.transform:SetPosition(pos.x, pos.y - 2.0, pos.z)
        else
            if not self.isDead then
                self.isDead = true
                deadEn = true
                Engine.Log("[Minocabro] Enterrat al seu lloc correcte.")
            end
        end

        --DestroyChargeFeedback(self)

        if self.isDead then
            self.rb = nil
            self.anim = nil
        end
        
    end
end

local function FindMinocabroParticles(self)
    self.thinBloodVFX = GameObject.FindInChildren(self.gameObject, "BloodDrops01")
    if self.thinBloodVFX then 
        self.thinBloodPs = self.thinBloodVFX:GetComponent("ParticleSystem") 
        if not self.thinBloodPs then 
            --Engine.Log("[Minocabro] Thin Blood Particle System NOT found!")
        else
            --Engine.Log("[Minocabro] Thin Blood Particle System FOUND!")
        end
    else 
        --Engine.Log("[Minocabro] Could not retrieve Thin Blood Drops VFX GameObject") 
    end

    self.wideBloodVFX = GameObject.FindInChildren(self.gameObject, "BloodDrops02")
    if self.wideBloodVFX then 
        self.wideBloodPs = self.wideBloodVFX:GetComponent("ParticleSystem") 
        if not self.wideBloodPs then 
            --Engine.Log("[Minocabro] Wide Blood Particle System NOT found!")
        else
            --Engine.Log("[Minocabro] Wide Blood Particle System FOUND!")
        end
    else 
        --Engine.Log("[Minocabro] Could not retrieve Wide Blood Drops VFX GameObject") 
    end

    self.dustVFX = GameObject.FindInChildren(self.gameObject, "RunDust")
    if self.dustVFX then 
        self.dustPs = self.dustVFX:GetComponent("ParticleSystem") 
        if not self.dustPs then 
            Engine.Log("[Minocabro] Running Dust Particle System NOT found!")
        else
            --Engine.Log("[Minocabro] Running Dust Particle System FOUND!")
        end
    else 
        --Engine.Log("[Minocabro] Could not retrieve Running Dust VFX GameObject") 
    end

    self.hoofVFX = GameObject.FindInChildren(self.gameObject, "HoofDust")
    if self.hoofVFX then 
        self.hoofPs = self.hoofVFX:GetComponent("ParticleSystem") 
        if not self.hoofPs then 
            --Engine.Log("[Minocabro] Hoof Dust Particle System NOT found!")
        else
            --Engine.Log("[Minocabro] Hoof Dust Particle System FOUND!")
        end
    else 
        --Engine.Log("[Minocabro] Could not retrieve Hoof Dust VFX GameObject") 
    end

end
          
function Start(self)
    self.public = {
        maxHp           = 60,
        detectRange     = 20.0,
		lockOnSize      = 7.5, -- partícula de fijado, no tocar.
        tooCloseRange   = 3.5,
        chargeRange     = 12.0,

        preparationTime = 0.8,--ANTES 1.5
        chargeSpeed     = 30.0,
        chargeDuration  = 0.4,
        knockbackForce  = 8.0,
        wallStunTime    = 5.0,
        wallSpeedThresh = 1.5,

        --Movement
        moveSpeed       = 15.0,
        rotationSpeed   = 3.0,

        stopSmoothing   = 8.0,

        hurtStunTime = 0.8,
        afterStunTime = 1.5, --Antes 2.2

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
    self.chargeTargetPos = { x = 0, y = 0, z = 0 }
    self.chargeDirX       = 0
    self.chargeDirZ       = 1
    self.slideVelX        = 0
    self.slideVelZ        = 0
    self.cameFromWall     = false
    self.pendingWallHit   = false
    self.playerGO         = nil
    self.chargeFeedbackGO = nil
    self.stepTimer        = 0.5
    

    self.nav = self.gameObject:GetComponent("Navigation")
    self.rb   = self.gameObject:GetComponent("Rigidbody")
    self.anim = self.gameObject:GetComponent("Animation")

    self.playerGO = GameObject.Find("Player")
    self.navTimer = 0

    --audio components

    self.stepSource = GameObject.FindInChildren(self.gameObject, "MinoStepSource")
    self.voiceSource = GameObject.FindInChildren(self.gameObject, "MinoVoiceSource")
    
   
    if self.stepSource then
        self.stepSFX = self.stepSource:GetComponent("Audio Source")
    else 
        --Engine.Log("[Minocabro] WARNING: Audio Source for steps not found") 
    end

    if self.voiceSource then
        self.voiceSFX = self.voiceSource:GetComponent("Audio Source")
    else 
        --Engine.Log("[Minocabro] WARNING: Audio Source for voice not found") 
    end


    self.stepTimer = 0.5

    --particle components
    FindMinocabroParticles(self)
    if self.thinBloodPs then self.thinBloodPs:Stop() end
    if self.wideBloodPs then self.wideBloodPs:Stop() end
    if self.dustPs then self.dustPs:Stop() end
    if self.hoofPs then self.hoofPs:Stop() end


    if self.anim then self.anim:Play("Idle") end

    self.attackCol = self.gameObject:GetComponent("Box Collider")
    if self.attackCol then
        self.attackCol:Disable()
    else
        Engine.Log("[Minocabro] ERROR: no se encontró Box Collider")
    end

    Engine.Log("[Minocabro] Start OK  HP=" .. self.hp)

    --Prefab.Load("MinocabroFeedback", Engine.GetAssetsPath() .. "/Prefabs/MinocabroFeedback.prefab")
    --self.chargeFeedbackGO = nil
    --self.chargeFeedbackActive = false 
    --self.chargeFeedbackTiles = {}

    mesh = GameObject.FindInChildren(self.gameObject,"Mesh")
    BaseMat = mesh:GetComponent("Material")

    Engine.RequestResource("16637297170788735381")
    Engine.RequestResource("15634858790036886356")
    Engine.RequestResource("12721768917354180794")

    self.stayinNavmesh=false

    self.targetDeathY=nil
    self.targetDeathYisEnter=false

    self.CheckAlive = function(self)
        return deadEn
    end
end

function Update(self, dt)
    if not self.gameObject or self.isDead then return end

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

    if not self.nav then self.nav = self.gameObject:GetComponent("Navigation") end
    if not self.rb   then self.rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not self.anim then self.anim = self.gameObject:GetComponent("Animation")  end

    if not self.thinBloodPs or not self.wideBloodPs or not self.dustPs then
        FindMinocabroParticles(self)
    end

    if not self.nav or not self.rb then return end
    
    if Input.GetKey("0") then
        TakeDamage(self, self.hp, self.transform.worldPosition)
        return
    end

    -- Trigger Wall
    if self.pendingWallHit then
        self.pendingWallHit = false
        if self.currentState ~= State.WALL and self.currentState ~= State.RECOVERY then
            StopMovement(self)
            --DestroyChargeFeedback(self)

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
            if self.hp<30 then
                BaseMat.SetTexture("16637297170788735381")

            else
                BaseMat.SetTexture("15634858790036886356")

            end
        end
    end
    
    self.stepTimer = self.stepTimer + dt
    local myPos = self.transform.worldPosition
    local pp    = self.playerGO.transform.worldPosition
    if not pp then return end

    local dist = Dist(myPos, pp)

    -- State machine
    if     self.currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif self.currentState == State.PATROL       then UpdatePatrol(self, dt)
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

    
    if self.isDead or not  self.stayinNavmesh then return end         

    if other:CompareTag("Wall") then
        if self.currentState == State.WALL or self.currentState == State.RECOVERY then 
            return 
        end

        DestroyChargeFeedback(self)


        self.pendingWallHit = true
        Engine.Log("[Minocabro] Chocó con la pared")
        return 
    end

    if other:CompareTag("Bullet") then
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
        if self.hp<30 then
            BaseMat.SetTexture("16637297170788735381")
        else
            BaseMat.SetTexture("15634858790036886356")
        end
    end
end


