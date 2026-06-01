--Aquiles Script

local atan2 = math.atan
local pi    = math.pi
local sqrt  = math.sqrt
local min   = math.min
local abs   = math.abs

-- States
local State = {
    IDLE        = "Idle",
    COMBAT_MOVE = "COMBAT_MOVE",
    LANCE_360   = "Lance360",
    ANTICIPATION = "Anticipation",
    CHARGE      = "Charge",
    DASH        = "Dash",
    WALL        = "Wall",
    RECOVERY    = "Recovery",
    STUN        = "Stun",
    DEAD        = "Dead",
}
public = {
    doorName = "Puerta_Final",
	lockOnSize      = 14.0,
    attackAreaFinalScale = 25.0,
}

local currentState = State.IDLE
local hp           = 0
local posture       = 0     
local isDead       = false
local deathTimer = 20.1
local deathAnimDone = false
local blockHits = false

local rb       = nil
local anim     = nil
local playerGO = nil
local attackCol    = nil
local attackCol    = nil

local aquilesMesh = nil

local colliderAreaAttack = nil
local colliderLance= nil
local attacklanceCol = nil
local areaAttackColObj = nil

local voiceSFX = nil
local stepSFX = nil
local spearSFX = nil
local dashSFX = nil
local armorSFX = nil
local areaSFX = nil

local sourceNames = {"AQ_VoiceSource", "AQ_StepSource", "AQ_SpearSource", "AQ_DashSource", "AQ_ArmorSource"}

local bloodPs = nil
local sparksPs = nil

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
local cameFromWall = false 

local lanceTimer    = 0 
local feedbackTimer = 0
local lanceCDTimer  = 0   
local dashCDTimer   = 0
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

-- Dash
local dashDirX      = 0
local dashDirZ      = 0
local dashTimer     = 0
local DASH_DURATION = 0.35
local DASH_SPEED    = 14.0

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

local ActiveDodge = false

local BaseMat = nil

local hitsReceivedCounter = 0

local wallAnimStarted = false
local stunAnimStarted = false
local opportunityHitTimer = 0 
local chargeAnimStarted = false
local lanceAnimStarted = false
local lanceHitActive   = false  -- colisión solo activa durante la ventana de golpe
local attackAreaActive = false
local anticipationAnimStarted = false
local recoveryAnimStarted = false

local playedBigStep = false
local playedDeepBreaths = false
local playedDeathCry = false
local playedKneelDown = false
local playedCollapse = false



local hitCooldown = 0
local finishedTransition = false

local TILE_SIZE = 3.744
local lastPPos = {x = 0, z = 0}

local isKinematic = false

local fase1 = true

local currentMaxHp = 300

local AquilesFeedback = "/Prefabs/AquilesFeedback.prefab"
local AttackAreaFeedback = "/Prefabs/AQ_ATKArea_Feedback.prefab"
local attackArea = nil
local currentFeedbackScale = 0
local currentColliderScale = 0
local attackAreaTransform = nil

local isWinBossPlaying = false
local winBossCinematicTimer = 22.0

--Fase2

local fase2Active    = false
local fase2Timer     = 0
local Fase2_Duration = 60        

local spawnTimer     = 0
local SPAWN_INTERVAL = 20 

local Prefab_Skeleton  = "/Prefabs/Skeleton_Fase2.prefab"
local Prefab_Minocabro = "/Prefabs/MinocabroPrefab.prefab"

local spawnedEnemies = {}
local pendingPositions = {}


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
    if audioComp then audioComp:PlayAudioEvent() end
end

local function StopSFX(audioComp)
    if audioComp then audioComp:StopAudioEvent() end
end

local function SelectPlaySFX(audioComp, eventName)
    if audioComp then audioComp:SelectPlayAudioEvent(eventName) end
    if not audioComp then Engine.Log("Could not retrieve "..tostring(audioComp).." Audio Source") end
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
    rb:SetLinearVelocity(0, 0, 0)
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
    pressureTimer = 0
    chargeAnimStarted    = false
    lanceAnimStarted     = false
    --lanceHitActive       = false
    --if colliderAreaAttack then colliderAreaAttack:Disable() end
    --if attackArea then attackArea:SetActive(false) end
    --feedbackTimer = 0
    --currentFeedbackScale = 0
    anticipationAnimStarted = false
    recoveryAnimStarted  = false
    dashTimer = 0

    --if colliderAreaAttack and newState == State.LANCE_360 then
        --colliderAreaAttack:Enable()
  ---  else
        --colliderAreaAttack:Disable()
 --   end


    if attackCol then
        if newState == State.CHARGE  then
            if attacklanceCol then attacklanceCol:Enable() end        
            attackCol:Enable()
        else
            attackCol:Disable()
            if attacklanceCol then attacklanceCol:Disable() end

        end
    end

    inOpportunity = (newState == State.WALL or newState == State.STUN)
end

local function FadeOutBossMusic(self, dt)
    if volume > 0 and not finishedTransition then 
        fadeMusicTimer = fadeMusicTimer + dt
        local progressPercent = math.min((fadeMusicTimer/3.5), 1.0)
        volume = 100 * (1 - progressPercent)
        if volume then 
            Audio.SetMusicVolume(volume)
        end
    elseif volume <= 0 and not finishedTransition then
        finishedTransition = true
        Audio.SetMusicVolume(0)
    end

    if _G._PlayerController_isDead then
        Audio.SetMusicState("Level2")
        fadeMusicTimer = 0
        Audio.SetMusicVolume(100)
    end 
