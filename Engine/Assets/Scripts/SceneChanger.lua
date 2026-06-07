
--Scene Changer Script
public = {
    targetScene = "Level2",
    fadeSpeed   = 1.0,
    musicFadeTime = 2.0,
    currentLevel = "Level1",
    loadingDuration = 2.5,
    maxVolume = 100.0,
    fullIntro = false
}


local State = {
    FADE_OUT = 0,
    IDLE     = 1,
    FADE_IN  = 2, 
    LOADING  = 3,
    DONE     = 4
}

local currentState = State.FADE_OUT
local currentAlpha = 1.0
local canvasComponent = nil 
local musicFadeTimer = 0.0
local volume = 100.0
local startDelay = 1.5
local loadingTimer = 0.0
local portalExitTimer = 0.0



function Start(self)

    if self.public.currentLevel == "Level1" and self.public.fullIntro and self.gameObject.name == "SceneManager" then 
        if _G.LoadedFromSave then
            _G._PlayerController_introAnim = false 
        else
            _G._PlayerController_introAnim = true 
        end
    else
        _G._PlayerController_introAnim = false 
    end
    
    currentState = State.LOADING
    currentAlpha = 1.0 
    loadingTimer = 0.0
    
    _G._NewSceneLoaded = true 

    _G.CurrentLevel = self.public.currentLevel
    canvasComponent = self.gameObject:GetComponent("Canvas") 

    if not canvasComponent then
        Engine.Log("[SceneTransition] ERROR: No se encontró Canvas.")
    else
        canvasComponent:LoadXAML("LoadingScreen.xaml")
        canvasComponent:SetOpacity(1.0) 
    end

    self.StartTransition = StartTransition

    if self.public.currentLevel == "Level2" then
        if not _G.LoadedFromSave then
            -- FIX: bloquejem la loading screen fins que la cinemàtica de portal estigui llesta
            _G.PortalCinematicReady = false
            portalExitTimer = 8.0
            if _G.PlayerInstance then 
                _G.PlayerInstance.public.canMove = false 
            end
            if _G.SetPlayerAnimTimer then _G.SetPlayerAnimTimer(15.0) end
        else
            _G.PortalCinematicReady = true
            portalExitTimer = 0.0
        end
    else
        -- Altres escenes no necessiten esperar cap cinemàtica
        _G.PortalCinematicReady = true
    end
end

