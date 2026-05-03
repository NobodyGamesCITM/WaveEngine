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
public = {
    doorName = "Puerta_Final",
}

-- Internal variables
local currentState = State.IDLE
local hp           = 0

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

local aquilesMesh =nil


local voiceSFX = nil
local stepSFX = nil
local spearSFX = nil
local dashSFX = nil
local armorSFX = nil

local sourceNames = {"AQ_VoiceSource", "AQ_StepSource", "AQ_SpearSource", "AQ_DashSource", "AQ_ArmorSource"}

local alreadyHit   = false
local playerAttackHandled = false

local currentYaw       = 0
local smoothDx = 0
local smoothDz = 0

local preparationTimer = 0
local chargeTimer      = 0
local chargeDirX = 0
local chargeDirZ = 1

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
local stepTimer = 0
local fadeMusicTimer = 0
local volume = 100

local inOpportunity = false
local pendingWallHit = false
local hasDashed = false

local pressureTimer = 0
local PRESSURE_THRESHOLD = 0.8

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

local ActiveDodge=false

local BaseMat = nil

local hitsReceivedCounter = 0

local wallAnimStarted = false
local stunAnimStarted = false
local opportunityHitTimer = 0 
local chargeAnimStarted = false
local lanceAnimStarted = false
local anticipationAnimStarted = false
local recoveryAnimStarted = false

local hitCooldown = 0
local finishedTransition = false

local TILE_SIZE = 3.744
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

local function PlayAnim(name, blend)
    if anim then anim:Play(name, blend or 0.15) end
end

local function PlaySFX(audioComp)
    if audioComp then audioComp:PlayAudioEvent()    
    else 
        Engine.Log("Could not play configured event in Audio Source ".. tostring(audioComp).. ", component not found")
    end
end

local function SelectPlaySFX(audioComp, eventName)
    if audioComp then audioComp:SelectPlayAudioEvent(eventName)
    else 
        Engine.Log("Could not play " .. eventName ..", Audio Source component".. tostring(audioComp).. " not found")
    end
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

local function ChangeState(newState)
    currentState = newState
    Engine.Log("[Aquiles] -> " .. newState)
    pressureTimer = 0 
    chargeAnimStarted = false
    lanceAnimStarted = false
    anticipationAnimStarted = false
    recoveryAnimStarted = false

    if attackCol then
        if newState == State.CHARGE or newState == State.LANCE_360 then
            attackCol:Enable()
        else
            attackCol:Disable()
        end
    end

    inOpportunity = (newState == State.WALL or newState == State.STUN)
end

local function FadeOutBossMusic(self, dt)

    if volume > 0 and not finishedTransition then 
		fadeMusicTimer = fadeMusicTimer + dt
		local progressPercent = math.min((fadeMusicTimer/3.5), 1.0)
		volume = 100 * (1 - progressPercent)
		Engine.Log("Setting music volume to ".. volume)
		if volume then 
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end

	elseif volume <= 0 and not finishedTransition then
		finishedTransition = true
        Audio.SetMusicVolume(0)
		--if bgMusic then bgMusic:StopAudioEvent() end
	end

	if _G._PlayerController_isDead then
		--exitedLevel = false
		--finishedTransition = false
        Audio.SetMusicState("Level2")
		fadeMusicTimer = 0
		Audio.SetMusicVolume(100)
	end 

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
        local totalDamage = amount * self.public.opportunityDamageMultiplier
        hp = hp - totalDamage
        SelectPlaySFX(voiceSFX, "SFX_AquilesHurt")
        if currentState == State.LANCE_360 or currentState == State.CHARGE then
            return
        end

        Engine.Log("[Aquiles] Daño directo HP: " .. hp .. "/" .. self.public.maxHp)
        if currentState == State.WALL then
            if anim then anim:Play("Stuck_Hit", 0.1) end
        elseif currentState == State.STUN then
            if anim then anim:Play("Stun_Hit", 0.1) end
        end
        opportunityHitTimer = 0.4

        -- Stun receive damage
        if currentState == State.COMBAT_MOVE or currentState == State.RECOVERY then
            StopMovement()
            hurtTimer = self.public.hurtStunTime
            if anim then anim:Play("Hit", 0.1) end
        end
        
        if hp <= 0 then
            ChangeState(State.DEAD)
            if anim then anim:Play("Death") end
            SelectPlaySFX(voiceSFX, "SFX_AquilesDeath")
            
        -- Hide boss bar when Aquiles dies
        if _G.BossBar_SetVisibility then
            _G.BossBar_SetVisibility(false)
        end
            return
        end
    else
        -- Damage Posture
        posture = posture + amount
        
        Engine.Log("[Aquiles] Postura: " .. posture .. "/" .. self.public.maxPosture)
        if posture >= self.public.maxPosture then
            posture = 0
            PlaySFX(armorSFX)

            if currentState == State.LANCE_360 or currentState == State.CHARGE then
                return
            end
        
            StopMovement()
            --stunTimer = self.public.stunDuration
                        
            ChangeState(State.IDLE)
            --ChangeState(State.STUN)
            --if anim then anim:Play("Stun") end
            return
        end
 
        
    end
    -- Refresh boss bar health after taking damage
    if _G.BossBar_RefreshHealth then
        _G.BossBar_RefreshHealth(hp, self.public.maxHp)
    end

    if not inOpportunity and currentState == State.COMBAT_MOVE then
        hitsReceivedCounter = hitsReceivedCounter + 1
        
        local myPos = self.transform.worldPosition
        local dist = Dist(myPos, attackerPos)
        
        if hitsReceivedCounter >= 3 and dist < 4.0 then
            hitsReceivedCounter = 0
            StopMovement()
            
            local dx = myPos.x - attackerPos.x
            local dz = myPos.z - attackerPos.z
            local len = sqrt(dx*dx + dz*dz)
            if len > 0.001 then
                slideVelX = (dx/len) * 15.0
                slideVelZ = (dz/len) * 15.0
            end
            
            wallStunTimer = 0.8 
            ChangeState(State.RECOVERY)
            PlaySFX(dashSFX)
            Engine.Log("[Aquiles] Dash de alejamiento: Demasiada presión")
        end
    end
