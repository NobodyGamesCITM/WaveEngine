-- MainMenu.lua

local NEXT_XAML     = "HUD.xaml"
local FADE_DURATION = 1.2

local canvas    = nil
local fading    = false
local fadeTimer = 0.0

function Start(self)
    local go = GameObject.Find("MainMenuCanvas")
    if not go then
        Engine.Log("[MainMenu] ERROR: No se encontró 'MainMenuCanvas'")
        return
    end

    canvas = go:GetComponent("Canvas")
    if not canvas then
        Engine.Log("[MainMenu] ERROR: No tiene ComponentCanvas")
        return
    end

    canvas:SetOpacity(1.0)
    Engine.Log("[MainMenu] Listo")
end

function Update(self, dt)
    if not canvas then return end

    -- UI.WasClicked es la API correcta registrada en ScriptManager
    if not fading and UI.WasClicked("StartButton") then
        fading    = true
        fadeTimer = 0.0
        Engine.Log("[MainMenu] START pulsado")
    end

    if UI.WasClicked("SettingsButton") then
        canvas:LoadXAML("SettingsMenu.xaml")
        canvas:SetOpacity(1.0)
        Engine.Log("[MainMenu] Abriendo Settings")
    end

    if UI.WasClicked("ExitButton") then
        Engine.Log("[MainMenu] EXIT pulsado")
    end

    -- Fade out
    if fading then
        fadeTimer = fadeTimer + dt
        local alpha = 1.0 - (fadeTimer / FADE_DURATION)
        if alpha < 0.0 then alpha = 0.0 end
        canvas:SetOpacity(alpha)

        if fadeTimer >= FADE_DURATION then
            fading = false
            canvas:LoadXAML(NEXT_XAML)
            canvas:SetOpacity(1.0)
            Engine.Log("[MainMenu] Transición a " .. NEXT_XAML .. " completada")
        end
    end
end