end

-- Fase2
local function CalcSpawnPos(myPos, index, total)
    local baseAngle = (2 * math.pi / total) * (index - 1)
    local angle = baseAngle + ((math.random() - 0.5) * 0.8)
    local radius = 3 + math.random() * 2         
    return
        myPos.x + math.cos(angle) * radius,
        myPos.y,
        myPos.z + math.sin(angle) * radius
end

local function QueueSpawn(self, prefabPath, index, total)
    local myPos = self.transform.worldPosition
    local x, y, z = CalcSpawnPos(myPos, index, total)
    local enemy = Prefab.Instantiate(prefabPath)
    if enemy then
        table.insert(spawnedEnemies, enemy)
        table.insert(pendingPositions, { enemy = enemy, x = x, y = y, z = z, frames = 3 })
    end
end

local series = {
    { Prefab_Skeleton, Prefab_Skeleton, Prefab_Skeleton, Prefab_Minocabro, Prefab_Minocabro },
    { Prefab_Skeleton, Prefab_Skeleton, Prefab_Minocabro, Prefab_Minocabro }, 
    { Prefab_Skeleton, Prefab_Skeleton, Prefab_Skeleton, Prefab_Skeleton,  Prefab_Minocabro  },
    { Prefab_Skeleton, Prefab_Minocabro, Prefab_Minocabro },                                    
    { Prefab_Skeleton, Prefab_Skeleton, Prefab_Skeleton },                                      
}
local lastTandaIdx = 0 