end

-- Dodge player
local function dodgePlayer(self, dist, dt)

    if dist<= self.public.Lance360Range then
        ActiveDodge=false
        pressureTimer=0
        return
    end
    if dist < 4.5 then
        pressureTimer = pressureTimer + dt
    else
        pressureTimer = pressureTimer - dt * 1.5
    end
    pressureTimer = math.max(0, pressureTimer)

    if pressureTimer >= PRESSURE_THRESHOLD then
        pressureTimer = 0
        StopMovement()

        local myPos = self.transform.worldPosition 

        local dx = myPos.x - pp.x   
        local dz = myPos.z - pp.z
        local len = sqrt(dx*dx + dz*dz)

        if len > 0.001 then
            
            local perpX =  dz / len  
            local perpZ = -dx / len

            slideVelX = perpX * 5.0
            slideVelZ = perpZ * 5.0

        end

        wallStunTimer = 0.4
        ChangeState(State.DASH)
        PlaySFX(dashSFX)
        if anim then anim:Play("Dash", 0.1) end
        ActiveDodge = true
        return
    else
        ActiveDodge = false
    end
end

local function MovementWalk(self, dx, dz, dt, speedOverride, isDashing)

    isDashing = isDashing or false
    local speedOverride = speedOverride or self.public.moveSpeed

    if not isDashing then
        hasDashed = false

        if anim and not anim:IsPlayingAnimation("Walk") then  anim:Play("Walk", 0.2) end

        stepTimer = stepTimer + dt
        if stepTimer >= (self.public.stepInterval / 10* speedOverride)  then
            PlaySFX(stepSFX)
            stepTimer = 0
        end

    else
        if anim and not anim:IsPlayingAnimation("Dash") then 
            anim:Play("Dash", 0.2) 
           
        end

        if not hasDashed then
            PlaySFX(dashSFX)
            hasDashed = true
            
        elseif hasDashed and not Audio.IsEventPlaying("SFX_AquilesDash") then
            if anim and not anim:IsPlayingAnimation("Walk") then 
                anim:Play("Walk", 0.2) 
                Engine.Log("[AQUILES] Walking after dash")
            end
            --PlaySFX(stepSFX)
        end
    end

    local vel = speedOverride or self.public.moveSpeed
    local cv = rb:GetLinearVelocity()
    RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
    rb:SetLinearVelocity(dx * vel, cv.y, dz * vel)
end

