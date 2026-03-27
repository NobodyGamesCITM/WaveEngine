local NEXT_XAML     = "HUD.xaml"
local FADE_DURATION = 0.4

local assetsPath = Engine.GetAssetsPath()

public = {
    updateWhenPaused = true
}

local canvas    = nil
local fading    = false
local fadeTimer = 0.0
local phase     = "idle"
local history   = {}
local current   = nil



local function EaseInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - (-2 * t + 2) ^ 2 / 2
    end
end

local function SetPhase(newPhase)
    phase     = newPhase
    fadeTimer = 0.0
    Engine.Log("[Transition] Phase: " .. newPhase)
end

local function NavigateTo(xaml)
    table.insert(history, current)
    NEXT_XAML = xaml
    fading    = true
    Engine.Log("[Transition] Navegando a: " .. xaml .. " (historial: " .. #history .. ")")
end

local function NavigateBack()
    if #history == 0 then
        Engine.Log("[Transition] No hay historial para volver")
        return
    end
    NEXT_XAML = table.remove(history)
    fading    = true
    Engine.Log("[Transition] Volviendo a: " .. NEXT_XAML)
end

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")

    if not canvas then
        Engine.Log("[Transition] ERROR: No tiene ComponentCanvas")
        return
    end

    current = canvas:GetCurrentXAML()
	
    Engine.Log("[Transition] current detectado: '" .. tostring(current) .. "'")

    if not current or current == "" then
        current = "MainMenu.xaml"
        Engine.Log("[Transition] WARN: Canvas sin XAML, usando fallback HUD")
    end
    Engine.Log("[Transition] XAML inicial: " .. current)

    if current ~= "HUD.xaml" then
        --Game.Pause()
    end

    canvas:SetOpacity(1.0)
    SetPhase("idle")

	NavigateTo("MainMenu.xaml")
	Game:Resume()
    Engine.Log("[Transition] Listo")


end

function Update(self, dt)
    if not canvas then return end

    if phase ~= "idle" then
        fadeTimer = fadeTimer + dt
    end

    if phase == "fadeIn" then
        local t     = math.min(fadeTimer / FADE_DURATION, 1.0)
        local alpha = EaseInOutQuad(t)
        canvas:SetOpacity(alpha)

        if t >= 1.0 then
            canvas:SetOpacity(1.0)
            SetPhase("idle")
        end
        return
    end

    if phase == "idle" then
        -- Buscar el player y comprobar si está muerto
        local isDead = false
        if _G.PlayerInstance then
            isDead = (_G.PlayerInstance.public.health <= 0)
        else
            local playerObj = GameObject.Find("Player")
            if playerObj then
                _G.PlayerInstance = playerObj
                isDead = (_G.PlayerInstance.public.health <= 0)
            end
        end

        -- Solo mostrar LoseMenu si estamos en el HUD, no desde el MainMenu
        if isDead and current ~= "LoseMenu.xaml" and current ~= "MainMenu.xaml" then
            history = {}
            NavigateTo("LoseMenu.xaml")
        end

        -- Pause toggle
        if current == "HUD.xaml" or current == "PauseMenu.xaml" then
            if Input.GetKeyDown("Escape") or Input.GetGamepadButtonDown("Start") then
                if current == "HUD.xaml" then
                    NavigateTo("PauseMenu.xaml")
                else
                    NavigateTo("HUD.xaml")
                end
            end
        end

        -- Main Menu
        if UI.WasClicked("StartButton") then
			
            NavigateTo("HUD.xaml")
        end
        if UI.WasClicked("SettingsButton") then
            NavigateTo("SettingsMenu.xaml")
        end
        if UI.WasClicked("ExitButton") then
            Game.Exit()
        end

        -- Pause Menu
        if UI.WasClicked("ResumeButton") then
            NavigateTo("HUD.xaml")
        end

        if UI.WasClicked("TryAgainButton") then
            _G._PlayerController_isDead = false
            NavigateTo("HUD.xaml")
        end

        -- BackToMenuButton: funciona tanto desde PauseMenu como desde LoseMenu
        if UI.WasClicked("BackToMenuButton") then
            _G._PlayerController_isDead = false
            -- Resetear la salud del player para que no vuelva al LoseMenu
            if _G.PlayerInstance then
                _G.PlayerInstance.public.health = 100
                _G.PlayerInstance.public.stamina = 100
            end
            NavigateTo("MainMenu.xaml")
        end

        -- Settings Menu
        if UI.WasClicked("SoundsButton") then
            NavigateTo("SoundsMenu.xaml")
        end
        if UI.WasClicked("GraphicsButton") then
            NavigateTo("GraphicsMenu.xaml")
        end

        -- Back (universal)
        local isEscapeHandled = (current == "HUD.xaml" or current == "PauseMenu.xaml")
        local canGoBack = #history > 0 and current ~= "MainMenu.xaml" and current ~= "LoseMenu.xaml"
        if canGoBack and (UI.WasClicked("BackButton") or (Input.GetGamepadButtonDown("East") and current ~= "HUD.xaml") or
           (Input.GetKeyDown("Escape") and not isEscapeHandled)) then
            NavigateBack()
        end

        if fading then
            fading = false
            SetPhase("fadeOut")
        end
    end

    if phase == "fadeOut" then
        local t     = math.min(fadeTimer / FADE_DURATION, 1.0)
        local alpha = 1.0 - EaseInOutQuad(t)
        canvas:SetOpacity(alpha)

        if t >= 1.0 then
            canvas:SetOpacity(0.0)
            SetPhase("swap")
        end

    elseif phase == "swap" then
        local previous = current
        canvas:LoadXAML(NEXT_XAML)
        current = NEXT_XAML

        if current == "HUD.xaml" then
            if previous == "PauseMenu.xaml" then
                -- Solo reanudar, sin recargar escena
                Game.Resume()
                Audio.SetMusicState("Level1")
            else
                if _G.ResetPlayer and _G.PlayerInstance then
                    _G.ResetPlayer(_G.PlayerInstance)
                    Engine.Log("[Transition] ResetPlayer global ejecutado")
                else
                    _G._PlayerController_isDead = false
                    Engine.Log("[Transition] WARN: ResetPlayer o PlayerInstance no encontrados")
                end
    
                Game.Resume()
                Audio.SetMusicState("Level1")
                
            end
        elseif
            current == "MainMenu.xaml" then
			Audio.SetMusicState("MainMenu")
			
        end

        Engine.Log("[Transition] Cargado: " .. NEXT_XAML)
        SetPhase("fadeIn")
    end
end

