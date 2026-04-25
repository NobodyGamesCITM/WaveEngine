public = {
    nextXaml = { type = "String", value = "MainMenu.xaml" }, 
    totalDuration = 6.5,
    fadeSpeed = 0.5,    
    updateWhenPaused = true
}

local function InitState(self)
    self.splashCanvas    = self.gameObject:GetComponent("Canvas")
    self.splashFinished  = false
    self.splashFadingOut = false
    self.splashTimer     = 0.0
    self.splashFadeTimer = 0.0
    self.splashStarted   = true
end

function Start(self)
    InitState(self)

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

    if self.splashFinished then return end

    if _G.SkipSplash then
        if not self.splashCanvas then self.splashCanvas = self.gameObject:GetComponent("Canvas") end
        if self.splashCanvas then
            local path = self.public.nextXaml
            if type(path) == "table" then path = path.value end

            Engine.Log("[SplashScreen] Skip detectado en Update. Forzando: " .. path)
            
            self.splashFinished = true
            _G.ForceStartXAML = path  
            _G._MenuManager_NeedReinit = true
            _G.SkipSplash = nil

            if self.splashCanvas:LoadXAML(path) then
                self.splashCanvas:SetOpacity(1.0)
                _G.CurrentXAML = path
            else
                Engine.Log("[SplashScreen] ERROR: No se pudo cargar " .. path .. ". Desbloqueando MenuManager de todos modos.")
            end
            return
        end
    end

    self.splashTimer = self.splashTimer + dt

    local skipInput = Input.GetKeyDown("Space") or Input.GetKeyDown("X") or Input.GetKeyDown("Enter")

    if skipInput and not self.splashFadingOut then
        self.splashFadingOut = true
        if self.splashCanvas then self.splashCanvas:PlayStoryboard("FadeOutBlack") end
        self.splashFadeTimer = 0.0
        Engine.Log("Splash Screen: Omitido por el usuario")
    end

    if self.splashTimer >= self.public.totalDuration and not self.splashFadingOut then
        self.splashFadingOut = true
        if self.splashCanvas then self.splashCanvas:PlayStoryboard("FadeOutBlack") end
        self.splashFadeTimer = 0.0
    end

    if self.splashFadingOut then
        self.splashFadeTimer = self.splashFadeTimer + dt

        if self.splashFadeTimer >= self.public.fadeSpeed then
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
                end
            end
        end
    end
end