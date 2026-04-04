--- SceneLoader_lvl2.lua
--- Trigger de cambio de escena con Fade Out y condición.

public = {
    targetScene    = { type = "Scene", value = "" },
    triggerKey     = "Space",
	--debugTriggerKey = "Space",
    conditionVar   = "",
    conditionValue = 1.0,
    fadeSpeed      = 2.0,
}

-- Constantes
local STATE_IDLE      =1 ; local STATE_WAIT_KEY  = 2
local STATE_FADE_OUT  =3 ; local STATE_LOADING   = 4

-- Variables propias de la instancia
local state        = STATE_IDLE
local fadeAlpha    = 0.0   
local playerInside = false
local musicVolume  = 100.0
local musicSource
local musicComp
local isMusicPlaying = false

-- Comprobar si se cumple la condición global de _G
local function IsConditionMet(self)
    local varName = self.public.conditionVar
    if varName == nil or varName == "" then return true end

    local required = self.public.conditionValue or 1.0
    local current  = _G[varName]

    if type(current) == "number" then return current >= required end
    if type(current) == "boolean" then return current == true end
    return false   
end

-- Funciones locales de colisión
local function MyOnTriggerEnter(self, other)
    if other and (other.tag == "Player" or other:CompareTag("Player")) then
        playerInside = true
        if state == STATE_IDLE then 
            state = STATE_WAIT_KEY 
            Engine.Log("[SceneLoader] Jugador en portal. Tecla: " .. (self.public.triggerKey or "Space"))
        end
    end
end

local function MyOnTriggerExit(self, other)
    if other and (other.tag == "Player" or other:CompareTag("Player")) then
        playerInside = false
        if state == STATE_WAIT_KEY then state = STATE_IDLE end
    end
end

function Start(self)
    state = STATE_IDLE ; fadeAlpha = 0.0 ; playerInside = false ; musicVolume = 100.0 ; musicPlaying = false

    Audio.SetGlobalVolume(musicVolume)
    --retrieve audio components
    musicSource = GameObject.Find("MusicSource")
	if not musicSource then 
		Engine.Log("Music GameObject not found, unable to play BGM track")
	else
		musicComp = musicSource:GetComponent("Audio Source")
		if not musicComp then
			Engine.Log("Music Audio Source not found or missing")
		end
	end
    
    -- Inyectamos las funciones en la instancia para que el motor las encuentre
    self.OnTriggerEnter = MyOnTriggerEnter
    self.OnTriggerExit = MyOnTriggerExit
    
    -- Ajuste inicial del panel de fade (UI)
    UI.SetElementHeight("FadePanel", 0)
    UI.SetElementVisibility("FadePanel", false)
end

function Update(self, dt)
    if state == STATE_IDLE then 
		--Debug scene change key
		--local debugKey = "2"
		if Input.GetKeyDown("2") then state = STATE_FADE_OUT end
	end

    if state == STATE_WAIT_KEY then
        if not playerInside then state = STATE_IDLE ; return end
        
        local key = self.public.triggerKey or "Space"
        if Input.GetKeyDown(key) then
            if IsConditionMet(self) then
                state = STATE_FADE_OUT
            else
                Engine.Log("[SceneLoader] Condición no cumplida todavía.")
            end
        end
        return
    end

	

    if state == STATE_FADE_OUT then
        
		musicVolume = musicVolume - (100.0 / self.public.fadeSpeed) * dt
		Audio.SetGlobalVolume(musicVolume)

        fadeAlpha = fadeAlpha + dt * (self.public.fadeSpeed)
        UI.SetElementHeight("FadePanel", fadeAlpha * 1080)
        UI.SetElementVisibility("FadePanel", true)

        if fadeAlpha >= 1.0 and musicVolume <= 0 then
            state = STATE_LOADING
            local sceneName = self.public.targetScene
            if type(sceneName) == "table" then sceneName = sceneName.value end
            Engine.LoadScene(Engine.GetScenesPath(), sceneName)
			
        end
    end

end






