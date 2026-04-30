
local State = {
    FADE_OUT = 0,
    IDLE     = 1,
    FADE_IN  = 2,
    DONE     = 3
}

local currentState = State.FADE_OUT
local currentAlpha = 1.0
local canvasComponent = nil 
local musicFadeTimer = 0.0
local volume = 100.0

public = {
    targetScene = "Level_02",  
    fadeSpeed   = 1.0,
    musicFadeTime = 2.0,
    currentLevel = "Level_01",
    maxVolume = 100.0,
    fullIntro = false
}

function Start(self)
    if self.public.currentLevel == "Level_01" and self.public.fullIntro == true and self.gameObject.name == "SceneManager" then _G._PlayerController_introAnim = true end
    currentState = State.FADE_OUT
    currentAlpha = 1.0
    
    
    canvasComponent = self.gameObject:GetComponent("Canvas") 
    
    if not canvasComponent then
        Engine.Log("[SceneTransition] ERROR: No se encontró el componente Image en este objeto.")
    else
        -- Cargamos la pantalla de carga para que sea lo que se desvanece al entrar en la escena
        if canvasComponent:GetCurrentXAML() ~= "LoadingScreen.xaml" then
            canvasComponent:LoadXAML("LoadingScreen.xaml")
        end
        canvasComponent:SetOpacity(1.0)
        -- Registramos el estado global inmediatamente
        _G.CurrentXAML = "LoadingScreen.xaml"
    end

    self.StartTransition = StartTransition
end

function Update(self, dt)
    if not canvasComponent then return end


    if currentState == State.FADE_OUT then
        currentAlpha = currentAlpha - (self.public.fadeSpeed * dt)
        musicFadeTimer = musicFadeTimer + (self.public.musicFadeTime * dt)
		local progressPercent = math.min((musicFadeTimer/(self.public.musicFadeTime or 2.0)), 1.0)
		volume = (self.public.maxVolume or 100.0) * (progressPercent)
        
        
        if currentAlpha <= 0.0 and volume >= (self.public.maxVolume or 100.0) then
            volume = self.public.maxVolume or 100.0
            currentAlpha = 0.0
            musicFadeTimer = 0
            currentState = State.IDLE
        end
        SetMusicVolume(volume)
        SetCanvasAlpha(currentAlpha)

    elseif currentState == State.FADE_IN then
        currentAlpha = currentAlpha + (self.public.fadeSpeed * dt)
        musicFadeTimer = musicFadeTimer + (self.public.musicFadeTime * dt)
		local progressPercent = math.min((musicFadeTimer/(self.public.musicFadeTime or 2.0)), 1.0)
		volume = (self.public.maxVolume or 100.0) * (1 - progressPercent)
		
		
        
        if currentAlpha >= 1.0 and volume <= 0  then
            currentAlpha = 1.0
            volume = 0
            musicFadeTimer = 0
            currentState = State.DONE
            SetCanvasAlpha(currentAlpha)
            SetMusicVolume(volume)

            -- Opcional: Cargar la pantalla de carga si la transición se hace desde este script
            if canvasComponent then
                canvasComponent:LoadXAML("LoadingScreen.xaml")
            end

            if Engine.LoadScene then
                Engine.LoadScene(self.public.targetScene)
            end
        end
        
        SetCanvasAlpha(currentAlpha)
        SetMusicVolume(volume)
    end
end

function StartTransition(self, sceneName)

    if currentState == State.IDLE or currentState == State.FADE_OUT then
        Engine.Log("[SceneTransition] Transición iniciada por script hacia: " .. tostring(sceneName))
        
        if sceneName then
            self.public.targetScene = sceneName
        end
        
        currentState = State.FADE_IN
        
        if _G.PlayerInstance then
            _G.PlayerInstance.public.canMove = false
        end
    end
end

function SetCanvasAlpha(alpha)
    if canvasComponent then

        if canvasComponent.SetOpacity then
            canvasComponent:SetOpacity(alpha)
        end
    end
end

function SetMusicVolume(volume)
    if volume then 
		Audio.SetMusicVolume(volume)
	else
		Engine.Log("Could not set music volume!")
		
    end
end