-- State functions
local function UpdateIdle(self, dist)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle")
    end
    -- If player detected and boss bar functions are available, show the bar and update health
    if dist <= self.public.detectRange and _G.BossBar_SetVisibility and _G.BossBar_RefreshHealth then
        _G.BossBar_SetVisibility(true)
        _G.BossBar_RefreshHealth(hp, self.public.maxHp)
    end
    if dist <= self.public.detectRange then
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateCombatMove(self, myPos, pp, dist, dt)
    if dist > self.public.detectRange then
        StopMovement()
        ChangeState(State.IDLE)
        return
    end

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

    --dodgePlayer(self,dist,dt)
    if dist < self.public.Lance360Range then --lance
        ActiveDodge   = false
        pressureTimer = 0
        if lanceCDTimer <= 0 then
            StopMovement()
            lanceTimer       = 0
            lanceAnimStarted = false
            ChangeState(State.LANCE_360)
            SelectPlaySFX(spearSFX, "SFX_AquilesSpearSwing")
            return 
        else
            StopMovement()
            RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
            if anim and not anim:IsPlayingAnimation("Walk") then anim:Play("Walk", 0.2) end
        end
        return
    end
    
    dodgePlayer(self, dist, dt)

    if dist < self.public.dashApproachRange then --dash
        MovementWalk(self, dx, dz, dt, self.public.moveSpeed * 1.5, true)

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

local function UpdateLance360(self, myPos, pp, dt)

    
    if not lanceAnimStarted then
        lanceAnimStarted = true
        anim:Play("360Attack", 0.1)
        currentYaw = self.transform.eulerAngles.y
    end

    currentYaw = currentYaw + 500.0 * dt
    if currentYaw >= 360 then currentYaw = currentYaw - 360 end
    rb:SetRotation(0, currentYaw, 0)

    lanceTimer = lanceTimer + dt
    if lanceTimer >= self.public.lanceDuration then
       
        local dx = pp.x - myPos.x
        local dz = pp.z - myPos.z
        if abs(dx) > 0.1 or abs(dz) > 0.1 then
            currentYaw = atan2(dx, dz) * (180.0 / pi)
            rb:SetRotation(0, currentYaw, 0)
        end

        if attackCol then attackCol:Disable() end
        lanceCDTimer = self.public.lanceCooldown
        wallStunTimer = self.public.recoveryLance
        StopMovement()
        ChangeState(State.RECOVERY)
    end

end

local function UpdateAnticipation(self, pp, dt)

    local pVelX = (pp.x - lastPPos.x) / dt
    local pVelZ = (pp.z - lastPPos.z) / dt
    lastPPos.x = pp.x
    lastPPos.z = pp.z

    if not self.chargeFeedbackGO then
        self.chargeFeedbackTiles = {}
        self.chargeFeedbackGO = true
        SelectPlaySFX(voiceSFX, "SFX_AquilesWarCry")
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
   
    if anim and not anim:IsPlayingAnimation("Charge_Start") then
        anim:Play("Charge_Start", 0.2)
    end
    anticipationAnimStarted = true

    if self.chargeFeedbackGO then
        --Maximum possible distance
        local maxChargeDistance = self.public.chargeSpeed * self.public.chargeDuration
        
        -- Vcetor distance player
        local vectorToPlayerX = pp.x - myPos.x
        local vectorToPlayerZ = pp.z - myPos.z
        local currentDistToPlayer = sqrt(vectorToPlayerX * vectorToPlayerX + vectorToPlayerZ * vectorToPlayerZ)

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

        local numTiles = math.floor(indicatorLength / TILE_SIZE)
        if #self.chargeFeedbackTiles ~= numTiles then

            -- Destroy old ones
            for _, tile in ipairs(self.chargeFeedbackTiles) do
                if tile then GameObject.Destroy(tile) end
            end

            self.chargeFeedbackTiles = {}

            for i = 1, numTiles do
                local tile = Prefab.Instantiate("AquilesFeedback")
                if tile then
                    table.insert(self.chargeFeedbackTiles, tile)
                end
            end
        end

        local dirX, dirZ = 0, 0
        if distance > 0.001 then 
            dirX = dx / distance 
            dirZ = dz / distance 
        end

        -- Place tiles
        for i, tile in ipairs(self.chargeFeedbackTiles) do
           if tile then
                local offset = (i - 0.5) * TILE_SIZE
                tile.transform:SetPosition(myPos.x + dirX * offset, pp.y + 0.2, myPos.z + dirZ * offset)
                tile.transform:SetRotation(0, atan2(dirX, dirZ) * (180.0 / pi), 0)
                tile.transform:SetScale(3.744, 0.30, 3.744)
            end
        end
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
        local timeToPredict = self.public.predictionTime or 0.5
        
        local predictedX = pp.x + (pVelX * timeToPredict)
        local predictedZ = pp.z + (pVelZ * timeToPredict)

        local pDx = predictedX - myPos.x
        local pDz = predictedZ - myPos.z
        local len = sqrt(pDx*pDx + pDz*pDz)


        if len > 0.1 then
            chargeDirX = pDx / len
            chargeDirZ = pDz / len
        else
            local rotY = self.transform.worldRotation.y * (pi / 180.0)
            chargeDirX = math.sin(rotY)
            chargeDirZ = math.cos(rotY)
        end
        chargeTimer = 0
        ChangeState(State.CHARGE)
    end