function Update(self, dt)

    if Input.GetKeyDown("F8") then
        Engine.Log("[DEBUG] F8 presionado: Forzando salto a Level2")
        StartTransition(self, "Level2")
    end

    if not canvasComponent then return end
    _G.SceneManagerState = currentState

    if portalExitTimer > 0 then
        portalExitTimer = portalExitTimer - dt
        if portalExitTimer <= 0 and _G.PlayerInstance then
            portalExitTimer = 0
            _G.PlayerInstance.public.canMove = false
            if _G.SetPlayerAnimTimer then _G.SetPlayerAnimTimer(18.0) end
            if _G.StartPortalExitAnim then _G.StartPortalExitAnim() end
            
            if _G.PlayPortalExitCinematic then _G.PlayPortalExitCinematic() end

            local anim = _G.PlayerInstance.gameObject:GetComponent("Animation")
            if anim then
                pcall(function() anim:Play("Idle", 0.0) end)
                pcall(function() anim:Play("PortalExit", 0.0) end)
            end

            -- FIX: la cinemàtica ja s'ha llançat, ara podem fer el fade out de la loading screen
            _G.PortalCinematicReady = true
            Engine.Log("[SceneChanger] PortalCinematicReady activat.")
        end
    end

    if currentState == State.FADE_OUT then
        currentAlpha = currentAlpha - (self.public.fadeSpeed * dt)
        musicFadeTimer = musicFadeTimer + (self.public.musicFadeTime * dt)
        local progressPercent = math.min((musicFadeTimer/(self.public.musicFadeTime or 2.0)), 1.0)
        volume = (self.public.maxVolume or 100.0) * (progressPercent)
        
        if currentAlpha <= 0.0 and volume >= (self.public.maxVolume or 100.0) then
            volume = self.public.maxVolume or 100.0
            currentAlpha = 0.0
            musicFadeTimer = 0
            currentState = State.IDLE

            -- FIX: si tornem al MainMenu, avisem el MenuManager
            if self.public.currentLevel == "MainMenu" or self.public.targetScene == "Splash.scene" or self.public.targetScene == "Splash" then
                _G.MainMenuNeedsIntro = true
                Engine.Log("[SceneChanger] MainMenuNeedsIntro activat.")
            end

            _G._MenuManager_NeedReinit = true
        end
        SetMusicVolume(volume)
        SetSFXVolume(volume)
        SetCanvasAlpha(currentAlpha)

    elseif currentState == State.LOADING then
        loadingTimer = loadingTimer + dt

        -- FIX: per Level2 (sense save), esperem tant el loadingDuration mínim
        -- com que la cinemàtica de portal estigui llesta (_G.PortalCinematicReady)
        local minTimeReached = loadingTimer >= (self.public.loadingDuration or 2.5)
        local cinematicReady = (_G.PortalCinematicReady == true)

        if minTimeReached and cinematicReady then
            if _G._NewSceneLoaded then
                currentState = State.FADE_OUT
                _G._NewSceneLoaded = false
                if canvasComponent then canvasComponent:LoadXAML("FadePanel.xaml") end
            else
                if Engine.LoadScene then
                    _G._NewSceneLoaded = true
                    Engine.LoadScene(self.public.targetScene)
                end
            end
        end

    elseif currentState == State.FADE_IN then
        currentAlpha = currentAlpha + (self.public.fadeSpeed * dt)
        musicFadeTimer = musicFadeTimer + (self.public.musicFadeTime * dt)
        local progressPercent = math.min((musicFadeTimer/(self.public.musicFadeTime or 2.0)), 1.0)
        volume = (self.public.maxVolume or 100.0) * (1 - progressPercent)
        
        if currentAlpha >= 1.0 then
            currentAlpha = 1.0
            volume = 0
            musicFadeTimer = 0
            loadingTimer = 0
            currentState = State.LOADING
            SetCanvasAlpha(currentAlpha)
            SetMusicVolume(volume)
            SetSFXVolume(volume)

            if canvasComponent then
                canvasComponent:LoadXAML("LoadingScreen.xaml")
            end
        end
        
        SetCanvasAlpha(currentAlpha)
        SetMusicVolume(volume)
        SetSFXVolume(volume)

    end
end

function StartTransition(self, sceneName)
    if currentState == State.IDLE or currentState == State.FADE_OUT then
        _G._MidRunTransition = true
        Engine.Log("[SceneTransition] Transición iniciada por script hacia: " .. tostring(sceneName))

        if _G.PotionSystem and _G.PotionSystem.public then
            local ps = _G.PotionSystem.public
            _G._SavedPotionCount  = ps.potionCount
            _G._SavedMaxPotions   = ps.maxPotions
            _G._SavedBerserkCount = ps.berserkCount
            _G._SavedMaxBerserk   = ps.maxBerserk
        end

        _G._SavedCurrentMask = _G._PlayerController_currentMask
        
        if sceneName then
            self.public.targetScene = sceneName
        end
        
        if canvasComponent then canvasComponent:LoadXAML("FadePanel.xaml") end
        currentState = State.FADE_IN
        
        if _G.PlayerInstance then
            _G.PlayerInstance.public.canMove = false
        end
    end
end

function SetCanvasAlpha(alpha)
    if canvasComponent then
        if canvasComponent.SetOpacity then
            canvasComponent:SetOpacity(alpha)
        end
    end
end

function SetMusicVolume(volume)
    if volume then 
        Audio.SetMusicVolume(volume)
    end
end

function SetSFXVolume(volume)
    if volume then
        Audio.SetSFXVolume(volume)
    end
end