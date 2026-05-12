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

public = {
    targetScene = "Level2",
    fadeSpeed   = 1.0,
    musicFadeTime = 2.0,
    currentLevel = "Level1",
    loadingDuration = 1.7,
    maxVolume = 100.0,
    fullIntro = false
}

function Start(self)
    if self.public.currentLevel == "Level1" and self.public.fullIntro == true and self.gameObject.name == "SceneManager" then 
        _G._PlayerController_introAnim = true 
    end
    
    currentState = State.LOADING
    currentAlpha = 1.0 
    loadingTimer = 0.0
    
    _G._NewSceneLoaded = true 

    _G.CurrentLevel = self.public.currentLevel
    canvasComponent = self.gameObject:GetComponent("Canvas") 

    self.musicSource = GameObject.Find("MusicSource")
    if self.musicSource then 
        self.musicComp = self.musicSource:GetComponent("Audio Source")
        if self.musicComp then 
            Engine.Log("[SceneChanger] Music Audio Source Component Found") 
        end
    end

    if not canvasComponent then
        Engine.Log("[SceneTransition] ERROR: No se encontró Canvas.")
    else
        canvasComponent:LoadXAML("LoadingScreen.xaml")
        canvasComponent:SetOpacity(1.0) 
        _G.CurrentXAML = "LoadingScreen.xaml"
    end

    self.StartTransition = StartTransition
end

function Update(self, dt)

    if Input.GetKeyDown("F8") then
        Engine.Log("[DEBUG] F8 presionado: Forzando salto a Level2")
        StartTransition(self, "Level2")
    end
	
	if not Audio.IsEventPlaying("MUS_BGM") then
        local sceneVal = self.public.currentScene 
        local musicState = "None"
        
        if self.public.currentLevel == "Level1" then 
           musicState = "Level1"
        elseif self.public.currentLevel == "Level2" then 
           musicState = "Level2"
        elseif self.public.currentLevel == "MainMenu" and _G.SkipSplash then
            musicState = "MainMenu"
        else
            Engine.Log("[SceneChanger] Current Scene = "..tostring(self.public.currentLevel))
        end
        
        Audio.SetMusicState(tostring(musicState))
        self.musicSource = GameObject.Find("MusicSource")
        if self.musicSource then 
            self.musicComp = self.musicSource:GetComponent("Audio Source")
            if self.musicComp then 
                self.musicComp:PlayAudioEvent() 
            end
        end
    end

    if not canvasComponent then return end
    _G.SceneManagerState = currentState

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
			_G._MenuManager_NeedReinit = true
        end
        SetMusicVolume(volume)
        SetCanvasAlpha(currentAlpha)

    elseif currentState == State.LOADING then
        loadingTimer = loadingTimer + dt
        if loadingTimer >= (self.public.loadingDuration or 1.7) then
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

            if canvasComponent then
                canvasComponent:LoadXAML("LoadingScreen.xaml")
            end
        end
        
        SetCanvasAlpha(currentAlpha)
        SetMusicVolume(volume)
    end
end

function StartTransition(self, sceneName)
    if currentState == State.IDLE or currentState == State.FADE_OUT then
        _G._MidRunTransition = true
        Engine.Log("[SceneTransition] Transición iniciada por script hacia: " .. tostring(sceneName))

        -- Guardar estado de pociones para persistencia entre niveles
        if _G.PotionSystem and _G.PotionSystem.public then
            local ps = _G.PotionSystem.public
            _G._SavedPotionCount  = ps.potionCount
            _G._SavedMaxPotions   = ps.maxPotions
            _G._SavedBerserkCount = ps.berserkCount
            _G._SavedMaxBerserk   = ps.maxBerserk
        end
        
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
    else
        --Engine.Log("Could not set music volume!")
    end
end