end

local function UpdateCharge(self, dt)

    chargeTimer = chargeTimer + dt

    if not chargeAnimStarted then
        chargeAnimStarted = true
        --if anim then anim:Play("Walk", 0.2) end
        anim:Play("Charge_Loop ")
    end
    
    if rb then
        rb:SetLinearVelocity(chargeDirX * self.public.chargeSpeed, 0, chargeDirZ * self.public.chargeSpeed)
    end


    if chargeTimer >= self.public.chargeDuration then
        --Save direction for after
        slideVelX = chargeDirX * 8.0
        slideVelZ = chargeDirZ * 8.0
        StopMovement(self)
        DestroyChargeFeedback(self)
        wallStunTimer = self.public.recoveryCharge
        ChangeState(State.RECOVERY)
    end
end

local function UpdateWall(self, dt)

    if rb then
        --local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(0, 0, 0)
        rb:SetRotation(0, currentYaw, 0)
    end

    if opportunityHitTimer > 0 then
        opportunityHitTimer = opportunityHitTimer - dt
        return
    end
    
    if anim and not anim:IsPlayingAnimation("Stuck_Loop") and not anim:IsPlayingAnimation("Stuck_Hit") then
        anim:Play("Stuck_Loop", 0.1)
    end
 

    wallStunTimer = wallStunTimer - dt
    if wallStunTimer <= 0 then
        wallAnimStarted = false
        anim:Play("Stuck_End", 0.15)
        slideVelX = 0
        slideVelZ = 0
        wallStunTimer = self.public.afterStunTime
        cameFromWall = true
        ChangeState(State.RECOVERY)
    end
end

