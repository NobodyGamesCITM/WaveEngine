local NEXT_XAML_DEFAULT = "HUD.xaml"
local FADE_DURATION      = 0.4

Engine.Log("[MenuManager] LUA FILE LOADED / CHUNK EXECUTED")

local assetsPath = Engine.GetAssetsPath()
local scenesPath = Engine.GetScenesPath()

public = {
    updateWhenPaused = true,
	currentScene    = { type = "Scene", value = "" },
    fullVolume = 100.0,
    lowerVolume = 60.0
}

-- Instance-specific state will be stored in 'self'
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
    if self.pressSFX then self.pressSFX:PlayAudioEvent() end
    if not self.history then self.history = {} end
    table.insert(self.history, self.current)
    self.nextXaml = xaml
    self.fading   = true
    Engine.Log("[MenuManager] Navigating to: " .. xaml)
end

local function NavigateBack(self)
    if self.pressSFX then self.pressSFX:PlayAudioEvent() end
    if not self.history or #self.history == 0 then return end
    self.nextXaml = table.remove(self.history)
    self.fading   = true
    Engine.Log("[MenuManager] Returning back to: " .. self.nextXaml)
end

function Initialize(self)
    Engine.Log("[MenuManager] Re-initializing instance on object: " .. (self.gameObject and self.gameObject.name or "Unknown"))
    
    self.canvas = self.gameObject:GetComponent("Canvas")
    self.phase = "idle"
    self.fadeTimer = 0.0
    self.fading = false
    self.history = {}
    self.loggedReady = false
    
    _G.GlobalMenuManagerInstance = self

    self.isMusicPlaying = false
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

    self.current = self.canvas:GetCurrentXAML()
    if not self.current or self.current == "" then
        self.current = "MainMenu.xaml"
        self.nextXaml = "MainMenu.xaml"
        _G.CurrentXAML = "MainMenu.xaml"
    end

    if self.current == "MainMenu.xaml" then
        Audio.SetMusicState("MainMenu") 
    else
        if self.public.currentScene == "Level1.scene" then
            Audio.SetMusicState("Level1")
        elseif self.public.currentScene == "Blockout2.scene" then
            Audio.SetMusicState("Level2")                
        end
    end
    
    Engine.Log("[MenuManager] Current XAML: " .. self.current)
    self.canvas:SetOpacity(1.0)
    SetPhase(self, "idle")
    
    -- Force a small jump-start navigation if we are in HUD
    -- if self.current == "HUD.xaml" then
    --     self.nextXaml = "HUD.xaml"
    --     _G.CurrentXAML = "HUD.xaml"
    -- end

    Game.Resume()
    Engine.Log("[MenuManager] Re-initialization COMPLETE.")
    return true
end


function Start(self)
    Initialize(self)
end

