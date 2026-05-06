local triggered = false
local fadeIn = false
local fadeTimer = 0.0
local FADE_DURATION = 1.5

local canvas = nil

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
    if not fadeIn then return end
    if not canvas then return end

    fadeTimer = fadeTimer + dt
    local t = math.min(fadeTimer / FADE_DURATION, 1.0)
    local alpha = t * t  -- EaseIn suave

    canvas:SetOpacity(alpha)

    if t >= 1.0 then
        canvas:SetOpacity(1.0)
        fadeIn = false
        Engine.Log("[TriggerThanks] Fade in completado.")
    end
end