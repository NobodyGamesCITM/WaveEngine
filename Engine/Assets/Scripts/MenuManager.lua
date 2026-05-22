local NEXT_XAML_DEFAULT = "HUD.xaml"
local MIN_LOADING_SCREEN_DURATION = 1.7
local FADE_DURATION      = 0.5
local SCENE_FADE_DURATION = 2.0

Engine.Log("[MenuManager] LUA FILE LOADED / CHUNK EXECUTED")

local assetsPath = Engine.GetAssetsPath()
local scenesPath = Engine.GetScenesPath()

if not _G.SavedSoundEffectsVolume then _G.SavedSoundEffectsVolume = 80.0 end
if not _G.SavedMusicVolume        then _G.SavedMusicVolume        = 80.0 end

public = {
    updateWhenPaused = true,
    currentScene    = { type = "Scene", value = "" },
    fullVolume = 100.0,
    lowerVolume = 60.0
}
local FADE_IN_DURATION = 0.4
local DEATH_MENU_DELAY = 1.5

local function ApplyFullVolume(self)
    Audio.SetSFXVolume(_G.SavedSoundEffectsVolume)
    Audio.SetMusicVolume(_G.SavedMusicVolume)
end

local function ApplyLowerVolume(self)
    local factor = (self.public.lowerVolume or 60.0) / (self.public.fullVolume or 100.0)
    Audio.SetSFXVolume(_G.SavedSoundEffectsVolume * factor)
    Audio.SetMusicVolume(_G.SavedMusicVolume * factor)
end

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

local function InitAudioSources(self)
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
end

function Initialize(self)
    if not self.public then
        self.public = {
            updateWhenPaused = true,
            currentScene = { type = "Scene", value = "" },
            fullVolume = 100.0,
            lowerVolume = 60.0
        }
    end

    _G.CinematicActive = false
    Engine.Log("[MenuManager] Re-initializing instance on object: " .. (self.gameObject and self.gameObject.name or "Unknown"))

    self.canvas = self.gameObject:GetComponent("Canvas")
    if not self.canvas then
        Engine.Log("[MenuManager] ERROR: No ComponentCanvas found during initialization")
        return false
    end

    if not self.phase      then self.phase      = "idle" end
    if not self.fadeTimer  then self.fadeTimer   = 0.0   end
    if not self.current    then self.current     = ""    end
    if not self.history    then self.history     = {}    end
    if not self.deathTimer then self.deathTimer  = 0.0   end

    self.fading                = false
    self.pendingScene          = nil
    self.loggedReady           = false
    self.lastPauseState        = nil
    self.waitingForSplash      = false
    self.loadingScreenTimer    = 0.0
    self.loadingXAMLStarted    = false
    self.pendingHUDRefresh     = false
    self.soundsMenuInitialized = false

    _G.GlobalMenuManagerInstance = self
    self.NavigateTo = NavigateTo

    InitAudioSources(self)
    ApplyFullVolume(self)

    if _G.SkipSplash and not _G.ForceStartXAML then
        self.waitingForSplash = true
        Engine.Log("[MenuManager] Waiting for ForceStartXAML (SkipSplash active)...")
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
        self.canvas:SetOpacity(0.0)
        self.fading = true

        if path:find("MainMenu.xaml") or path:find("Splash.scene") then
            Game.Resume()
            self.lastPauseState = "running"
            self.history = {}
        else
            Game.Pause()
            self.lastPauseState = "paused"
        end

        SetPhase(self, "fadeIn")
        Engine.Log("[MenuManager] Re-initialization COMPLETE (forced XAML).")
        return true
    end

    local sceneVal = ""
    if type(self.public.currentScene) == "table" then
        sceneVal = self.public.currentScene.value or ""
    elseif type(self.public.currentScene) == "string" then
        sceneVal = self.public.currentScene
    end

    local isGameplayScene = (sceneVal:find("Level1") ~= nil or sceneVal:find("Level2") ~= nil)

    local function isTransientXAML(x)
        return not x or x == ""
            or x:find("LoadingScreen.xaml") ~= nil
            or x:find("FadePanel.xaml") ~= nil
    end

    if isGameplayScene then
        Engine.Log("[MenuManager] Inicializando HUD en escena de juego.")
        self.current = "HUD.xaml"
        _G.CurrentXAML = "HUD.xaml"
        self.canvas:LoadXAML("HUD.xaml")
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
    else
        self.current = self.canvas:GetCurrentXAML() or ""
        if isTransientXAML(self.current) then
            if _G.CurrentXAML and not isTransientXAML(_G.CurrentXAML) then
                self.current = _G.CurrentXAML
            else
                self.current = "MainMenu.xaml"
            end
        end
        _G.CurrentXAML = self.current
    end

    if self.current:find("MainMenu.xaml") and not isGameplayScene then
        Audio.SetMusicState("MainMenu")
        self.history = {}
        self.lastPauseState = "running"
    elseif isGameplayScene then
        if sceneVal == "Level1.scene" then
            Audio.SetMusicState("Level1")
        elseif sceneVal == "Level2.scene" then
            Audio.SetMusicState("Level2")
        end
        Game.Resume()
        Game.SetTimeScale(1.0)
        self.lastPauseState = "running"
    end

    Engine.Log("[MenuManager] Current XAML: " .. tostring(self.current))
    if not _G.TitleTrigger_HUDShouldStartHidden then
        self.canvas:SetOpacity(1.0)
    else
        self.canvas:SetOpacity(0.0)
        Engine.Log("[MenuManager] TitleTrigger activo: HUD inicializado oculto.")
    end

    Engine.Log("[MenuManager] Re-initialization COMPLETE.")
    return true