function Update(self, dt)
    -- PERSISTENCE FIX: If scene changed or references lost, re-init
    if not self.canvas or _G._MenuManager_NeedReinit then
        _G._MenuManager_NeedReinit = false
        Initialize(self)
    end

    if self.current == "MainMenu.xaml" then
        Audio.SetMusicState("MainMenu")
        Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
        Game.Pause()
    end
    -- Detect scene change via common global if available
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

    if self.phase == "fadeIn" then
        local t     = math.min(self.fadeTimer / FADE_DURATION, 1.0)
        local alpha = EaseInOutQuad(t)
        self.canvas:SetOpacity(alpha)

        if t >= 1.0 then
            self.canvas:SetOpacity(1.0)
            SetPhase(self, "idle")
        end
        return
    end

    if self.phase == "idle" then
        -- DEBUG: Log once when entering idle
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

        -- Check for Escape with robust logging
        if Input.GetKeyDown("Escape") or Input.GetGamepadButtonDown("Start") then
            Engine.Log("[MenuManager] Input detected! Current XAML: '" .. tostring(self.current) .. "'")
            
            -- String matching can be tricky with paths, so we check for substring too
            local isHUD = (self.current == "HUD.xaml") or self.current:find("HUD.xaml")
            local isPause = (self.current == "PauseMenu.xaml") or self.current:find("PauseMenu.xaml")
            --local isMainMenu = (self.current == "MainMenu.xaml") or self.current:find("MainMenu.xaml")

      
 
            if isHUD then
                Engine.Log("[MenuManager] Logic: Open PauseMenu")
                if _G.SuspendDialog then _G.SuspendDialog() end
                Game.Pause()
                NavigateTo(self, "PauseMenu.xaml")
                Audio.SetGlobalVolume(self.public.lowerVolume or 60.0)

            elseif isPause then
                Engine.Log("[MenuManager] Logic: Resume to HUD")
                Game.Resume()
                NavigateTo(self, "HUD.xaml")
                Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
            else
                Engine.Log("[MenuManager] Logic: No HUD/Pause detected, ignoring Escape key.")
            end
        end

        local allCanvasButtons = UI.GetCanvasButtons()

        for i, button in ipairs(allCanvasButtons) do
            if UI.WasFocused(tostring(button)) then
                Engine.Log("[BUTTON AUDIO] "..tostring(button).. " was focused")
                if self.selectSFX then 
                    self.selectSFX:PlayAudioEvent() 
                    Engine.Log("[BUTTON AUDIO] selectSFX played")
                end
            end
        end


        -- if UI.WasFocused("StartButton") or UI.WasFocused("SettingsButton") or UI.WasFocused("ExitButton") 
        -- or UI.WasFocused("ResumButton") or UI.WasFocused("TryAgainButton") or UI.WasFocused("BackToMenuButton") then
        --     if self.selectSFX then self.selectSFX:PlayAudioEvent() end
        -- end
        
        if UI.WasClicked("StartButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "HUD.xaml")
        end
        if UI.WasClicked("SettingsButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "SettingsMenu.xaml")
        end
        if UI.WasClicked("ExitButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            Game.Exit()
        end

        if UI.WasClicked("ResumeButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "HUD.xaml")
        end

        if UI.WasClicked("TryAgainButton") then
            _G._PlayerController_isDead = false
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "HUD.xaml")
        end

        if UI.WasClicked("BackToMenuButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            _G._PlayerController_isDead = false
            if _G.PlayerInstance then
                _G.PlayerInstance.public.health = 100
                _G.PlayerInstance.public.stamina = 100
            end
            NavigateTo(self, "MainMenu.xaml")
            Game.Pause()
        end

        if UI.WasClicked("SoundsButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "SoundsMenu.xaml")
        end
        if UI.WasClicked("GraphicsButton") then
            --if self.pressSFX then self.pressSFX:PlayAudioEvent() end
            NavigateTo(self, "GraphicsMenu.xaml")
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
        local t     = math.min(self.fadeTimer / FADE_DURATION, 1.0)
        local alpha = 1.0 - EaseInOutQuad(t)
        self.canvas:SetOpacity(alpha)

        if t >= 1.0 then
            self.canvas:SetOpacity(0.0)
            SetPhase(self, "swap")
        end

    elseif self.phase == "swap" then
        if self.nextXaml == "PauseMenu.xaml" then
            if _G.SuspendDialog then _G.SuspendDialog() end
        elseif self.nextXaml == "HUD.xaml" and self.current == "PauseMenu.xaml" then
            if _G.ResumeDialog then _G.ResumeDialog() end
            
        else
            if _G.ForceCloseDialog then _G.ForceCloseDialog() end
        end


        if self.nextXaml == "PauseMenu.xaml" or self.nextXaml == "GraphicsMenu.xaml" or self.nextXaml == "LoseMenu.xaml" or  self.nextXaml == "SettingsMenu.xaml" then
            Audio.SetGlobalVolume(self.public.lowerVolume or 60.0)
        elseif self.nextXaml == "MainMenu.xaml" or self.nextXaml == "HUD.xaml" then
            Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
        end
            
       
        local previous = self.current
        self.canvas:LoadXAML(self.nextXaml)
        self.current = self.nextXaml
        _G.CurrentXAML = self.current

        if self.current == "HUD.xaml" then
            Engine.Log("[UI MENU] current scene: " .. tostring(self.public.currentScene.value))
            if self.public.currentScene == "Level1.scene" then
                Audio.SetMusicState("Level1")
            elseif self.public.currentScene == "Blockout2.scene" then
                Audio.SetMusicState("Level2")                
            end

            if previous == "PauseMenu.xaml" then
                Game.Resume()
                -- No SetMusicState here to avoid restarting track

            else
                if _G.ResetPlayer and _G.PlayerInstance then
                    _G.ResetPlayer(_G.PlayerInstance)
                else
                    _G._PlayerController_isDead = false
                end
                Game.Resume()
            end

        elseif self.current == "MainMenu.xaml" then
            Audio.SetMusicState("MainMenu")
            Audio.SetGlobalVolume(self.public.fullVolume or 100.0)
            Game.Pause()
        end
        -- if not self.isMusicPlaying and self.musicComp then
        --     self.musicComp:PlayAudioEvent()
        --     self.isMusicPlaying = true
        -- end

        Engine.Log("[MenuManager] Swapped to: " .. self.nextXaml)
        SetPhase(self, "fadeIn")
    end
end