local function UpdateDash(self, dt)
    local friction = self.public.stopSmoothing
    slideVelX = slideVelX + (0 - slideVelX) * min(1.0, dt * friction)
    slideVelZ = slideVelZ + (0 - slideVelZ) * min(1.0, dt * friction)

    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(slideVelX, vel.y, slideVelZ)
    end

    if not anim:IsPlayingAnimation("Dash") then
        ActiveDodge   = false
        pressureTimer = 0
        slideVelX     = 0
        slideVelZ     = 0
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateRecovery(self, dt)

    if not recoveryAnimStarted then
        recoveryAnimStarted = true
        if cameFromWall then
            anim:Play("Idle", 0.2)
        else
            anim:Play("Charge_End", 0.15)
        end
    end

    local friction = self.public.stopSmoothing
    slideVelX = slideVelX + (0 - slideVelX) * min(1.0, dt * friction)
    slideVelZ = slideVelZ + (0 - slideVelZ) * min(1.0, dt * friction)
 
    if rb then
        local vel = rb:GetLinearVelocity()
        rb:SetLinearVelocity(slideVelX, vel.y, slideVelZ)
    end

    wallStunTimer = wallStunTimer - dt
    
    --if anim and not anim:IsPlayingAnimation("Charge_End") and not anim:IsPlayingAnimation("Idle") then
        --anim:Play("Charge_End", 0.15)
    --end

    if wallStunTimer <= 0 then
        lanceCDTimer=self.public.lanceCooldown
        chargeCDTimer=self.public.chargeCooldown
        cameFromWall = false
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateStun(self, dt)
    rb:SetLinearVelocity(0, 0, 0)

    if opportunityHitTimer > 0 then
        opportunityHitTimer = opportunityHitTimer - dt
        return
    end

    if not stunAnimStarted then
        anim:Play("Stun_Start", 0.15)
        stunAnimStarted = true
    elseif anim and not anim:IsPlayingAnimation("Stun_Start") and not anim:IsPlayingAnimation("Stun_Loop") then
        anim:Play("Stun_Loop", 0.1)
    end

    stunTimer = stunTimer - dt
    if stunTimer <= 0 then
        posture = 0
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateDeath(self,dt)
    deathTimer = deathTimer - dt
    
    if deathTimer <= 0 then
     --   local door = GameObject.Find(self.public.doorName)
       -- if door then
         --   local doorScript = door:GetComponent("Script")
         --   if doorScript and doorScript.OpenDoor then
            --    doorScript:OpenDoor()
           -- end
        --end
        DestroyChargeFeedback(self)
        local _rb  = rb
        Audio.SetMusicState("AfterBoss")
        rb       = nil
        anim     = nil
        playerGO = nil
        
        if _rb  then
            local vel = _rb:GetLinearVelocity()
            _rb:SetLinearVelocity(0, 0, 0)
        end
        Engine.Log("[Aquiles] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.1
        isDead = true

        local door = GameObject.Find("Puerta_Final") 
        if door then
            local doorScript = door:GetComponent("Script")
            doorScript:OpenDoor()
        end


        self:Destroy()
  
    end
end

--attempting to automize the audiosource retrieval (WIP)
local function AutoFindAquilesAudioComponents(self)
    Engine.Log("Getting AQUILES AUDIOsource components... AudioComps size: " ..tostring(#audioComps).." vs. SourceNames size: "..tostring(#sourceNames))
    -- Note to self: # gets the length of an array in Lua
    -- Note to self 2: Lua arrays start at 1, not 0
    for i = 1, #audioComps do
        local audioGO = GameObject.FindInChildren(self.gameObject, tostring(sourceNames[i]))
        if not audioGO then
            Engine.Log("[AQUILES AUDIO] Could not find GameObject " .. tostring(sourceNames[i]))
        else
            local key = nameToKey[tostring(sourceNames[i])]
            audioComps[key] = audioGO:GetComponent("Audio Source")
            if not audioComps[key] then
                Engine.Log("[AQUILES AUDIO] Could not retrieve Audio Source from " .. tostring(sourceNames[i]))
            else
                Engine.Log("[AQUILES AUDIO] Found ".. tostring(audioComps[key]))
            end
        end
    end
end


local function FindAquilesAudioComponents(self)
    local stepSource = GameObject.FindInChildren(self.gameObject, "AQ_StepsSource")
    if stepSource then
       stepSFX = stepSource:GetComponent("Audio Source")
    else Engine.Log("[AQUILES] WARNING: Audio Source for steps SFX not found") end

    local voiceSource = GameObject.FindInChildren(self.gameObject, "AQ_VoiceSource")
    if voiceSource then
       voiceSFX = voiceSource:GetComponent("Audio Source")
    else Engine.Log("[AQUILES] WARNING: Audio Source for voice SFX not found") end

    local spearSource = GameObject.FindInChildren(self.gameObject, "AQ_SpearSource")
    if spearSource then
       spearSFX = spearSource:GetComponent("Audio Source")
    else Engine.Log("[AQUILES] WARNING: Audio Source for spear SFX not found") end

    local dashSource = GameObject.FindInChildren(self.gameObject, "AQ_DashSource")
    if dashSource then
       dashSFX = dashSource:GetComponent("Audio Source")
    else Engine.Log("[AQUILES] WARNING: Audio Source for dash SFX not found") end

    local armorSource = GameObject.FindInChildren(self.gameObject, "AQ_ArmorSource")
    if armorSource then
       armorSFX = armorSource:GetComponent("Audio Source")
    else Engine.Log("[AQUILES] WARNING: Audio Source for armor SFX not found") end
end
          
function Start(self)

    self.public = {
        maxHp           = 300,
        maxPosture      = 100,

        -- Ranges
        detectRange     = 25.0,
        Lance360Range   = 2.0,
        chargeRange     = 18.0,
        dashApproachRange = 9.0,
        --Movement
        moveSpeed       = 6.5,
        rotationSpeed   = 1.8,
        stopSmoothing   = 6.0,

        --Lance 360
        lanceDuration       = 0.8,
        lanceCooldown       = 1.2,
        lanceDamage         = 20,

        preparationTime = 1.0,
        chargeSpeed     = 22.0,
        chargeDuration  = 1.0,
        wallStunTime    = 1.5,

        wallSpeedThresh = 1.5,

        afterStunTime   = 1.2,
        chargeCooldown  = 2.0,  -- cooldown entre embestidas
        chargeDamage    = 35,
        stepInterval    = 0.6,

        -- Receive damage
        knockbackForce  = 10.0,

        stunDuration        = 2.0,

        hurtStunTime = 0.4,

        predictionTime = 0.4,

        opportunityDamageMultiplier = 1.0,
        wallStunDuration=2.0,
        recoveryLance = 0.5,
        recoveryCharge = 1.0,
    }

    hp           = self.public.maxHp
    posture = self.public.maxPosture
    isDead       = false
    currentState = State.IDLE

    rb   = self.gameObject:GetComponent("Rigidbody")
    anim = self.gameObject:GetComponent("Animation")

    FindAquilesAudioComponents(self)


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

    Prefab.Load("AquilesFeedback", Engine.GetAssetsPath() .. "/Prefabs/AquilesFeedback.prefab")
    self.chargeFeedbackGO = nil
    self.chargeFeedbackActive = false 
    self.chargeFeedbackTiles = {}

    aquilesMesh = GameObject.FindInChildren(self.gameObject,"aquilesMesh")
    if aquilesMesh then
        BaseMat = aquilesMesh:GetComponent("Material")
    else
        Engine.Log("[Aquiles] ERROR: aquilesMesh no encontrado")
    end
end

function Update(self, dt)
    if not self.gameObject then return end

    if isDead then
        return
    end

    if not rb   then rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not anim then anim = self.gameObject:GetComponent("Animation")  end 

    if not stepSFX or not voiceSFX or not spearSFX or not dashSFX or not armorSFX then
        FindAquilesAudioComponents(self)
    end

    if Input.GetKey("K") then
        --TakeDamage(self, hp, self.transform.worldPosition)
        SelectPlaySFX(voiceSFX, "SFX_AquilesHurt")
        Engine.Log("Aquiles at 1HP!")
        hp = 1
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
            wallAnimStarted = false 
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
    if not playerGO or _G._PlayerController_isDead then return end

    if hitCooldown > 0 then
        hitCooldown = hitCooldown - dt
        if hitCooldown <= 0 then
            self.alreadyHit = false
            
            if hp <=60 then
                BaseMat.SetTexture("10242481670410472725")
            elseif hp > 60 and hp <=120 then
                BaseMat.SetTexture("15230868181932546860")            
            elseif hp > 120 and hp <=180 then
                BaseMat.SetTexture("770031546471412972")
            elseif hp > 180 and hp <=240 then
                BaseMat.SetTexture("14923760841240419563")
            else
                BaseMat.SetTexture("14923760841240419563")
            end        
        end
    end

   
    local myPos
    local pp

    if self.transform then 
        myPos = self.transform.worldPosition
        pp = playerGO.transform.worldPosition
    else
        Engine.Log("Could not retrieve transform value")
    end
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

    if other:CompareTag("Wall") then
        if currentState == State.WALL or currentState == State.RECOVERY or currentState == State.COMBAT_MOVE then 
            return 
        end

        if rb then
            rb:SetLinearVelocity(0, 0, 0)
        end
        StopMovement()
        slideVelX = 0
        slideVelZ = 0
        DestroyChargeFeedback(self)
        wallStunTimer = 5.0
        
    
        anim:Play("Stuck_Start", 0.15)
        ChangeState(State.WALL)


        pendingWallHit = true
      
        Engine.Log("[Aquiles] Choco con la pared")
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
            BaseMat.SetTexture("6600101727014948682")
            TakeDamage(self, dmg, ap)
        end
    end

    if other:CompareTag("Player") then
        -- The player hits the enemy
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack and attack ~= "" then
                alreadyHit = true
                BaseMat.SetTexture("6600101727014948682")
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

            SelectPlaySFX(spearSFX, "SFX_AquilesSpearHit")
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
            wallStunTimer = self.public.recoveryCharge

            if currentState == State.CHARGE then 
                StopMovement()
                slideVelX = 0
                slideVelZ = 0
                DestroyChargeFeedback(self)
                ChangeState(State.RECOVERY)
            end

            Engine.Log("[Aquiles] Impacto " .. currentState .. ". Daño: " .. (finalDamage or 0))
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 

         if hp <=60 then
            BaseMat.SetTexture("10242481670410472725")
        elseif hp > 60 and hp <=120 then
            BaseMat.SetTexture("15230868181932546860")        
        elseif hp > 120 and hp <=180 then
            BaseMat.SetTexture("770031546471412972")
        elseif hp > 180 and hp <=240 then
            BaseMat.SetTexture("14923760841240419563")
        else
            BaseMat.SetTexture("14923760841240419563")
        end 
    end
end