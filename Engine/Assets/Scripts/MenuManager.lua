local NEXT_XAML     = "HUD.xaml"
local FADE_DURATION = 0.4

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
    if not current or current == "" then
        current = "MainMenu.xaml"
        Engine.Log("[Transition] WARN: Canvas sin XAML, usando fallback")
    end
    Engine.Log("[Transition] XAML inicial: " .. current)

    canvas:SetOpacity(1.0)
    SetPhase("idle")
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
        end
        if UI.WasClicked("SettingsButton") then
            NavigateTo("SettingsMenu.xaml")
        end
        if UI.WasClicked("ExitButton") then
            Engine.Log("[Transition] EXIT pulsado")
        end

        -- Pause Menu
        if UI.WasClicked("ResumeButton") then
            NavigateTo("HUD.xaml")
        end
        if UI.WasClicked("BackToMenuButton") then
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
        local canGoBack = #history > 0 and current ~= "MainMenu.xaml"
        if canGoBack and (UI.WasClicked("BackButton") or Input.GetGamepadButtonDown("East") or 
           (Input.GetKeyDown("Escape") and not isEscapeHandled)) then
            NavigateBack()
        end
        
        if fading then
            fading  = false
            current = NEXT_XAML
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
        Engine.Log("[Transition] Cargado: " .. NEXT_XAML)
        SetPhase("fadeIn")
    end
end