end

function Start(self)
    self.canvas = self.gameObject:GetComponent("Canvas")
    if not self.canvas then
        Engine.Log("[MenuManager] ERROR: No Canvas in Start, aborting.")
        return
    end
    Initialize(self)
end

function Update(self, dt)
    if _G.TitleTrigger_Active then return end

    if not self.canvas then
        self.canvas = self.gameObject:GetComponent("Canvas")
        if not self.canvas then return end
        Engine.Log("[MenuManager] Canvas recovered in Update.")
    end

    if not self.musicComp or not self.selectSFX or not self.pressSFX then
        InitAudioSources(self)
    end

    if not Audio.IsEventPlaying("MUS_BGM") then
        local sceneVal = ""
        if type(self.public.currentScene) == "table" then
            sceneVal = self.public.currentScene.value or ""
        elseif type(self.public.currentScene) == "string" then
            sceneVal = self.public.currentScene
        end

        local musicState = "None"
        if sceneVal:find("Level1") then
            musicState = "Level1"
        elseif sceneVal:find("Level2") or sceneVal:find("Blockout2") then
            musicState = "Level2"
        elseif sceneVal == "Splash.scene" and _G.SkipSplash then
            musicState = "MainMenu"
        else
            Engine.Log("[Menu Manager] Current Scene = " .. tostring(sceneVal))
        end
        Audio.SetMusicState(tostring(musicState))
        if self.musicComp then
            self.musicComp:PlayAudioEvent()
        end
    end

    if self.waitingForSplash then
        if _G.ForceStartXAML then
            self.waitingForSplash = false
            Initialize(self)
        end
        return
    end

    if _G._MenuManager_NeedReinit then
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
    elseif not _G.DialogActive and not _G.CinematicActive then
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

    if not self.phase      then self.phase      = "idle" end
    if not self.fadeTimer  then self.fadeTimer   = 0.0   end
    if not self.history    then self.history     = {}    end
    if not self.deathTimer then self.deathTimer  = 0.0   end

    local function currentIsTransient()
        return not self.current or self.current == ""
            or self.current:find("LoadingScreen.xaml") ~= nil
            or self.current:find("FadePanel.xaml") ~= nil
    end
    if currentIsTransient() then
        local sv = ""
        if type(self.public.currentScene) == "table" then
            sv = self.public.currentScene.value or ""
        elseif type(self.public.currentScene) == "string" then
            sv = self.public.currentScene
        end
        if sv:find("Level1") or sv:find("Level2") then
            self.current = "HUD.xaml"
        else
            self.current = "MainMenu.xaml"
        end
        _G.CurrentXAML = self.current
        Engine.Log("[MenuManager] current era transitorio, corregido a: " .. self.current)
    end

    if self.phase ~= "idle" then
        self.fadeTimer = self.fadeTimer + dt
    end

    if self.phase == "idle" then

        if self.current == "SoundsMenu.xaml" then
            if not self.soundsMenuInitialized then
                self.soundsMenuInitialized = true
                UI.SetSliderValue("SoundEffectsSlider", _G.SavedSoundEffectsVolume)
                UI.SetSliderValue("MusicSlider",        _G.SavedMusicVolume)
                Engine.Log("[MenuManager] SoundsMenu cargado: SFX=" ..
                    tostring(_G.SavedSoundEffectsVolume) .. " Music=" .. tostring(_G.SavedMusicVolume))
            end

            if UI.SliderValueChanged("SoundEffectsSlider") then
                local val = UI.GetSliderValue("SoundEffectsSlider")
                _G.SavedSoundEffectsVolume = val
                Engine.Log("[MenuManager] SFX SLIDER CHANGED: " .. tostring(val))
                Audio.SetSFXVolume(val)
                Engine.Log("[MenuManager] SFX volume set: " .. tostring(val))
            end

            if UI.SliderValueChanged("MusicSlider") then
                local val = UI.GetSliderValue("MusicSlider")
                _G.SavedMusicVolume = val
                Audio.SetMusicVolume(val)
                Engine.Log("[MenuManager] Music volume: " .. tostring(val))
            end
        else
            if self.soundsMenuInitialized then
                self.soundsMenuInitialized = false
            end
        end

        if self.pendingHUDRefresh then
            self.pendingHUDRefresh = false
            if _G.ForceRefreshHUD then
                _G.ForceRefreshHUD()
            end
        end

        if not self.loggedReady then
            Engine.Log("[MenuManager] READY (Object: " .. self.gameObject.name .. ", XAML: " .. tostring(self.current) .. ")")
            self.loggedReady = true
        end

        if not self.deathTimer then self.deathTimer = 0.0 end

        local playerHealth = 101
        if _G.PlayerInstance and _G.PlayerInstance.public then
            playerHealth = _G.PlayerInstance.public.health
        else
            local playerObj = GameObject.Find("Player")
            if playerObj then
                local pScript = GameObject.GetScript(playerObj)
                if pScript then
                    _G.PlayerInstance = pScript
                    playerHealth = pScript.public and pScript.public.health or 101
                end
            end
        end

        local playerIsDead = (playerHealth <= 0)

        if not _G.CinematicActive then
            if playerIsDead and self.current ~= "LoseMenu.xaml" and self.current ~= "MainMenu.xaml" then
                self.deathTimer = self.deathTimer + Time.GetRealDeltaTime()
                Engine.Log("[MenuManager] Death timer: " .. tostring(self.deathTimer))
                if self.deathTimer >= DEATH_MENU_DELAY then
                    self.deathTimer = 0.0
                    self.history = {}
                    NavigateTo(self, "LoseMenu.xaml")
                end
            else
                if not playerIsDead then self.deathTimer = 0.0 end
            end

            if Input.GetKeyDown("Escape") or Input.GetGamepadButtonDown("Start") then
                Engine.Log("[MenuManager] Input detected! Current XAML: '" .. tostring(self.current) .. "'")
                local isHUD   = (self.current == "HUD.xaml")       or self.current:find("HUD.xaml")
                local isPause = (self.current == "PauseMenu.xaml") or self.current:find("PauseMenu.xaml")

                if _G.TitleTrigger_HUDShouldStartHidden and isHUD then
                    return
                end
                if isHUD then
                    Engine.Log("[MenuManager] Logic: Open PauseMenu")
                    if _G.SuspendDialog then _G.SuspendDialog() end
                    NavigateTo(self, "PauseMenu.xaml")
                    Game.Pause()
                    ApplyLowerVolume(self)
                elseif isPause then
                    Engine.Log("[MenuManager] Logic: Resume to HUD")
                    NavigateTo(self, "HUD.xaml")
                    ApplyFullVolume(self)
                else
                    Engine.Log("[MenuManager] Logic: No HUD/Pause detected, ignoring Escape key.")
                end
            end
        end

        if UI.WasClicked("StartButton") then
            if not self.fading then
                Engine.Log("[MenuManager] StartButton clicked.")
                self.pendingScene = "Level1.scene"
                self.fading = true
                self.canvas:PlayStoryboard("FadeOut")
            end
        end
        if UI.WasClicked("SettingsButton") then NavigateTo(self, "SettingsMenu.xaml") end
        if UI.WasClicked("ExitButton") then
            if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
            Game.Exit()
        end
        if UI.WasClicked("ResumeButton")   then NavigateTo(self, "HUD.xaml") end
        if UI.WasClicked("TryAgainButton") then
            _G._PlayerController_isDead = false
            self.deathTimer = 0.0
            NavigateTo(self, "HUD.xaml")
        end
        if UI.WasClicked("BackToMenuButton") then
            if not self.fading then
                Engine.Log("[MenuManager] BackToMenuButton.")
                _G._PlayerController_isDead = false
                self.deathTimer = 0.0
                if _G.PlayerInstance then
                    _G.PlayerInstance.public.health  = 100
                    _G.PlayerInstance.public.stamina = 100
                end
                _G.SkipSplash     = true
                self.pendingScene = "Splash.scene"
                self.fading       = true
                self.canvas:PlayStoryboard("FadeOut")
            end
        end
        if UI.WasClicked("SoundButton")    then NavigateTo(self, "SoundsMenu.xaml")   end
        if UI.WasClicked("GraphicsButton") then NavigateTo(self, "GraphicsMenu.xaml") end

        local allCanvasButtons = UI.GetCanvasButtons()
        for i, button in ipairs(allCanvasButtons) do
            if UI.WasFocused(tostring(button)) then
                if self.selectSFX then self.selectSFX:SelectPlayAudioEvent("UI_ButtonSelect") end
            end
            if UI.WasClicked(tostring(button)) then
                if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
            end
        end

        local isEscapeHandled = (self.current == "HUD.xaml" or self.current == "PauseMenu.xaml")
        local canGoBack = self.history and #self.history > 0
            and self.current ~= "MainMenu.xaml"
            and self.current ~= "LoseMenu.xaml"
        if canGoBack and (
            UI.WasClicked("BackButton") or
            (Input.GetGamepadButtonDown("East") and self.current ~= "HUD.xaml") or
            (Input.GetKeyDown("Escape") and not isEscapeHandled)
        ) then
            NavigateBack(self)
        end

        if self.fading then
            self.fading = false
            SetPhase(self, "fadeOut")
        end

    elseif self.phase == "fadeOut" then
        local duration = self.pendingScene and SCENE_FADE_DURATION or FADE_DURATION
        local t = math.min(self.fadeTimer / duration, 1.0)

        if not self.pendingScene then
            self.canvas:SetOpacity(1.0 - EaseInOutQuad(t))
        else
            Audio.SetMusicVolume(_G.SavedMusicVolume * (1.0 - EaseInOutQuad(t)))
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

        if self.nextXaml == "PauseMenu.xaml"  or self.nextXaml == "GraphicsMenu.xaml"
        or self.nextXaml == "LoseMenu.xaml"   or self.nextXaml == "SettingsMenu.xaml"
        or self.nextXaml == "SoundsMenu.xaml" then
            ApplyLowerVolume(self)
        elseif self.nextXaml == "MainMenu.xaml" or self.nextXaml == "HUD.xaml" then
            ApplyFullVolume(self)
        end

        local previous = self.current
        self.canvas:LoadXAML(self.nextXaml)
        self.current   = self.nextXaml
        _G.CurrentXAML = self.current

        if self.current == "PauseMenu.xaml" and _G.HUD_RefreshStatuesDestroyed then
            _G.HUD_RefreshStatuesDestroyed()
        end
        self.lastPauseState = nil

        if self.current == "HUD.xaml" then
            if self.public.currentScene == "Level1.scene" then
                Audio.SetMusicState("Level1")
            elseif self.public.currentScene == "Blockout2Nuevo.scene"
                or self.public.currentScene == "Level2.scene" then
                if Audio.GetMusicState() ~= "Boss" or Audio.GetMusicState() ~= "AfterBoss" then
                    Audio.SetMusicState("Level2")
                end
            end
            if previous == "PauseMenu.xaml" then
                Game.Resume()
                self.lastPauseState    = "running"
                if _G.ForceRefreshHUD then
                    _G.ForceRefreshHUD()
                end
            else
                if _G.ResetPlayer and _G.PlayerInstance then
                    _G.ResetPlayer(_G.PlayerInstance)
                else
                    _G._PlayerController_isDead = false
                end
                Game.Resume()
                self.lastPauseState    = "running"
                if _G.ForceRefreshHUD then
                    _G.ForceRefreshHUD()
                end
            end
        elseif self.current:find("MainMenu.xaml") then
            Audio.SetMusicState("MainMenu")
            self.history        = {}
            Game.Resume()
            self.lastPauseState = "running"
        end

        Engine.Log("[MenuManager] Swapped to: " .. self.nextXaml .. ". TitleTrigger_HUDShouldStartHidden: " .. tostring(_G.TitleTrigger_HUDShouldStartHidden))
        if _G.TitleTrigger_HUDShouldStartHidden and self.nextXaml == "HUD.xaml" then
            self.canvas:SetOpacity(0.0)
            SetPhase(self, "idle")
        else
            self.canvas:SetOpacity(0.0)
            SetPhase(self, "fadeIn")
        end

    elseif self.phase == "fadeIn" then
        local t = math.min(self.fadeTimer / FADE_IN_DURATION, 1.0)
        self.canvas:SetOpacity(EaseInOutQuad(t))

        Audio.SetSFXVolume(_G.SavedSoundEffectsVolume * t)
        Audio.SetMusicVolume(_G.SavedMusicVolume * t)

        if t >= 1.0 then
            self.canvas:SetOpacity(1.0)
            ApplyFullVolume(self)
            SetPhase(self, "idle")
            Engine.Log("[MenuManager] Fade IN completado.")
        end

    elseif self.phase == "loadingScreenAnimating" then
        if self.pendingScene then
            if not self.loadingXAMLStarted then
                Engine.Log("[MenuManager] Mostrando LoadingScreen...")
                if self.canvas then self.canvas:LoadXAML("LoadingScreen.xaml") end
                self.loadingXAMLStarted = true
            end
            self.loadingScreenTimer = self.loadingScreenTimer + dt
            if self.loadingScreenTimer < MIN_LOADING_SCREEN_DURATION then return end
            Engine.Log("[MenuManager] Cargando escena: " .. self.pendingScene)
            self.loadingXAMLStarted = false
            Engine.LoadScene(self.pendingScene)
            self.pendingScene = nil
            return
        end
        SetPhase(self, "idle")
    end
end