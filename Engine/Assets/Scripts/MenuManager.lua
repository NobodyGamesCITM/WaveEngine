local NEXT_XAML_DEFAULT = "HUD.xaml"
local MIN_LOADING_SCREEN_DURATION = 1.7
local FADE_DURATION      = 0.4
local SCENE_FADE_DURATION = 2.0

Engine.Log("[MenuManager] LUA FILE LOADED / CHUNK EXECUTED")

local assetsPath = Engine.GetAssetsPath()
local scenesPath = Engine.GetScenesPath()

public = {
    updateWhenPaused = true,
	currentScene    = { type = "Scene", value = "" },
    fullVolume = 100.0,
    lowerVolume = 60.0
}

local function EaseInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - (-2 * t + 2) ^ 2 / 2
    end
end

local function SetPhase(self, newPhase)
    self.phase     = newPhase
    self.fadeTimer = 0.0
    Engine.Log("[MenuManager] Phase: " .. newPhase .. " (Instance: " .. tostring(self) .. ")")
end

local function NavigateTo(self, xaml)
    if self.pressSFX then 
        self.pressSFX:SelectPlayAudioEvent("UI_CloseWindow") 
    end
    if not self.history then self.history = {} end
    if self.current and not self.current:find("SplashScreen.xaml") then
        table.insert(self.history, self.current)
    end
    self.nextXaml = xaml
    SetPhase(self, "fadeOut")
    Engine.Log("[MenuManager] Navigating to: " .. xaml)
end

local function NavigateBack(self)
    if self.pressSFX then 
        self.pressSFX:SelectPlayAudioEvent("UI_CloseWindow") 
    end
    if not self.history or #self.history == 0 then return end
    self.nextXaml = table.remove(self.history)
    SetPhase(self, "fadeOut")
    Engine.Log("[MenuManager] Returning back to: " .. self.nextXaml)
end

function Initialize(self)
    Engine.Log("[MenuManager] Re-initializing instance on object: " .. (self.gameObject and self.gameObject.name or "Unknown"))
    
    self.canvas = self.gameObject:GetComponent("Canvas")
    self.phase = "idle"
    self.fadeTimer = 0.0
    self.fading = false
    self.history = {}
    self.pendingScene = nil
    self.loggedReady = false
    self.lastPauseState = nil
    self.waitingForSplash = false
    self.loadingScreenTimer = 0.0
    self.loadingXAMLStarted = false

    _G.GlobalMenuManagerInstance = self

    --Audio.SetMusicState("MainMenu")
    

    self.isMusicPlaying = false
    Engine.Log("[MenuManager] isMusicPlaying reset to false")

    self.musicSource = GameObject.Find("MusicSource")
    if self.musicSource then 
        self.musicComp = self.musicSource:GetComponent("Audio Source")

    end

    self.selectSource = GameObject.Find("UISelectSound")
    if self.selectSource then
        self.selectSFX = self.selectSource:GetComponent("Audio Source")
    end

    self.pressSource = GameObject.Find("UIPressSound")
    if self.pressSource then
        self.pressSFX = self.pressSource:GetComponent("Audio Source")
    end

    if not self.canvas then
        Engine.Log("[MenuManager] ERROR: No ComponentCanvas found during initialization")
        return false
    end

    if _G.SkipSplash and not _G.ForceStartXAML and not self.waitingForSplash then
        Engine.Log("[MenuManager] Esperando a que SplashScreen procese el Skip...")
        self.waitingForSplash = true
        return true
    end

    if _G.ForceStartXAML then
        local path = _G.ForceStartXAML
        _G.ForceStartXAML = nil
        self.current = path
        _G.CurrentXAML = path
        _G.SkipSplash = nil
        self.waitingForSplash = false
        Engine.Log("[MenuManager] ForceStartXAML aplicado: " .. path)
        
        self.canvas:LoadXAML(path)
        self.canvas:SetOpacity(1.0)
        self.fading = false 
        
        if path:find("MainMenu.xaml") then
            Game.Resume()
            self.lastPauseState = "running"
            self.history = {}
        else
            Game.Pause()
            self.lastPauseState = "paused"
        end

        SetPhase(self, "idle")
        Engine.Log("[MenuManager] Re-initialization COMPLETE (forced XAML).")
        return true
    end

    self.current = self.canvas:GetCurrentXAML() or ""
    if self.current == "" and _G.CurrentXAML then
        self.current = _G.CurrentXAML
    end
    
    local sceneVal = self.public.currentScene and self.public.currentScene.value or ""
    local isGameplayScene = (sceneVal == "Level1.scene" or sceneVal == "Blockout2.scene" or sceneVal == "Blockout2Nuevo.scene")

    if isGameplayScene then
        if self.current == "" or self.current:find("MainMenu.xaml") then
            Engine.Log("[MenuManager] Inicializando HUD en escena de juego.")
            self.current = "HUD.xaml"
            self.canvas:LoadXAML("HUD.xaml")
            _G.CurrentXAML = "HUD.xaml"
        end
    elseif self.current == "" then
        self.current = "MainMenu.xaml"
        self.nextXaml = self.current
        _G.CurrentXAML = self.current
    end

    if self.current:find("MainMenu.xaml") and not isGameplayScene then
        Audio.SetMusicState("MainMenu")
        self.history = {}
        self.lastPauseState = "running"
    elseif isGameplayScene then
        
        if sceneVal == "Level1.scene" then Audio.SetMusicState("Level1")
        elseif sceneVal == "Blockout2Nuevo.scene" then Audio.SetMusicState("Level2") end
            
        Game.Resume()
        Game.SetTimeScale(1.0)
        self.lastPauseState = "running"
    end
    
    Engine.Log("[MenuManager] Current XAML: " .. self.current)
    self.canvas:SetOpacity(1.0)
    self.fading = false
    SetPhase(self, "idle")

    Engine.Log("[MenuManager] Re-initialization COMPLETE.")
    return true
