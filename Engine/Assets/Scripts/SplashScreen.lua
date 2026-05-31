-- SplashScreen Script

public = {
    nextXaml = "MainMenu.xaml", 
    totalDuration = 6.5,
    fadeSpeed = 0.5,    
    updateWhenPaused = true,
    maxVolume = 100
}

local function InitState(self)
    self.splashCanvas    = self.gameObject:GetComponent("Canvas")
    self.splashFinished  = false
    self.splashFadingOut = false
    self.splashTimer     = 0.0
    self.splashFadeTimer = 0.0
    self.splashStarted   = true
    self.musicFadeTimer  = 0.0
    self.currentAlpha    = 1.0
  

    local bgMusic = GameObject.Find("MusicSource")
    if bgMusic then
        self.musicComp = bgMusic:GetComponent("Audio Source")
        if not self.musicComp then Engine.Log("Could not find BGM Audio Source Component") end
    else 
        Engine.Log("Could not find BGM GameObject") 
    end
    
end



local function PlayBGM(self)

    Audio.SetMusicState("MainMenu")

    if not Audio.IsEventPlaying("MUS_BGM") then
        if bgMusic then 
            bgMusic:SelectPlayAudioEvent("MUS_BGM") 
        else
            Engine.Log("[SplashScreen] BGM Audio Source Component not found")
        end
    else
        Engine.Log("[SplashScreen] BGM_MUS already playing")
    end

end

local function FadeInMusic(self, dt)
    self.musicFadeTimer = self.musicFadeTimer + dt
	local progressPercent = math.min((self.musicFadeTimer/(self.public.fadeSpeed or 0.5)), 1.0)
	local volume = (self.public.maxVolume or 100) * (progressPercent)

    if volume then
        if volume >= (self.public.maxVolume or 100) then volume = self.public.maxVolume or 100  end
        Audio.SetMusicVolume(volume)
    else
        Engine.Log("Could not set music volume!")
    end
    if self.splashFadeTimer >= self.public.fadeSpeed then
        PlayBGM(self)
    end
    

end

local function SetCanvasAlpha(self, alpha)
    if self.splashCanvas then
        if self.splashCanvas.SetOpacity then
            self.splashCanvas:SetOpacity(alpha)
        else
            Engine.Log("Set Opacity not found!")
        end
    else
        Engine.Log("Splash Canvas not found!")
    end
end

local function FadeOutBlackCanvas(self, fadeSpeed, dt)

    Engine.Log("Fading out black canvas!!")
    self.currentAlpha = self.currentAlpha - (fadeSpeed * dt)        
    if self.currentAlpha then

        if self.currentAlpha <= 0.0 then self.currentAlpha = 0.0 end
        SetCanvasAlpha(self, self.currentAlpha)
    else
        Engine.Log("[Splash Screen] Could not set Canvas alpha!")
    end
end

function Start(self)
    InitState(self)
    --Audio.SetMusicState("MainMenu")
    Audio.SetMusicVolume(self.public.maxVolume)

    if _G.SkipSplash then
        return
    end

    if self.splashCanvas then
        self.splashCanvas:PlayStoryboard("Intro")
        Engine.Log("Splash Screen: Iniciando animación Intro")
    end
end

function Update(self, dt)
    if not self.splashStarted then
        InitState(self)
    end

    if self.splashFinished then 
        PlayBGM(self)
        return 
    end

    if _G.SkipSplash then
        if not self.splashCanvas then self.splashCanvas = self.gameObject:GetComponent("Canvas") end
        if self.splashCanvas then
            local path = self.public.nextXaml
            if type(path) == "table" then path = path.value end

            Engine.Log("[SplashScreen] Skip detectado en Update. Forzando: " .. path)

            
            --FadeInMusic(self, dt)
            
            self.splashFinished = true
            _G.ForceStartXAML = path  
            _G._MenuManager_NeedReinit = true
            _G.SkipSplash = nil

            if self.splashCanvas:LoadXAML(path) then
             
                _G.CurrentXAML = path
            else 
                Engine.Log("[SplashScreen] ERROR: No se pudo cargar " .. path .. ". Desbloqueando MenuManager de todos modos.")
            end
            return
        end
    end

    self.splashTimer = self.splashTimer + dt

    local skipInput = Input.GetKeyDown("Space") or Input.GetKeyDown("X") or Input.GetKeyDown("Enter") or Input.GetGamepadButtonDown("A")

    if skipInput and not self.splashFadingOut then
        self.splashFadingOut = true
        if self.splashCanvas then self.splashCanvas:PlayStoryboard("FadeOutBlack") end
        self.splashFadeTimer = 0.0
        Engine.Log("Splash Screen: Omitido por el usuario")
    end

    if self.splashTimer >= self.public.totalDuration and not self.splashFadingOut then
        self.splashFadingOut = true
        
        --self.currentAlpha = 0.0
        if self.splashCanvas then self.splashCanvas:PlayStoryboard("FadeOutBlack") end
        self.splashFadeTimer = 0.0
    end

    if self.splashFadingOut then
        self.splashFadeTimer = self.splashFadeTimer + dt
        
        
        -- if not self.splashFinished then 
        --     FadeOutBlackCanvas(self, 2, dt)
        -- end
		--FadeInMusic(self, dt)
        --PlayBGM(self)
        Audio.SetMusicState("MainMenu")

        if self.splashFadeTimer >= self.public.fadeSpeed then 
            --self.currentAlpha = 1.0
            
            self.splashFinished = true

            if self.splashCanvas then
                local path = self.public.nextXaml
                if type(path) == "table" then path = path.value end

                Engine.Log("Splash Screen: Transición a " .. path)
                if self.splashCanvas:LoadXAML(path) then

                    self.splashCanvas:SetOpacity(1.0)
                    
                    _G.CurrentXAML = path
                    _G._MenuManager_NeedReinit = true
                    _G.SkipSplash = nil
                    
                    
                else
                    Engine.Log("Splash Screen ERROR: No se pudo cargar " .. path)
                    _G._MenuManager_NeedReinit = true -- Forzamos el re-inicio del Manager aunque falle la carga para limpiar el historial
                end
            end
        end
    end
end