local function SpawnSeries(self)
    math.randomseed(os.time() + math.random(1000))

    local idx
    repeat
        idx = math.random(#series)
    until idx ~= lastTandaIdx
    lastTandaIdx = idx

    local list = series[idx]
    local total = #list

    for i, prefabPath in ipairs(list) do
        QueueSpawn(self, prefabPath, i, total)
    end
end

local function ProcessPendingPositions()
    for i = #pendingPositions, 1, -1 do
        local entry = pendingPositions[i]
        entry.frames = entry.frames - 1
        if entry.frames <= 0 then
            if entry.enemy and entry.enemy.transform then
                entry.enemy.transform:SetPosition(entry.x, entry.y, entry.z)
            end
            table.remove(pendingPositions, i)
        end
    end
end

local function AllEnemiesDead()
    for i = #spawnedEnemies, 1, -1 do
        local e = spawnedEnemies[i]
        if not e or not e.gameObject then
            table.remove(spawnedEnemies, i)
        end
    end
    return #spawnedEnemies == 0
end


local function UpdateFase2(self, dt)

    ProcessPendingPositions()

    if rb then
        if isKinematic then
            rb:SetBody(1)
            isKinematic = false
        end
        rb:SetLinearVelocity(0, 0, 0)
    end

    fase2Timer = fase2Timer - dt
    local allEnemies  = GameObject.FindByTag("Enemy")
    local totalLive   = 0
    if allEnemies then
        for _, enemie in ipairs(allEnemies) do
            if enemie:IsActive() then
                    totalLive = totalLive + 1
                end
            end
        
    end

    if fase2Timer > 0 then
        spawnTimer = spawnTimer + dt
        if spawnTimer >= SPAWN_INTERVAL or totalLive==1 then
            spawnTimer = 0
            SpawnSeries(self)
        end

    elseif AllEnemiesDead() and totalLive==1  then
        fase2Active    = false
        spawnedEnemies = {}
 
        -- Stats fase 3
        hp      = 400
        posture = 150
        self.public.chargeDamage   = 30
        self.public.chargeSpeed    = 40.0
        self.public.chargeCooldown = 1.5
        self.public.lanceDamage    = 20
        self.public.lanceCooldown  = 0.4
        self.public.moveSpeed      = 8
 
        blockHits    = false   
        currentMaxHp = 400
        if _G.BossBar_ResetToFull    then _G.BossBar_ResetToFull(400) end
        if _G.BossBar_SetVisibility  then _G.BossBar_SetVisibility(true) end
        if _G.BossBar_RefreshHealth  then _G.BossBar_RefreshHealth(hp, currentMaxHp) end
 
        Engine.Log("[AQUILES] Fase 3 comenzada")
        ChangeState(State.COMBAT_MOVE)
    end
end

local function TakeDamage(self, amount, attackerPos)
    if isDead then return end
    if blockHits then return end

    if _G.TriggerCameraShake then
        _G.TriggerCameraShake(0.1, 0.5, 5.0)
    end

    _PlayerController_triggerCameraShake = true

    if rb and attackerPos then
        local pos = self.transform.worldPosition
        local dx  = pos.x - attackerPos.x
        local dz  = pos.z - attackerPos.z
        local len = sqrt(dx*dx + dz*dz)
        if len > 0.001 then dx = dx/len; dz = dz/len end
        rb:AddForce((dx * self.public.knockbackForce) / 10, 0, (dz * self.public.knockbackForce) / 10, 2)
    end
    local hasPosture = (posture>0)

    local dmg = 0

    if hasPosture and not inOpportunity then
        posture = posture - amount
        PlaySFX(armorSFX)
        if sparksPs then sparksPs:Play() end

        if posture > 0 then
            StopMovement()
            ChangeState(State.IDLE)
        else
            StopMovement()
            stunTimer=self.public.stunDuration
            rb:SetBody(2)
            isKinematic = true
            ChangeState(State.STUN)
        end

        Engine.Log("Aquiles HP = " .. tostring(hp))
        Engine.Log("Aquiles Escudo = " .. tostring(posture))
        return
    end

    -- Baja vida
    if hasPosture and inOpportunity then
        dmg = amount * self.public.opportunityDamageMultiplier

    elseif not hasPosture and not inOpportunity then
        dmg = amount * 0.4 
        
    else
        dmg = amount * self.public.opportunityDamageMultiplier
    end

    hp = hp - dmg

    Engine.Log("Aquiles HP = " .. tostring(hp))
    Engine.Log("Aquiles Escudo = " .. tostring(posture))

    if _G.BossBar_RefreshHealth then
        _G.BossBar_RefreshHealth(hp, currentMaxHp)
    end


    SelectPlaySFX(voiceSFX, "SFX_AquilesHurt")
    if bloodPs then bloodPs:Play() end

    
    if inOpportunity then
        if currentState == State.WALL then
            anim:Play("Stuck_Hit", 0.1)
            SelectPlaySFX(spearSFX, "SFX_AquilesWallHit")
        elseif currentState == State.STUN then
            anim:Play("Stun_Hit", 0.1)
        end
        
    else
        if currentState == State.COMBAT_MOVE or currentState == State.RECOVERY then
            StopMovement()
            hurtTimer = self.public.hurtStunTime
            anim:Play("Hit", 0.1)
        end
    end

    -- Dead
    if hp <= 0 then
        if not fase1 then
            _G._AquilesDefeated = true
            Game.SetTimeScale(0.1)
            _impactFrameTimer = 0.3
            blockHits = true
            ChangeState(State.DEAD)
            SelectPlaySFX(voiceSFX, "SFX_AquilesDeath")
            if _G.BossBar_SetVisibility then _G.BossBar_SetVisibility(false) end
 
        elseif not fase2Active then
            fase1       = false
            fase2Active = true
            fase2Timer  = Fase2_Duration
            spawnTimer  = 0
            spawnedEnemies = {}
 
            hp      = 1 
            posture = 0
            blockHits = true
 
            StopMovement()
            if anim then anim:Play("Idle", 0.2) end

            -- Primera serie
            SpawnSeries(self)
            Engine.Log("[AQUILES] Fase 2 iniciada")
        end
        return
    end


    if not inOpportunity and currentState == State.COMBAT_MOVE then
        hitsReceivedCounter = hitsReceivedCounter + 1

        PlaySFX(armorSFX)
        if sparksPs then sparksPs:Play() end
        
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
        end
    end
end

local function StartDash(self, dirX, dirZ)
    dashDirX  = dirX
    dashDirZ  = dirZ
    dashTimer = 0
    StopMovement()
    PlaySFX(dashSFX)
    --PlayAnim("Dash", 0.1)
    ActiveDodge = true
    ChangeState(State.DASH)

    local myPos = self.transform.worldPosition
    local pp    = playerGO.transform.worldPosition
    local toPlayerX = pp.x - myPos.x
    local toPlayerZ = pp.z - myPos.z
    
    local dot = (dirX * toPlayerX) + (dirZ * toPlayerZ)
    
    if anim then
        if dot < 0 then
            anim:Play("Dash_Backwards", 0.1)
        else
            anim:Play("Dash", 0.1)
        end
    end
end

local function MovementWalk(self, dx, dz, dt, speedOverride)
    local myPos = self.transform.worldPosition
    local pPos  = playerGO.transform.worldPosition
    local dist  = Dist(myPos, pPos)

    if dist <= self.public.minDistanceToPlayer then
        rb:SetLinearVelocity(0, 0, 0)
        if anim and not anim:IsPlayingAnimation("Idle") then anim:Play("Idle", 0.2) end
        return
    end

    local vel = speedOverride or self.public.moveSpeed
    if anim and not anim:IsPlayingAnimation("Walk") then anim:Play("Walk", 0.2) end

    stepTimer = stepTimer + dt
    if stepTimer >= (self.public.stepInterval / 10 * vel) then
        SelectPlaySFX(stepSFX, "SFX_AquilesSteps")
        stepTimer = 0
    end

    RotateTowards(self, dx, dz, self.public.rotationSpeed, dt)
    rb:SetLinearVelocity(dx * vel, 0, dz * vel)
end

local function UpdateIdle(self, dist)
    if anim and not anim:IsPlayingAnimation("Idle") then
        anim:Play("Idle")
    end
    if dist <= self.public.detectRange and _G.BossBar_SetVisibility and _G.BossBar_RefreshHealth then
        _G.BossBar_SetVisibility(true)
        _G.BossBar_RefreshHealth(hp, currentMaxHp)
    end
    if dist <= self.public.detectRange then
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateCombatMove(self, myPos, pp, dist, dt)
    if isKinematic then
        rb:SetBody(1)
        isKinematic = false
    end

    if dist > self.public.detectRange then
        StopMovement()
        if _G.BossBar_SetVisibility then _G.BossBar_SetVisibility(false) end
        ChangeState(State.IDLE)
        return
    end

    if hurtTimer > 0 then
        hurtTimer = hurtTimer - dt
        return
    end

    if lanceCDTimer  > 0 then lanceCDTimer  = lanceCDTimer  - dt end
    if chargeCDTimer > 0 then chargeCDTimer = chargeCDTimer - dt end
    if dashCDTimer   > 0 then dashCDTimer   = dashCDTimer   - dt end

    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end


    if dashCDTimer <= 0 then
        -- Hacia atrás
        if dist < self.public.Lance360Range and lanceCDTimer > 0 then
            dashCDTimer = 3.5
            StartDash(self, -dx, -dz) 
            return
        end

        -- Hacia adelante
        if dist >= self.public.Lance360Range and dist <= self.public.dashApproachRange then
            if lanceCDTimer <= 0 then
                dashCDTimer = 4.0
                StartDash(self, dx, dz) 
                return
            end
        end
    end

    if dist < self.public.Lance360Range then
        if lanceCDTimer <= 0 then
            StopMovement()
            lanceTimer       = 0
            lanceAnimStarted = false
            ChangeState(State.LANCE_360)
            SelectPlaySFX(spearSFX, "SFX_AquilesSpearSwing")
        else
            MovementWalk(self, dx, dz, dt, self.public.moveSpeed * 0.8)
        end
        return
    end

    if dist <= self.public.chargeRange then
        if chargeCDTimer <= 0 then
            StopMovement()
            chargeDirX       = dx
            chargeDirZ       = dz
            preparationTimer = 0
            chargeCDTimer    = self.public.chargeCooldown
            ChangeState(State.ANTICIPATION)
        else
            MovementWalk(self, dx, dz, dt)
        end
        return
    end

    MovementWalk(self, dx, dz, dt)
end

local function UpdateLance360(self, myPos, pp, dt)

    if rb then rb:SetLinearVelocity(0, 0, 0) end

    if not lanceAnimStarted then
        lanceAnimStarted = true
        lanceHitActive   = false
        anim:Play("AreaAttack", 0.1)
        feedbackTimer = 0
        currentFeedbackScale = 0
        currentColliderScale = 0
    end

    --if lanceAnimStarted then attackAreaActive = true end
    lanceTimer = lanceTimer + dt

   if lanceTimer < self.public.lanceWindup or lanceTimer > (self.public.lanceWindup + 0.15) then
        --if colliderAreaAttack then colliderAreaAttack:Disable() end
        --if attackArea then attackArea:SetActive(false) end
        

        --and lanceTimer <= (self.public.lanceWindup + 0.15)
    elseif lanceTimer >= self.public.lanceWindup  and not attackAreaActive then
        if colliderAreaAttack then
            attackAreaActive = true 
            lanceHitActive = true
            if colliderAreaAttack then 
                colliderAreaAttack:Enable() 
                colliderAreaAttack:SetRadius(1.0,1.0,1.0)
            end
           
            if not attackArea then
                attackArea = GameObject.Find("AQ_ATKArea_Feedback")
            end
            if not attackArea then 
                attackArea = Prefab.Instantiate(AttackAreaFeedback)
            end

            if attackArea then 
 
                local t = areaAttackColObj.transform
                if t then

                    local pos = t.worldPosition 
                    --local rot = t.worldRotation
                    attackArea.transform:SetPosition(pos.x, pos.y + 0.5, pos.z)
                    --attackArea.transform:SetRotation(rot.x, rot.y, rot.z)
                    attackArea.transform:SetScale(1.0, 1.0, 1.0)
                    SelectPlaySFX(spearSFX, "SFX_AquilesSpearHit")
                    SelectPlaySFX(areaSFX, "SFX_AquilesAreaExp")
                else
                    Engine.Log("AttackArea Collider Object Position not found!")
                end

                attackArea:SetActive(true)

                
            end
            
        end
    end

    


    if lanceTimer >= self.public.lanceDuration then
        --if colliderAreaAttack then colliderAreaAttack:Disable() end
        --if attackArea then attackArea:SetActive(false) end
        lanceHitActive   = false
        lanceCDTimer     = self.public.lanceCooldown
        wallStunTimer    = self.public.recoveryLance
        ChangeState(State.RECOVERY)
        lanceTimer = 0
        --attackAreaActive = false
    end
    --cannot scale feedback here because it'd stop abruptly if the state changes
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
    --local myLocalPos = self.transform.position
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
        local maxChargeDistance = self.public.chargeSpeed * self.public.chargeDuration
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
            for _, tile in ipairs(self.chargeFeedbackTiles) do
                if tile then GameObject.Destroy(tile) end
            end
            self.chargeFeedbackTiles = {}
            for i = 1, numTiles do
                local tile = Prefab.Instantiate(AquilesFeedback)
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
            rb:SetLinearVelocity(backDx * 5.0, 0, backDz * 5.0)
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
        anim:Play("Charge_Loop")
    end
    
    if rb then
        rb:SetLinearVelocity(chargeDirX * self.public.chargeSpeed, 0, chargeDirZ * self.public.chargeSpeed)
    end
    

    if chargeTimer >= self.public.chargeDuration then
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
        rb:SetLinearVelocity(0, 0, 0)
        rb:SetRotation(0, currentYaw, 0)
        rb:SetBody(2)
    end

    if opportunityHitTimer > 0 then
        opportunityHitTimer = opportunityHitTimer - dt
        return
    end
    
    if anim and not anim:IsPlayingAnimation("Stuck_Loop") and not anim:IsPlayingAnimation("Stuck_Hit") then
        anim:Play("Stuck_Loop", 0.1)
        
    end

    if anim and anim:IsPlayingAnimation("Stuck_Loop") then
        if not Audio.IsEventPlaying("SFX_AquilesStuck") then
            SelectPlaySFX(voiceSFX, "SFX_AquilesStuck")
        end
    end


    wallStunTimer = wallStunTimer - dt
    if wallStunTimer <= 0 then
        isKinematic = true
        wallAnimStarted = false
        anim:Play("Stuck_End", 0.15)
        slideVelX = 0
        slideVelZ = 0
        wallStunTimer = self.public.afterStunTime
        cameFromWall = true
        ChangeState(State.RECOVERY)
    end
end


local function UpdateDash(self, myPos, pp, dt)
    dashTimer = dashTimer + dt

    local dx = pp.x - myPos.x
    local dz = pp.z - myPos.z
    local len = sqrt(dx*dx + dz*dz)
    if len > 0.001 then dx = dx/len; dz = dz/len end

    if rb then
        
        -- Detectar si vamos hacia adelante usando producto punto
        local dot = (dashDirX * dx) + (dashDirZ * dz)
        local currentSpeed = DASH_SPEED
        if dot > 0 then
            currentSpeed = DASH_SPEED * 1.6 -- Le damos un impulso extra al dash de acercamiento para cubrir los 13 metros
        end

        rb:SetLinearVelocity(dashDirX * currentSpeed, 0, dashDirZ * currentSpeed)
        RotateTowards(self, dx, dz, self.public.rotationSpeed * 2.0, dt)    
    end

    if dashTimer >= DASH_DURATION then
        StopMovement()
        ActiveDodge   = false
        pressureTimer = 0

        local dist = Dist(myPos, pp)

        -- Al terminar el dash, si estamos cerca (menor a 8.0) y listo, reventamos el suelo
        if dist < self.public.Lance360Range and lanceCDTimer <= 0 then  
            lanceTimer       = 0
            lanceAnimStarted = false
            ChangeState(State.LANCE_360)
            SelectPlaySFX(spearSFX, "SFX_AquilesSpearSwing")
        else
            ChangeState(State.COMBAT_MOVE)
        end
    end
end

local function UpdateRecovery(self, dt)
    if isKinematic then
        rb:SetBody(1)
        isKinematic = false
    end

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
        rb:SetLinearVelocity(slideVelX, 0, slideVelZ)
    end

    wallStunTimer = wallStunTimer - dt

    if wallStunTimer <= 0 then
        lanceCDTimer = self.public.lanceCooldown
        chargeCDTimer = self.public.chargeCooldown
        cameFromWall = false
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateStun(self, dt)
    rb:SetLinearVelocity(0, 0, 0)

    if not stunAnimStarted then
        anim:Play("Stun_Start", 0.15)
        stunAnimStarted = true
        return  
    end

    if anim:IsPlayingAnimation("Stun_Start") then
        return
    end

    if not anim:IsPlayingAnimation("Stun_Loop") then
        anim:Play("Stun_Loop", 0.1)
    end

    stunTimer = stunTimer - dt
    if stunTimer <= 0 then
        posture = 0
        ChangeState(State.COMBAT_MOVE)
    end
end

local function UpdateDeath(self, dt)

    if fase1 == true then
        hp      = 500 
        posture = 100 
        isDead  = false

        self.public.detectRange    = 27.0
        self.public.chargeDamage      = 45
        self.public.chargeSpeed       = 40.0 
        self.public.chargeCooldown    = 1.5
        self.public.lanceDamage       = 30
        self.public.lanceCooldown     = 0.4
        self.public.moveSpeed         = 8
        self.public.preparationTime   = 0.5 
        self.public.wallStunTime      = 1.0
        self.public.afterStunTime     = 0.7
        self.public.stunDuration      = 1.5
        self.public.predictionTime    = 0.2 


        currentState = State.IDLE
        fase1 = false

        currentMaxHp = 500
        if _G.BossBar_ResetToFull then
            _G.BossBar_ResetToFull(500)
        end

        return
    else
        
        deathTimer = deathTimer - dt
        
        if rb then
            rb:SetLinearVelocity(0, 0, 0)
            rb:SetBody(2)
        end
        if _impactFrameTimer == 0 and _G._AquilesDefeated == false and deathAnimDone == false then
            if anim then anim:Play("CinematicDeath") end
            self.transform:SetPosition(131.563, -0.926, -657.100)
            self.transform:SetRotation(-180, 76.951, -180)
            deathAnimDone = true
        end

        -- if deathAnimDone then 
        --     if anim then anim:Play("Idle") end
        -- end

        if deathTimer <= 0 then
            if self.targetDeathYisEnter == false then
                local currentY = self.transform.position.y
                self.targetDeathY = currentY - 5.0
                self.targetDeathYisEnter = true
                
                local colision = self.gameObject:GetComponent("Box Collider")
                if colision then 
                    colision:Disable() 
                    
                    if rb then rb:SetUseGravity(false) end
                end
                
                DestroyChargeFeedback(self)
                Audio.SetMusicState("AfterBoss")
            end

            local pos = self.transform.position
            if pos.y > self.targetDeathY then
                self.transform:SetPosition(pos.x, pos.y - 2.0, pos.z)
            else
                if not isDead then
                      local door = GameObject.Find("Puerta_Final") 
                    if door then
                        local doorScript = door:GetComponent("Script")
                        if doorScript and doorScript.OpenDoor then
                            doorScript:OpenDoor()
                        end
                    end

                    local colision = self.gameObject:GetComponent("Box Collider")
                    if colision then 
                        colision:Disable() 
                        if rb then rb:SetUseGravity(false) end
                    end
                    isDead = true
                    Engine.Log("[Aquiles] DEAD i enterrat")

                  

                    rb       = nil
                    anim     = nil
                    playerGO = nil
                end
            end
        end
    end
end

local function FindAquilesAudioComponents(self)
    local stepSource = GameObject.FindInChildren(self.gameObject, "AQ_StepsSource")
    if stepSource then stepSFX = stepSource:GetComponent("Audio Source") end

    local voiceSource = GameObject.FindInChildren(self.gameObject, "AQ_VoiceSource")
    if voiceSource then voiceSFX = voiceSource:GetComponent("Audio Source") end

    local spearSource = GameObject.FindInChildren(self.gameObject, "AQ_SpearSource")
    if spearSource then spearSFX = spearSource:GetComponent("Audio Source") end

    local dashSource = GameObject.FindInChildren(self.gameObject, "AQ_DashSource")
    if dashSource then dashSFX = dashSource:GetComponent("Audio Source") end

    local armorSource = GameObject.FindInChildren(self.gameObject, "AQ_ArmorSource")
    if armorSource then armorSFX = armorSource:GetComponent("Audio Source") end

    local areaSource = GameObject.FindInChildren(self.gameObject, "AreaAttackCollider")
    if areaSource then areaSFX = areaSource:GetComponent("Audio Source") end
end

local function FindAquilesParticles(self)
    local bloodVFX = GameObject.FindInChildren(self.gameObject, "BloodDrops")
    if bloodVFX then 
        bloodPs = bloodVFX:GetComponent("ParticleSystem")
    end

    local sparksVFX = GameObject.FindInChildren(self.gameObject, "Sparks")
    if sparksVFX then 
        sparksPs = sparksVFX:GetComponent("ParticleSystem")
    end
end
          
function Start(self)

    self.public = {
        maxHp           = 200, --Antes 300
        maxPosture      = 100,

        detectRange     = 30.0, --Antes 25
        Lance360Range   = 8.0, --Antes 2
        chargeRange     = 18.0,
        dashApproachRange = 13.0,

        moveSpeed       = 6.5,
        rotationSpeed   = 1.8,
        stopSmoothing   = 6.0,

        lanceWindup         = 0.6,    
        lanceDuration       = 2.0,
        feedbackScaleTime   = 3.0,   
        lanceCooldown       = 1.0, -- Antes1.2
        lanceDamage         = 20,

        preparationTime = 1.0,
        chargeSpeed     = 30.0, -- antes 22
        chargeDuration  = 0.4,
        wallStunTime    = 1.5,
        wallSpeedThresh = 1.5,
        afterStunTime   = 1.2,
        chargeCooldown  = 2.0,
        chargeDamage    = 35,
        stepInterval    = 0.6,

        knockbackForce  = 10.0,
        stunDuration    = 1.5,
        hurtStunTime    = 0.4,
        predictionTime  = 0.2, --Antes 0.4

        opportunityDamageMultiplier = 1.0,
        wallStunDuration = 2.0,
        recoveryLance    = 0.5,
        recoveryCharge   = 0.5, -- Antes 1.0


        minDistanceToPlayer=6.0,
    }

    currentMaxHp = self.public.maxHp

    hp           = self.public.maxHp
    posture      = self.public.maxPosture
    isDead       = false
    currentState = State.IDLE

    --cinematics
    isWinBossPlaying = false
    winBossCinematicTimer = 22.0

    rb   = self.gameObject:GetComponent("Rigidbody")
    anim = self.gameObject:GetComponent("Animation")

    Engine.RequestResource("10242481670410472725")
    Engine.RequestResource("15230868181932546860")
    Engine.RequestResource("770031546471412972")
    Engine.RequestResource("14923760841240419563")

    FindAquilesAudioComponents(self)
    FindAquilesParticles(self)

    areaAttackColObj = GameObject.FindInChildren(self.gameObject, "AreaAttackCollider")

    if areaAttackColObj then
        colliderAreaAttack = areaAttackColObj:GetComponent("Sphere Collider")
    else
        Engine.Log("[Aquiles] Attack Collider GameObject not found!")
    end
    
    if colliderAreaAttack then colliderAreaAttack:Disable() end
    if attackArea then attackArea:SetActive(false) end
    attackAreaTransform = self.transform

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then attackCol:Disable() end

    colliderLance = GameObject.FindInChildren(self.gameObject, "LanceCollider")
    attacklanceCol = colliderLance:GetComponent("Sphere Collider")
    if attacklanceCol then attacklanceCol:Disable()
    else Engine.Log("No encontrado") end

    if anim then anim:Play("Idle") end
    
    --feedbackTimer = 0
    lanceCDTimer  = 0
    chargeCDTimer = 0
    dashCDTimer   = 0

    self.chargeFeedbackGO     = nil
    self.chargeFeedbackActive = false 
    self.chargeFeedbackTiles  = {}


    if not attackArea then 
        attackArea = Prefab.Instantiate(AttackAreaFeedback)
        -- if attackArea then attackArea:SetActive(false) end
    end
    --attackAreaActive = false
    --lanceHitActive = false

    aquilesMesh = GameObject.FindInChildren(self.gameObject, "aquilesMesh")
    if aquilesMesh then
        BaseMat = aquilesMesh:GetComponent("Material")
    end

    self.targetDeathY        = nil
    self.targetDeathYisEnter = false
end

function Update(self, dt)

    if not self.gameObject then return end
    if isDead then return end

    if not rb   then rb   = self.gameObject:GetComponent("Rigidbody")  end
    if not anim then anim = self.gameObject:GetComponent("Animation")  end 

    --local AQworldPos = self.gameObject.transform.worldPosition
    --local AQworldRot = self.gameObject.transform.worldRotation

    if not stepSFX or not voiceSFX or not spearSFX or not dashSFX or not armorSFX or not areaSFX then
        FindAquilesAudioComponents(self)
    end

    if not bloodPs or not sparksPs then 
        FindAquilesParticles(self)
    end

    if Input.GetKey("0") then
        fase1 = false
        TakeDamage(self, hp, self.transform.worldPosition)
        return
    end


    if Input.GetKeyDown("K") then
        local damage = hp + 1
        if damage > 0 then
            TakeDamage(self, damage, self.transform.worldPosition)
        end
        return
        
    end

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

    if not playerGO then
        playerGO = GameObject.Find("Player")
    end
    if not playerGO or _G._PlayerController_isDead then 
        if _G.BossBar_SetVisibility then
            _G.BossBar_SetVisibility(false)
        end
        return 
    end

    if hitCooldown > 0 then
        hitCooldown = hitCooldown - dt
        if hitCooldown <= 0 then
            self.alreadyHit = false
            if hp <= 60 then
                BaseMat.SetTexture("10242481670410472725")
            elseif hp > 60 and hp <= 120 then
                BaseMat.SetTexture("15230868181932546860")            
            elseif hp > 120 and hp <= 180 then
                BaseMat.SetTexture("770031546471412972")
            elseif hp > 180 and hp <= 240 then
                BaseMat.SetTexture("14923760841240419563")
            else
                BaseMat.SetTexture("14923760841240419563")
            end        
        end
    end

    
    if attackArea then attackArea:SetActive(attackAreaActive) end
    if not attackAreaActive then colliderAreaAttack:Disable() end
    
    if attackAreaActive then 
        feedbackTimer = feedbackTimer + dt

        --Engine.Log("Current feedback scale timer = " ..tostring(feedbackTimer))

        if feedbackTimer <= 1.0 then
            --scale feedback gradually
            local progressPercent = math.min((feedbackTimer/1.0), 1.0)
            --Engine.Log("ProgressPercent = "..tostring(progressPercent))
            currentFeedbackScale = (self.public.attackAreaFinalScale or 25.0) * progressPercent
            currentColliderScale = 100.0 * progressPercent
            --Engine.Log("currentFeedbackScale = "..tostring(currentFeedbackScale))

            
            if attackArea then
                local t = attackArea.transform
                if t then t:SetScale(currentFeedbackScale, currentFeedbackScale, currentFeedbackScale) end
                if colliderAreaAttack then colliderAreaAttack:SetRadius(currentColliderScale, currentColliderScale, currentColliderScale) end
                
            end
            
        elseif feedbackTimer > 1.0 then
            
            if attackArea then attackArea:SetActive(false) end
            feedbackTimer = 0
            --currentFeedbackScale = 0.0
            attackAreaActive = false
            --attackAreaTransform = nil
        end
    end
    
    

    local myPos
    local myLocalPos
    local myRot
    local myLocalRot
    local pp

    if self.transform then 
        myPos = self.transform.worldPosition
        myLocalPos = self.transform.position
        myRot = self.transform.worldRotation
        myLocalRot = self.transform.rotation
        pp = playerGO.transform.worldPosition


        local currentPos = self.transform.worldPosition
        local floorheight = -1.5

        if currentPos.y > floorheight then
            self.transform:SetPosition(currentPos.x, floorheight, currentPos.z)
            
            if rb then
                rb:SetLinearVelocity(slideVelX or 0, 0, slideVelZ or 0)
            end
        end
    end
    if not pp then return end


    local dist = Dist(myPos, pp)   

    if fase2Active then
        UpdateFase2(self, dt)
        return
    end

    if     currentState == State.IDLE         then UpdateIdle(self, dist)
    elseif currentState == State.COMBAT_MOVE  then UpdateCombatMove(self, myPos, pp, dist, dt)
    elseif currentState == State.LANCE_360    then UpdateLance360(self, myPos, pp, dt)
    elseif currentState == State.ANTICIPATION then UpdateAnticipation(self, pp, dt)
    elseif currentState == State.CHARGE       then UpdateCharge(self, dt)
    elseif currentState == State.DASH         then UpdateDash(self, myPos, pp, dt)
    elseif currentState == State.WALL         then UpdateWall(self, dt)
    elseif currentState == State.RECOVERY     then UpdateRecovery(self, dt)
    elseif currentState == State.STUN         then UpdateStun(self, dt)
    elseif currentState == State.DEAD         then UpdateDeath(self, dt)
    end


    -- winboss cinematic

    if _G.PlayWinBossCinematic and _G._AquilesDefeated and not isWinBossPlaying then 
        isWinBossPlaying = true
        winBossCinematicTimer = 22.0
        
    end

    if isWinBossPlaying then 

        winBossCinematicTimer = winBossCinematicTimer - dt

        if winBossCinematicTimer <= 21.8 and winBossCinematicTimer >= 21.00 and not playedDeepBreaths then 
            SelectPlaySFX(voiceSFX, "SFX_DeepBreaths")
            playedDeepBreaths = true
        end

        if winBossCinematicTimer <= 21.00 and winBossCinematicTimer >= 20.8 and not playedBigStep then
            SelectPlaySFX(stepSFX, "SFX_AquilesBigStep")
            playedBigStep = true
        end

        if winBossCinematicTimer <= 9.3 and winBossCinematicTimer >= 9.0 and not playedDeathCry then
            if Audio.IsEventPlaying("SFX_DeepBreaths") then 
                StopSFX(voiceSFX) 
            end
            SelectPlaySFX(voiceSFX, "SFX_AquilesDeath")
            playedDeathCry = true
        end

        if winBossCinematicTimer <= 5.00 and winBossCinematicTimer >= 4.9 and not playedKneelDown then
            SelectPlaySFX(spearSFX, "SFX_KneelDown")
            playedKneelDown = true
        end

        if winBossCinematicTimer <= 4.00 and winBossCinematicTimer >= 3.9 and not playedCollapse then
            SelectPlaySFX(armorSFX, "SFX_AquilesCollapse")
            playedCollapse = true
        end
        
        if winBossCinematicTimer < 0 then 
            isWinBossPlaying = false
            playedDeepBreaths = false
            playedBigStep = false
            playedDeathCry = false
            playedKneelDown = false
            playedCollapse = false
            winBossCinematicTimer = 0
        end
    end
    
end

function OnTriggerEnter(self, other)
    if blockHits then return end
    if isDead and hp<=0 then return end

    if other:CompareTag("Wall") then
        local lancePos = colliderLance.transform.worldPosition
        local wallPos = other.transform.worldPosition

        local dx = lancePos.x - wallPos.x
        local dz = lancePos.z - wallPos.z
        local distLance = sqrt(dx*dx + dz*dz)

        if distLance > 2.0 then return end
        
        if currentState == State.WALL or currentState == State.RECOVERY or currentState == State.COMBAT_MOVE or currentState == State.IDLE then 
            return 
        end
        Engine.Log("Estoy dentro")

        if rb then rb:SetLinearVelocity(0, 0, 0) end
        StopMovement()
        slideVelX = 0
        slideVelZ = 0
        DestroyChargeFeedback(self)

        if fase1 then
            wallStunTimer = 5.0
        else
            wallStunTimer = self.public.wallStunTime + 1
        end

        anim:Play("Stuck_Start", 0.15)
        ChangeState(State.WALL)
        pendingWallHit = true
        return 
       
    end

    if other:CompareTag("Bullet") then
        if not self.alreadyHit then
            local ap  = other.transform.worldPosition
            local dmg = 15
            self.alreadyHit = true
            hitCooldown = 0.2
            BaseMat.SetTexture("6600101727014948682")
            
            TakeDamage(self, dmg, ap)
            
        end
    end

    if other:CompareTag("Player") then
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

        if (currentState == State.CHARGE or currentState == State.LANCE_360) and not alreadyHit and _PlayerController_pendingDamage == 0 and not isKinematic then
            SelectPlaySFX(spearSFX, "SFX_AquilesSpearHit")
            alreadyHit = true

            local finalDamage
            if currentState == State.CHARGE then
                finalDamage = self.public.chargeDamage
            elseif currentState == State.LANCE_360 then
                finalDamage = self.public.lanceDamage
            end

            _PlayerController_pendingDamage      = finalDamage
            _PlayerController_pendingDamagePos   = self.transform.worldPosition
            _PlayerController_triggerCameraShake = true
            
            Engine.Log("he hecho dentro")


            if attackCol then attackCol:Disable() end
            if colliderLance then colliderLance:Disable() end
            --if colliderAreaAttack then colliderAreaAttack:Disable() end
            --if attackArea then attackArea:SetActive(false) end
            --feedbackTimer = 0
            --currentFeedbackScale = 0

            wallStunTimer = self.public.recoveryCharge

            if currentState == State.CHARGE then 
                StopMovement()
                slideVelX = 0
                slideVelZ = 0
                DestroyChargeFeedback(self)
                ChangeState(State.RECOVERY)
            end
        end
    end

end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then 
        alreadyHit = false 

        if hp <= 60 then
            BaseMat.SetTexture("10242481670410472725")
        elseif hp > 60 and hp <= 120 then
            BaseMat.SetTexture("15230868181932546860")        
        elseif hp > 120 and hp <= 180 then
            BaseMat.SetTexture("770031546471412972")
        elseif hp > 180 and hp <= 240 then
            BaseMat.SetTexture("14923760841240419563")
        else
            BaseMat.SetTexture("14923760841240419563")
        end 
    end
end