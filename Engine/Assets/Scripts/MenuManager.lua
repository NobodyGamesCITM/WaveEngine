_G.PendingSaveDataApply = _G.PendingSaveDataApply or false
_G.IsLoadingSaveGame = _G.IsLoadingSaveGame or false
_G.LoadedSaveData = _G.LoadedSaveData or nil
_G.SaveManager = _G.SaveManager or {}
local SAVE_FILENAME = "savegame.json"

local function TableToString(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        if type(k) == "string" then result = result .. '["' .. k .. '"]='
        else result = result .. "[" .. tostring(k) .. "]=" end
        if type(v) == "table" then result = result .. TableToString(v) .. ","
        elseif type(v) == "string" then result = result .. "\"" .. v .. "\","
        elseif type(v) == "boolean" then result = result .. tostring(v) .. ","
        elseif type(v) == "number" then result = result .. tostring(v) .. ","
        else result = result .. "nil," end
    end
    if result:sub(-1) == "," then result = result:sub(1, -2) end
    return result .. "}"
end

local function StringToTable(str)
    local func, err = load("return " .. str)
    if func then
        local ok, res = pcall(func)
        if ok then return res else Engine.Log("[SaveManager] Error pcall: "..tostring(res)) end
    end
    return nil
end

function _G.SaveManager.SaveGame()
    if not Engine.SaveTextFile then return end
    Engine.Log("[SaveManager] Recopilando datos de la escena...")
    local player = GameObject.Find("Player")
    if not player or not _G.PlayerInstance then return end
    local pScript = _G.PlayerInstance.public
    local potScript = _G.PotionSystem.public
    local pPos = player.transform.position
    local pRot = player.transform.rotation
    local saveData = {
        scene = _G.CurrentLevel or "Level1",
        player = {
            x = pPos.x, y = pPos.y, z = pPos.z, rotY = pRot.y,
            hp = pScript.health or 100, stamina = pScript.stamina or 100,
            potions = potScript.potionCount or 0, maxPotions = potScript.maxPotions or 0,
            berserk = potScript.berserkCount or 0, maxBerserk = potScript.maxBerserk or 0,
            maskApolo = _G._MaskState_Apolo or false, maskHermes = _G._MaskState_Hermes or false,
            maskAres = _G._MaskState_Ares or false, activeMask = _G._PlayerController_currentMask or ""
        },
        world = {
            keysCollected = _G.keysCollected or 0,
            portalState = _G.PortalState or 0,
            dialogs = _G.DialogsShown or {},
            combats = _G.CombatStates or {}
        },
        enemies = {}, doors = {}
    }
    local enemyTags = {"Enemy", "Enemy_Combat_1", "Enemy_Combat_Ares"}
    for _, tag in ipairs(enemyTags) do
        local enemies = GameObject.FindByTag(tag)
        if enemies then
            for _, enemy in ipairs(enemies) do
                local eName = enemy.name
                if eName then
                    local script = enemy:GetComponent("Script")
                    if script and not (script.public and script.public.excludeFromSave) then
                        if not saveData.enemies[eName] then saveData.enemies[eName] = {} end
                        local isDead = false
                        if script.CheckAlive then isDead = script:CheckAlive()
                        elseif script.isDead ~= nil then isDead = script.isDead
                        elseif script.hp ~= nil then isDead = (script.hp <= 0) end
                        local currentHp = 0
                        if script.GetHP then currentHp = script:GetHP()
                        elseif script.hp ~= nil then currentHp = script.hp end
                        local ePos = enemy.transform.position
                        local eRot = enemy.transform.rotation
                        table.insert(saveData.enemies[eName], { dead = isDead, hp = currentHp, x = ePos.x, y = ePos.y, z = ePos.z, rotY = eRot.y })
                    end
                end
            end
        end
    end
    local doorTags = {"Door", "Door_Combat_1", "Door_Combat_Ares"}
    for _, tag in ipairs(doorTags) do
        local doors = GameObject.FindByTag(tag)
        if doors then
            for _, door in ipairs(doors) do
                local dName = door.name
                if dName then
                    if not saveData.doors[dName] then saveData.doors[dName] = {} end
                    local script = door:GetComponent("Script")
                    local state = false
                    if script then
                        if script.isOpen ~= nil then state = script.isOpen
                        elseif script.isClose ~= nil then state = not script.isClose end
                    end
                    table.insert(saveData.doors[dName], { open = state })
                end
            end
        end
    end
    local jsonString = TableToString(saveData)
    if Engine.SaveTextFile(SAVE_FILENAME, jsonString) then Engine.Log("[SaveManager] Partida guardada con exito.") end
end

function _G.SaveManager.LoadGameData()
    if not Engine.LoadTextFile then return false end
    local jsonString = Engine.LoadTextFile(SAVE_FILENAME)
    if not jsonString then return false end
    _G.LoadedSaveData = StringToTable(jsonString)
    return _G.LoadedSaveData ~= nil
end

function _G.SaveManager.ApplyLoadedData(playerObj)
    if not _G.LoadedSaveData then return end
    Engine.Log("[SaveManager] Aplicando datos a la escena...")
    local data = _G.LoadedSaveData
    local player = playerObj
    if player and player.transform then
        player.transform:SetPosition(data.player.x, data.player.y, data.player.z)
        player.transform:SetRotation(0, data.player.rotY, 0)
        local rb = player:GetComponent("Rigidbody")
        if rb then rb:SetLinearVelocity(0,0,0) end
        _G.lastCheckpoint = { x = data.player.x, y = data.player.y, z = data.player.z }
        if _G.PlayerInstance then
            _G.PlayerInstance.public.health = data.player.hp
            _G.PlayerInstance.public.stamina = data.player.stamina
        end
        if _G.PotionSystem then
            _G.PotionSystem.public.potionCount = data.player.potions
            _G.PotionSystem.public.maxPotions = data.player.maxPotions
            _G.PotionSystem.public.berserkCount = data.player.berserk
            _G.PotionSystem.public.maxBerserk = data.player.maxBerserk
        end
        _G._MaskState_Apolo = data.player.maskApolo
        _G._MaskState_Hermes = data.player.maskHermes
        _G._MaskState_Ares = data.player.maskAres
        _G._UnlockedMasks = _G._UnlockedMasks or {}
        _G._UnlockedMasks.Apollo = data.player.maskApolo
        _G._UnlockedMasks.Hermes = data.player.maskHermes
        _G._UnlockedMasks.Ares = data.player.maskAres
        _G._PlayerController_currentMask = data.player.activeMask
        _G.keysCollected = data.world.keysCollected or 0
        _G.PortalState = data.world.portalState or 0
        _G.DialogsShown = data.world.dialogs or {}
        _G.CombatStates = data.world.combats or {}
        _G._PlayerController_introAnim = false
        _G.ForcePortalUpdate = true
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
    end
    local enemyCounters = {}
    local enemyTags = {"Enemy", "Enemy_Combat_1", "Enemy_Combat_Ares"}
    for _, tag in ipairs(enemyTags) do
        local enemies = GameObject.FindByTag(tag)
        if enemies and data.enemies then
            for _, enemy in ipairs(enemies) do
                pcall(function()
                    local eName = enemy.name
                    if eName then
                        local script = enemy:GetComponent("Script")
                        if not script or (script.public and script.public.excludeFromSave) then return end
                        enemyCounters[eName] = (enemyCounters[eName] or 0) + 1
                        local eList = data.enemies[eName]
                        if eList and enemyCounters[eName] <= #eList then
                            local eData = eList[enemyCounters[eName]]
                            if eData.hp <= 0 then eData.dead = true end
                            if eData.dead then
                                if enemy.transform then enemy.transform:SetPosition(0, -1000, 0) end
                                if script then
                                    if script.SetHP then script:SetHP(0) else script.hp = 0 end
                                    script.isDead = true
                                    if script.SetDead then script:SetDead() end
                                end
                                if enemy.SetActive then enemy:SetActive(false) end
                            else
                                if enemy.transform then
                                    enemy.transform:SetPosition(eData.x, eData.y, eData.z)
                                    enemy.transform:SetRotation(0, eData.rotY, 0)
                                end
                                local rb = enemy:GetComponent("Rigidbody")
                                if rb then rb:SetLinearVelocity(0,0,0) end
                                if script then
                                    if script.SetHP then script:SetHP(eData.hp) else script.hp = eData.hp end
                                    if script.SetAlive then script:SetAlive() end
                                end
                                if enemy.SetActive then enemy:SetActive(true) end
                            end
                        end
                    end
                end)
            end
        end
    end
    local doorCounters = {}
    local doorTags = {"Door", "Door_Combat_1", "Door_Combat_Ares"}
    for _, tag in ipairs(doorTags) do
        local doors = GameObject.FindByTag(tag)
        if doors and data.doors then
            for _, door in ipairs(doors) do
                pcall(function()
                    local dName = door.name
                    if dName then
                        doorCounters[dName] = (doorCounters[dName] or 0) + 1
                        local dList = data.doors[dName]
                        if dList and doorCounters[dName] <= #dList then
                            local dData = dList[doorCounters[dName]]
                            local script = door:GetComponent("Script")
                            if script then
                                if dData.open then
                                    if script.ForceOpen then script:ForceOpen() end
                                else
                                    if script.ForceClose then script:ForceClose() end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
    _G.LoadedSaveData = nil
    Engine.Log("[SaveManager] Datos aplicados correctamente.")
end

local NEXT_XAML_DEFAULT       = "HUD.xaml"
local MIN_LOADING_SCREEN_DURATION = 2.5
local FADE_DURATION           = 0.5
local SCENE_FADE_DURATION     = 2.0
local FADE_IN_DURATION        = 0.4

Engine.Log("[MenuManager] LUA FILE LOADED / CHUNK EXECUTED")

local assetsPath = Engine.GetAssetsPath()
local scenesPath = Engine.GetScenesPath()

if not _G.SavedSoundEffectsVolume then _G.SavedSoundEffectsVolume = 80.0 end
if not _G.SavedMusicVolume        then _G.SavedMusicVolume        = 80.0 end

public = {
    updateWhenPaused = true,
    currentScene    = { type = "Scene", value = "" },
    fullVolume  = 100.0,
    lowerVolume = 60.0
}

local DEATH_MENU_DELAY          = 6.2
local DROWNING_DEATH_MENU_DELAY = 2.0
local triedAgain = false

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
    if t < 0.5 then return 2 * t * t
    else return 1 - (-2 * t + 2) ^ 2 / 2 end
end

local function SetPhase(self, newPhase)
    self.phase     = newPhase
    self.fadeTimer = 0.0
    Engine.Log("[MenuManager] Phase: " .. newPhase)
end

local function NavigateTo(self, xaml)
    if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_CloseWindow") end
    if not self.history then self.history = {} end
    if self.current and not self.current:find("SplashScreen.xaml") then
        table.insert(self.history, self.current)
    end
    self.nextXaml = xaml
    SetPhase(self, "fadeOut")
    Engine.Log("[MenuManager] Navigating to: " .. xaml)
end

local function NavigateBack(self)
    if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_CloseWindow") end
    if not self.history or #self.history == 0 then return end
    self.nextXaml = table.remove(self.history)
    SetPhase(self, "fadeOut")
    Engine.Log("[MenuManager] Returning back to: " .. self.nextXaml)
end

local function InitAudioSources(self)
    self.musicSource = GameObject.Find("MusicSource")
    if self.musicSource then self.musicComp = self.musicSource:GetComponent("Audio Source") end
    self.selectSource = GameObject.Find("UISelectSound")
    if self.selectSource then self.selectSFX = self.selectSource:GetComponent("Audio Source") end
    self.pressSource = GameObject.Find("UIPressSound")
    if self.pressSource then self.pressSFX = self.pressSource:GetComponent("Audio Source") end
end

function Initialize(self)
    if not self.public then
        self.public = { updateWhenPaused = true, currentScene = { type = "Scene", value = "" }, fullVolume = 100.0, lowerVolume = 60.0 }
    end

    _G.CinematicActive = false
    Engine.Log("[MenuManager] Re-initializing on: " .. (self.gameObject and self.gameObject.name or "Unknown"))

    self.canvas = self.gameObject:GetComponent("Canvas")
    if not self.canvas then
        Engine.Log("[MenuManager] ERROR: No ComponentCanvas found during initialization")
        return false
    end

    self.phase     = self.phase or "idle"
    self.fadeTimer = self.fadeTimer or 0.0
    self.current   = self.current or ""
    self.history   = self.history or {}
    self.deathTimer = self.deathTimer or 0.0

    self.fading                = false
    self.pendingScene          = nil
    self.loggedReady           = false
    self.lastPauseState        = nil
    self.waitingForSplash      = false
    self.loadingScreenTimer    = 0.0
    self.loadingXAMLStarted    = false
    self.pendingHUDRefresh     = false
    self.soundsMenuInitialized = false
    self.pendingMainMenuIntro  = false

    _G.GlobalMenuManagerInstance = self
    self.NavigateTo = NavigateTo

    InitAudioSources(self)
    ApplyFullVolume(self)

    if _G.IsLoadingSaveGame then
        self.current = "HUD.xaml"
        _G.CurrentXAML = "HUD.xaml"
        self.canvas:LoadXAML("HUD.xaml")
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
        Game.Resume()
        self.lastPauseState = "running"
        Engine.Log("[MenuManager] Forzando HUD por carga de partida.")
        self.loggedReady = true
        return true
    end

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

        if path:find("MainMenu.xaml") then
            if _G.MainMenuNeedsIntro then
                -- FIX: venim de BackToMenu via SceneChanger.
                -- Canvas ocult, esperem IDLE del SceneChanger, llavors fadeIn + Intro.
                _G.MainMenuNeedsIntro = nil
                self.pendingMainMenuIntro = true
                self.canvas:SetOpacity(0.0)
                Game.Resume()
                self.lastPauseState = "running"
                self.history = {}
                SetPhase(self, "waitForSceneChanger")
                Engine.Log("[MenuManager] Esperant SceneChanger IDLE per fer fadeIn + Intro.")
            else
                -- Inici normal des del splash: el XAML ja dispara la seva Intro via Loaded trigger
                self.canvas:SetOpacity(1.0)
                Game.Resume()
                self.lastPauseState = "running"
                self.history = {}
                SetPhase(self, "idle")
            end
        elseif path:find("Splash.scene") then
            self.canvas:SetOpacity(0.0)
            self.fading = true
            Game.Resume()
            self.lastPauseState = "running"
            self.history = {}
            SetPhase(self, "fadeIn")
        else
            self.canvas:SetOpacity(0.0)
            self.fading = true
            Game.Pause()
            self.lastPauseState = "paused"
            SetPhase(self, "fadeIn")
        end

        Engine.Log("[MenuManager] Re-initialization COMPLETE (forced XAML).")
        return true
    end

    local sceneVal = _G.CurrentLevel or ""
    if sceneVal == "" then
        if type(self.public.currentScene) == "table" then sceneVal = self.public.currentScene.value or ""
        elseif type(self.public.currentScene) == "string" then sceneVal = self.public.currentScene end
    end

    local isGameplayScene = (sceneVal:find("Level1") ~= nil or sceneVal:find("Level2") ~= nil)

    local function isTransientXAML(x)
        return not x or x == "" or x:find("LoadingScreen.xaml") ~= nil or x:find("FadePanel.xaml") ~= nil
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
        self.history = {}
        self.lastPauseState = "running"
    elseif isGameplayScene then
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
    self.loggedReady = true
    return true
end

function Start(self)
    if not self.gameObject:GetComponent("Canvas") then
        Engine.Log("[MenuManager] ERROR: No Canvas in Start, aborting.")
        return
    end
    if _G._NewSceneLoaded then
        self.newSceneDelay = 0.8
        self.sceneLoadedFlag = true
    else
        Initialize(self)
    end
end

function Update(self, dt)
    local playerHealth = 101
    local playerIsDrowning = false
    if _G.PlayerInstance and _G.PlayerInstance.public then
        playerHealth = _G.PlayerInstance.public.health
        playerIsDrowning = _G._PlayerController_drownDeath or false
    else
        local playerObj = GameObject.Find("Player")
        if playerObj then
            local pScript = GameObject.GetScript(playerObj)
            if pScript then
                _G.PlayerInstance = pScript
                playerHealth = pScript.public and pScript.public.health or 101
                playerIsDrowning = _G._PlayerController_drownDeath or false
            end
        end
    end

    local playerIsDead = (playerHealth <= 0)

    if self.newSceneDelay and self.newSceneDelay > 0 then
        self.newSceneDelay = self.newSceneDelay - Time.GetRealDeltaTime()
        if self.newSceneDelay <= 0 then
            self.newSceneDelay = nil
            Initialize(self)
        end
        return
    end

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
        if type(self.public.currentScene) == "table" then sceneVal = self.public.currentScene.value or ""
        elseif type(self.public.currentScene) == "string" then sceneVal = self.public.currentScene end
        local musicState = "None"
        if sceneVal:find("Level1") or sceneVal == "Level1.scene" then
            musicState = _G.CinematicActive and "Vignettes" or "Level1"
        elseif sceneVal:find("Level2") or sceneVal == "Level2.scene" then
            musicState = "Level2"
        elseif sceneVal == "Splash.scene" and _G.SkipSplash then
            musicState = "MainMenu"
        else
            Engine.Log("[Menu Manager] Current Scene = " .. tostring(sceneVal))
        end
        Audio.SetMusicState(tostring(musicState))
        if self.musicComp then
            self.musicComp:SelectPlayAudioEvent("MUS_BGM")
            Engine.Log("Started playing BGM from MenuManager Update")
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

    local isActualMenu = (self.current ~= nil and self.current ~= ""
        and not self.current:find("HUD.xaml")
        and not self.current:find("SonOfIthaca.xaml"))

    if isActualMenu then
        if self.current:find("MainMenu.xaml") then
            if self.lastPauseState ~= "running" then Game.Resume(); self.lastPauseState = "running" end
        else
            if self.lastPauseState ~= "paused" and self.public.currentScene ~= "Splash.scene" then
                Game.Pause(); self.lastPauseState = "paused"
            end
        end
    elseif not _G.DialogActive and not _G.CinematicActive then
        if self.lastPauseState ~= "running" then Game.Resume(); self.lastPauseState = "running" end
    end

    if _G._NewSceneLoaded and not self.sceneLoadedFlag then
        self.sceneLoadedFlag = true
        self.newSceneDelay = 0.8
        return
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
        if type(self.public.currentScene) == "table" then sv = self.public.currentScene.value or ""
        elseif type(self.public.currentScene) == "string" then sv = self.public.currentScene end
        self.current = (sv:find("Level1") or sv:find("Level2")) and "HUD.xaml" or "MainMenu.xaml"
        _G.CurrentXAML = self.current
        Engine.Log("[MenuManager] current era transitorio, corregido a: " .. self.current)
    end

    -- El fadeTimer no avança durant waitForSceneChanger ni idle
    if self.phase ~= "idle" and self.phase ~= "waitForSceneChanger" then
        self.fadeTimer = self.fadeTimer + Time.GetRealDeltaTime()
    end

    -- ─── WAIT FOR SCENE CHANGER ──────────────────────────────────────────────
    -- Esperem que el SceneChanger (FadePanel fade out) arribi a State.IDLE=1
    -- per assegurar-nos que la pantalla és completament negra abans del fadeIn.
    if self.phase == "waitForSceneChanger" then
        if _G.SceneManagerState == 1 then
            Engine.Log("[MenuManager] SceneChanger IDLE, iniciant fadeIn + Intro del MainMenu.")
            SetPhase(self, "fadeIn")
        end
        return

    -- ─── IDLE ────────────────────────────────────────────────────────────────
    elseif self.phase == "idle" then

        if self.current == "SoundsMenu.xaml" then
            if not self.soundsMenuInitialized then
                self.soundsMenuInitialized = true
                UI.SetSliderValue("SoundEffectsSlider", _G.SavedSoundEffectsVolume)
                UI.SetSliderValue("MusicSlider",        _G.SavedMusicVolume)
                Engine.Log("[MenuManager] SoundsMenu cargado: SFX=" .. tostring(_G.SavedSoundEffectsVolume) .. " Music=" .. tostring(_G.SavedMusicVolume))
            end
            if UI.SliderValueChanged("SoundEffectsSlider") then
                local val = UI.GetSliderValue("SoundEffectsSlider")
                _G.SavedSoundEffectsVolume = val
                Audio.SetSFXVolume(val)
                if self.pressSFX then
                    if not Audio.IsEventPlaying("UI_SliderTest") then self.pressSFX:SelectPlayAudioEvent("UI_SliderTest") end
                end
            end
            if UI.SliderValueChanged("MusicSlider") then
                local val = UI.GetSliderValue("MusicSlider")
                _G.SavedMusicVolume = val
                Audio.SetMusicVolume(val)
            end
        else
            if self.soundsMenuInitialized then self.soundsMenuInitialized = false end
        end

        if self.pendingHUDRefresh then
            self.pendingHUDRefresh = false
            if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
        end

        if not self.loggedReady then
            Engine.Log("[MenuManager] READY (Object: " .. self.gameObject.name .. ", XAML: " .. tostring(self.current) .. ")")
            self.loggedReady = true
        end

        if not self.deathTimer then self.deathTimer = 0.0 end
        if playerIsDead and self.current ~= "LoseMenu.xaml" and self.current ~= "MainMenu.xaml" then
            if not self.fading and not _G.TitleTrigger_Active then
                self.canvas:SetOpacity(1.0)
            end
            self.deathTimer = self.deathTimer + Time.GetRealDeltaTime()
            local currentDeathDelay = playerIsDrowning and DROWNING_DEATH_MENU_DELAY or DEATH_MENU_DELAY
            if self.deathTimer >= currentDeathDelay then
                self.deathTimer = 0.0
                self.history = {}
                NavigateTo(self, "LoseMenu.xaml")
            end
        elseif _G.CinematicActive then
            if self.canvas then self.canvas:SetOpacity(0.0) end
            self.deathTimer = 0.0
        else
            self.deathTimer = 0.0
            if not self.fading and self.canvas then
                local isGameplayHUD = (self.current == "HUD.xaml" or self.current == "SonOfIthaca.xaml")
                if not (isGameplayHUD and (_G.TitleTrigger_Active or _G.TitleTrigger_HUDShouldStartHidden)) then
                    self.canvas:SetOpacity(1.0)
                end
            end
        end

        if not _G.CinematicActive and not playerIsDead then
            if Input.GetKeyDown("Escape") or Input.GetGamepadButtonDown("Start") then
                Engine.Log("[MenuManager] Input detected! Current XAML: '" .. tostring(self.current) .. "'")
                local isHUD   = (self.current == "HUD.xaml") or self.current:find("HUD.xaml") or self.current:find("SonOfIthaca.xaml")
                local isPause = (self.current == "PauseMenu.xaml") or self.current:find("PauseMenu.xaml")
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
                _G.PendingSaveDataApply = false
                _G.IsLoadingSaveGame = false
                _G.LoadedFromSave = false
                _G.ForceStartXAML = nil
                _G.CurrentXAML = "HUD.xaml"
                _G.CurrentLevel = "Level1"
                _G.DialogsShown = {}
                _G.CombatStates = {}
                
                _G.PortalState        = 0
                _G._MidRunTransition  = false
                _G._UnlockedMasks     = {}
                _G._MaskState_Apolo   = false
                _G._MaskState_Hermes  = false
                _G._MaskState_Ares    = false
                _G._SavedCurrentMask  = nil
                _G.keysCollected      = 0
                
                self.pendingScene = "Level1.scene"
                self.fading = true
                self.canvas:PlayStoryboard("FadeOut")
            end
        end

        if UI.WasClicked("ContinueButton") then
            if not self.fading then
                if _G.SaveManager and _G.SaveManager.LoadGameData() then
                    Engine.Log("[MenuManager] ContinueButton clicked. LOAD GAME.")
                    _G.PendingSaveDataApply = true
                    _G.IsLoadingSaveGame = true
                    _G.LoadedFromSave = true
                    local sName = _G.LoadedSaveData.scene
                    if sName == "Level_01" then sName = "Level1" end
                    if sName == "Level_02" then sName = "Level2" end
                    if sName:find(".scene") == nil then sName = sName .. ".scene" end
                    self.pendingScene = sName
                    _G.CurrentLevel = sName:gsub(".scene", "")
                    self.fading = true
                    self.canvas:PlayStoryboard("FadeOut")
                else
                    Engine.Log("[MenuManager] No hay partida guardada.")
                end
            end
        end

        if UI.WasClicked("SettingsButton") then NavigateTo(self, "SettingsMenu.xaml") end
        if UI.WasClicked("ExitButton") then
            if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
            Game.Exit()
        end
        if UI.WasClicked("ResumeButton") then NavigateTo(self, "HUD.xaml") end
        if UI.WasClicked("TryAgainButton") then
            _G._PlayerController_isDead = false
            triedAgain = true
            self.deathTimer = 0.0
            NavigateTo(self, "HUD.xaml")
        end

        if UI.WasClicked("BackToMenuButton") then
            if not self.fading then
                Engine.Log("[MenuManager] BackToMenuButton. Delegant al SceneChanger.")
                _G._PlayerController_isDead = false
                self.deathTimer = 0.0

                -- Preparar globals per a la nova escena
                _G.CurrentLevel   = "MainMenu"
                _G.ForceStartXAML = "MainMenu.xaml"
                _G.SkipSplash     = true
                -- El SceneChanger activara MainMenuNeedsIntro quan arribi a IDLE (fade out acabat)
                -- i el MenuManager de la nova escena fara el fadeIn + PlayStoryboard("Intro")

                -- Cridar StartTransition al SceneChanger perque gestioni el FadePanel + LoadingScreen
                local sceneManagerObj = GameObject.Find("SceneManager")
                if sceneManagerObj then
                    local sceneScript = sceneManagerObj:GetComponent("Script")
                    if sceneScript and sceneScript.StartTransition then
                        sceneScript:StartTransition("Splash.scene")
                        Engine.Log("[MenuManager] StartTransition('Splash.scene') cridat al SceneChanger.")
                    else
                        Engine.Log("[MenuManager] WARN: SceneChanger.StartTransition no disponible, transicio manual.")
                        _G.MainMenuNeedsIntro = true
                        self.pendingScene = "Splash.scene"
                        self.fading = true
                        self.canvas:PlayStoryboard("FadeOut")
                    end
                else
                    Engine.Log("[MenuManager] WARN: SceneManager no trobat, transicio manual.")
                    _G.MainMenuNeedsIntro = true
                    self.pendingScene = "Splash.scene"
                    self.fading = true
                    self.canvas:PlayStoryboard("FadeOut")
                end
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

    -- ─── FADE OUT ────────────────────────────────────────────────────────────
    elseif self.phase == "fadeOut" then
        local duration = self.pendingScene and SCENE_FADE_DURATION or FADE_DURATION
        local t = math.min(self.fadeTimer / duration, 1.0)

        if not self.pendingScene then
            local alpha = 1.0 - EaseInOutQuad(t)
            local isGameplayHUD = (self.current == "HUD.xaml" or self.current == "SonOfIthaca.xaml")
            if isGameplayHUD and (_G.TitleTrigger_Active or _G.TitleTrigger_HUDShouldStartHidden) then
                alpha = 0.0
            end
            self.canvas:SetOpacity(alpha)
        else
            Audio.SetMusicVolume(_G.SavedMusicVolume * (1.0 - EaseInOutQuad(t)))
            Audio.SetSFXVolume(_G.SavedSoundEffectsVolume * (1.0 - EaseInOutQuad(t)))
        end

        if t >= 1.0 then
            if not self.pendingScene then self.canvas:SetOpacity(0.0)
            else Audio.SetMusicVolume(0); Audio.SetSFXVolume(0) end
            SetPhase(self, "swap")
        end

    -- ─── SWAP ────────────────────────────────────────────────────────────────
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
        if self.nextXaml and self.nextXaml ~= "" then
            self.canvas:LoadXAML(self.nextXaml)
            self.current   = self.nextXaml
            _G.CurrentXAML = self.current
        end

        self.lastPauseState = nil

        if self.current == "HUD.xaml" then
            if self.public.currentScene == "Level1.scene" then
                Audio.SetMusicState("Level1")
            elseif self.public.currentScene == "Level2.scene" then
                if triedAgain then Audio.SetMusicState("Level2"); triedAgain = false end
            end
            if previous == "PauseMenu.xaml" then
                Game.Resume()
                self.lastPauseState = "running"
                if not _G.TitleTrigger_Active then
                    if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
                end
            else
                if not _G.IsLoadingSaveGame then
                    if _G.ResetPlayer and _G.PlayerInstance then _G.ResetPlayer(_G.PlayerInstance)
                    else _G._PlayerController_isDead = false end
                else
                    _G._PlayerController_isDead = false
                end
                Game.Resume()
                self.lastPauseState = "running"
                if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
            end
        elseif self.current:find("MainMenu.xaml") then
            Audio.SetMusicState("MainMenu")
            self.history = {}
            Game.Resume()
            self.lastPauseState = "running"
        end

        Engine.Log("[MenuManager] Swapped to: " .. tostring(self.nextXaml))

        local isGameplayHUD = (self.nextXaml == "HUD.xaml" or self.nextXaml == "SonOfIthaca.xaml")

        if self.nextXaml == "MainMenu.xaml" then
            self.canvas:SetOpacity(1.0)
            SetPhase(self, "idle")
        elseif isGameplayHUD and (_G.TitleTrigger_Active or _G.TitleTrigger_HUDShouldStartHidden) then
            self.canvas:SetOpacity(0.0)
            SetPhase(self, "idle")
        else
            self.canvas:SetOpacity(0.0)
            SetPhase(self, "fadeIn")
        end

    -- ─── FADE IN ─────────────────────────────────────────────────────────────
    elseif self.phase == "fadeIn" then
        local t = math.min(self.fadeTimer / FADE_IN_DURATION, 1.0)
        self.canvas:SetOpacity(EaseInOutQuad(t))
        Audio.SetSFXVolume(_G.SavedSoundEffectsVolume * t)
        Audio.SetMusicVolume(_G.SavedMusicVolume * t)

        if t >= 1.0 then
            self.canvas:SetOpacity(1.0)
            ApplyFullVolume(self)
            SetPhase(self, "idle")
            Engine.Log("[MenuManager] Fade IN completat.")
            -- FIX: canvas visible, disparar la Intro del MainMenu
            if self.pendingMainMenuIntro then
                self.pendingMainMenuIntro = false
                self.canvas:PlayStoryboard("Intro")
                Engine.Log("[MenuManager] Intro del MainMenu disparada post-fadeIn.")
            end
        end

    -- ─── LOADING SCREEN ANIMATING ────────────────────────────────────────────
    elseif self.phase == "loadingScreenAnimating" then
        if self.pendingScene then
            if not self.loadingXAMLStarted then
                if self.canvas then self.canvas:LoadXAML("LoadingScreen.xaml") end
                self.loadingXAMLStarted = true
            end
            self.loadingScreenTimer = self.loadingScreenTimer + dt
            if self.loadingScreenTimer < MIN_LOADING_SCREEN_DURATION then return end
            Engine.Log("[MenuManager] Cargando escena: " .. self.pendingScene)
            self.loadingXAMLStarted = false
            _G.CurrentLevel = self.pendingScene:gsub(".scene", "")
            Engine.LoadScene(self.pendingScene)
            self.pendingScene = nil
            return
        end
        SetPhase(self, "idle")
    end
end