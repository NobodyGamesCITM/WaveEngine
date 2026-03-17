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
local audioPlayed = false  


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
        current = "HUD.xaml"
        Engine.Log("[Transition] WARN: Canvas sin XAML, usando fallback HUD")
    end
    Engine.Log("[Transition] XAML inicial: " .. current)

    if current ~= "HUD.xaml" then
        --Game.Pause()
    end

    canvas:SetOpacity(1.0)
    SetPhase("idle")


    
    local menuAudio = self.gameObject:GetComponent("Audio Source")
    if not menuAudio then
        Engine.Log("[Menu Audio] WARN: Menu sin Audio Source, no habrá música de fondo")
    else
        
        menuAudio:PlayAudioEvent()
        --Audio.SetMusicState("MainMenu")
    end




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
            --Audio.SetMusicState("Level1")
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
        if UI.WasClicked("BackToMenuButton") then
            NavigateTo("MainMenu.xaml")
            --Audio.SetMusicState("MainMenu")
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
        local canGoBack = #history > 0 and current ~= "MainMenu.xaml"
        if canGoBack and (UI.WasClicked("BackButton") or Input.GetGamepadButtonDown("East") or
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
        canvas:LoadXAML(NEXT_XAML)
        current = NEXT_XAML

        if current == "HUD.xaml" then
            Game.Resume()
            Audio.SetMusicState("Level1")
			Engine.LoadScene(assetsPath, "../Scenes/Level1-audio.scene")
        else
            Game.Pause()
            Audio.SetMusicState("MainMenu")
        end

        Engine.Log("[Transition] Cargado: " .. NEXT_XAML)
        SetPhase("fadeIn")
        
    end



end