end

function Start(self)
    Initialize(self)
end

function Update(self, dt)

    local sceneVal = self.public.currentScene
    local musicState = "None"
    if not Audio.IsEventPlaying("MUS_BGM") then 
        
        if sceneVal == "Level1.scene" then 
           musicState = "Level1"
        elseif sceneVal == "Blockout2Nuevo.scene" then 
           musicState = "Level2"
        elseif sceneVal == "Splash.scene" and _G.SkipSplash then
            musicState = "MainMenu"
        else
            Engine.Log("[Menu Manager] Current Scene = "..tostring(sceneVal))
        end
        
        
        Audio.SetMusicState(tostring(musicState))
        if self.musicComp then self.musicComp:PlayAudioEvent()
        else Engine.Log("Music Audio Source Component NOT found! Music will NOT play!")
        end
        
    end

    if self.waitingForSplash then
        if _G.ForceStartXAML then
            Engine.Log("[MenuManager] ForceStartXAML disponible tras espera. Aplicando...")
            self.waitingForSplash = false
            Initialize(self)
            
        end
        return
    end

    if not self.canvas or _G._MenuManager_NeedReinit then
        _G._MenuManager_NeedReinit = false
        Initialize(self)
        if self.waitingForSplash then return end 
    end

    local isActualMenu = (self.current ~= nil and self.current ~= "" and not self.current:find("HUD.xaml"))

    if isActualMenu then
        if self.current:find("MainMenu.xaml") then
            if self.lastPauseState ~= "running" then
                Game.Resume()
                self.lastPauseState = "running"
            end
        else
            if self.lastPauseState ~= "paused" and self.public.currentScene ~= "Splash.scene" then
                Game.Pause()
                self.lastPauseState = "paused"
            end
        end
        if self.current:find("MainMenu.xaml") then
            Audio.SetMusicState("MainMenu")
            Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
            
        end
    elseif not _G.DialogActive then
        if self.lastPauseState ~= "running" then
            Game.Resume()
            self.lastPauseState = "running"
        end
    end

    if _G._NewSceneLoaded and not self.sceneLoadedFlag then
        self.sceneLoadedFlag = true
        Initialize(self)
    elseif not _G._NewSceneLoaded then
        self.sceneLoadedFlag = false
    end

    if not self.canvas then return end

    if self.phase ~= "idle" then
        self.fadeTimer = self.fadeTimer + dt
    end

    if self.phase == "idle" then
        if not self.loggedReady then
            Engine.Log("[MenuManager] READY AND WAITING FOR ESCAPE (Object: " .. self.gameObject.name .. ", XAML: " .. tostring(self.current) .. ")")
            self.loggedReady = true
        end

        local isDead = false
        if _G.PlayerInstance and _G.PlayerInstance.public then
            isDead = (_G.PlayerInstance.public.health <= 0)
        else
            local playerObj = GameObject.Find("Player")
            if playerObj then
                local pScript = GameObject.GetScript(playerObj)
                if pScript then
                    _G.PlayerInstance = pScript
                    isDead = (pScript.public and pScript.public.health <= 0)
                end
            end
        end

        if isDead and self.current ~= "LoseMenu.xaml" and self.current ~= "MainMenu.xaml" then
            self.history = {}
            NavigateTo(self, "LoseMenu.xaml")
        end

        if Input.GetKeyDown("Escape") or Input.GetGamepadButtonDown("Start") then
            Engine.Log("[MenuManager] Input detected! Current XAML: '" .. tostring(self.current) .. "'")
            
            local isHUD = (self.current == "HUD.xaml") or self.current:find("HUD.xaml")
            local isPause = (self.current == "PauseMenu.xaml") or self.current:find("PauseMenu.xaml")

            if isHUD then
                Engine.Log("[MenuManager] Logic: Open PauseMenu")
                if _G.SuspendDialog then _G.SuspendDialog() end
                NavigateTo(self, "PauseMenu.xaml")
                Game.Pause()
                Audio.SetGlobalVolume(self.public.lowerVolume or 60.0)

            elseif isPause then
                Engine.Log("[MenuManager] Logic: Resume to HUD")
                NavigateTo(self, "HUD.xaml")
                Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
            else
                Engine.Log("[MenuManager] Logic: No HUD/Pause detected, ignoring Escape key.")
            end
        end

        if UI.WasClicked("StartButton") then
            
            if not self.fading then
                Engine.Log("[MenuManager] StartButton clicked: Iniciando fade out para cargar nivel...")
                self.pendingScene = "Level1.scene"
                self.fading = true
                self.canvas:PlayStoryboard("FadeOut")
                --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            end
        end
        if UI.WasClicked("SettingsButton") then
            NavigateTo(self, "SettingsMenu.xaml")
        end
        if UI.WasClicked("ExitButton") then
            if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
            Game.Exit()
        end

        if UI.WasClicked("ResumeButton") then
            NavigateTo(self, "HUD.xaml")
        end

        if UI.WasClicked("TryAgainButton") then
            _G._PlayerController_isDead = false
            NavigateTo(self, "HUD.xaml")
        end

        if UI.WasClicked("BackToMenuButton") then
            if not self.fading then
                Engine.Log("[MenuManager] BackToMenuButton: Iniciando FadeOut y regreso a Splash")
                _G._PlayerController_isDead = false
                if _G.PlayerInstance then
                    _G.PlayerInstance.public.health = 100
                    _G.PlayerInstance.public.stamina = 100
                   
                end
                _G.SkipSplash = true               
                self.pendingScene = "Splash.scene"
                self.fading = true                  
                self.canvas:PlayStoryboard("FadeOut")
                --Audio.SetMusicVolume(self.public.fullVolume or 100)
            end
        end

        if UI.WasClicked("SoundsButton") then
            NavigateTo(self, "SoundsMenu.xaml")
        end
        if UI.WasClicked("GraphicsButton") then
            NavigateTo(self, "GraphicsMenu.xaml")
        end

        local allCanvasButtons = UI.GetCanvasButtons()

        for i, button in ipairs(allCanvasButtons) do
            if UI.WasFocused(tostring(button)) then
                if self.selectSFX then 
                    self.selectSFX:SelectPlayAudioEvent("UI_ButtonSelect") 
                end
            end

            if UI.WasClicked(tostring(button)) then
                if self.pressSFX then 
                    self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") 
                end
            end
        end

        local isEscapeHandled = (self.current == "HUD.xaml" or self.current == "PauseMenu.xaml")
        local canGoBack = self.history and #self.history > 0 and self.current ~= "MainMenu.xaml" and self.current ~= "LoseMenu.xaml"
        if canGoBack and (UI.WasClicked("BackButton") or (Input.GetGamepadButtonDown("East") and self.current ~= "HUD.xaml") or
           (Input.GetKeyDown("Escape") and not isEscapeHandled)) then
            NavigateBack(self)
        end

        if self.fading then
            self.fading = false
            SetPhase(self, "fadeOut")
        end
    end

    if self.phase == "fadeOut" then
        local duration = self.pendingScene and SCENE_FADE_DURATION or FADE_DURATION
        local t     = math.min(self.fadeTimer / duration, 1.0)

        if not self.pendingScene then
            local alpha = 1.0 - EaseInOutQuad(t)
            self.canvas:SetOpacity(alpha)
        else
            local volume = (self.public.fullVolume or 100) * (1 - EaseInOutQuad(t))
            if volume then 
			    Audio.SetMusicVolume(volume)
		    else
			    Engine.Log("Could not set music volume!")
		    end
        end

        if t >= 1.0 then
            if not self.pendingScene then 
                self.canvas:SetOpacity(0.0) 
            else
                Audio.SetMusicVolume(0) 
            end
            SetPhase(self, "swap")
        end

    elseif self.phase == "swap" then
        if self.pendingScene then
            SetPhase(self, "loadingScreenAnimating")
            self.loadingScreenTimer = 0.0
            self.loadingXAMLStarted = false 
            return 
        end

        if self.nextXaml == "PauseMenu.xaml" then
            if _G.SuspendDialog then _G.SuspendDialog() end
        elseif self.nextXaml == "HUD.xaml" and self.current == "PauseMenu.xaml" then
            if _G.ResumeDialog then _G.ResumeDialog() end
        else
            if _G.ForceCloseDialog then _G.ForceCloseDialog() end
        end

        if self.nextXaml == "PauseMenu.xaml" or self.nextXaml == "GraphicsMenu.xaml" or self.nextXaml == "LoseMenu.xaml" or self.nextXaml == "SettingsMenu.xaml" then
            Audio.SetGlobalVolume(self.public.lowerVolume or 60.0)
        elseif self.nextXaml == "MainMenu.xaml" or self.nextXaml == "HUD.xaml" then
            Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
        end

        local previous = self.current
        self.canvas:LoadXAML(self.nextXaml)
        self.current = self.nextXaml
        _G.CurrentXAML = self.current
        self.lastPauseState = nil

        if self.current == "HUD.xaml" then
            Engine.Log("[UI MENU] current scene: " .. tostring(self.public.currentScene.value))
            if self.public.currentScene == "Level1.scene" then
                Audio.SetMusicState("Level1")
            elseif self.public.currentScene == "Blockout2.scene" or self.public.currentScene == "Blockout2Nuevo.scene"then
                if Audio.GetMusicState() ~= "Boss" or Audio.GetMusicState() ~= "AfterBoss" then 
                    Audio.SetMusicState("Level2")
                end
            end

            if previous == "PauseMenu.xaml" then
                Game.Resume()
                self.lastPauseState = "running"
            else
                if _G.ResetPlayer and _G.PlayerInstance then
                    _G.ResetPlayer(_G.PlayerInstance)
                else
                    _G._PlayerController_isDead = false
                end
                Game.Resume()
                self.lastPauseState = "running"
            end

        elseif self.current:find("MainMenu.xaml") then
            Audio.SetMusicState("MainMenu")
            Audio.SetGlobalVolume(self.public.fullVolume or 100.0)

            self.history = {}
            
            Game.Resume()
            self.lastPauseState = "running" 
        end

        Engine.Log("[MenuManager] Swapped to: " .. self.nextXaml)
        self.canvas:SetOpacity(1.0)
        SetPhase(self, "idle")

    elseif self.phase == "loadingScreenAnimating" then
        if self.pendingScene then
            if not self.loadingXAMLStarted then
                Engine.Log("[MenuManager] LoadingScreenAnimating phase: Mostrando LoadingScreen...")
                if self.canvas then
                    self.canvas:LoadXAML("LoadingScreen.xaml")
                end
                self.loadingXAMLStarted = true
            end

            self.loadingScreenTimer = self.loadingScreenTimer + dt
            if self.loadingScreenTimer < MIN_LOADING_SCREEN_DURATION then
                return
            end
            Engine.Log("[MenuManager] LoadingScreenAnimating phase: Duración mínima cumplida. Procediendo a cargar la escena " .. self.pendingScene)
            self.loadingXAMLStarted = false

            Engine.LoadScene(self.pendingScene)
            self.pendingScene = nil

            return
        end

        SetPhase(self, "idle")
    end
end
