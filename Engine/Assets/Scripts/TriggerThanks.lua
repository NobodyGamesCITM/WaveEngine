local triggered = false
local fadeIn = false
local fadeTimer = 0.0
local FADE_DURATION = 1.5
local canExit = false

local canvas = nil

public = {
    updateWhenPaused = true
}

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")
    if canvas then
        canvas:LoadXAML("ThanksForPlayingScreen.xaml")
        canvas:SetOpacity(0.0)
        Engine.Log("[TriggerThanks] Canvas listo con opacidad 0.")
    else
        Engine.Log("[TriggerThanks] ERROR: No se encontró Canvas en el GameObject.")
    end
end

function OnTriggerEnter(self, other)
    if triggered then return end
    if other.name ~= "Player" and not other:CompareTag("Player") then return end

    triggered = true
    fadeIn = true
    fadeTimer = 0.0
    Game.Pause()
    Engine.Log("[TriggerThanks] Player detectado. Iniciando fade in de ThanksForPlayingScreen.")
end

function Update(self, dt)
    if not triggered then return end
    if not canvas then return end

    if fadeIn then
        fadeTimer = fadeTimer + dt
        local t = math.min(fadeTimer / FADE_DURATION, 1.0)
        local alpha = t * t  -- EaseIn suave

        canvas:SetOpacity(alpha)

        if t >= 1.0 then
            canvas:SetOpacity(1.0)
            fadeIn = false
            canExit = true
            Engine.Log("[TriggerThanks] Fade in completado. Esperando input para volver al menú.")
        end
    end

    if canExit then
        -- Detectar Enter, Espacio o Botón A (X en PS4)
        if Input.GetKeyDown("Enter") or Input.GetKeyDown("Space") or Input.GetGamepadButtonDown("A") then
            canExit = false
            _G.SkipSplash = true -- Saltamos los logos al volver
            Engine.Log("[TriggerThanks] Volviendo a Splash.scene...")
            
            if _G.TransitionToScene then
                _G.TransitionToScene("Splash.scene")
            else
                Engine.LoadScene(Engine.GetScenesPath(), "Splash.scene")
            end
        end
    end
end