public = {
    nextXaml = { type = "String", value = "MainMenu.xaml" }, 
    totalDuration = 6.5, -- Duración de la animación del logo (Intro Storyboard)
    fadeSpeed = 0.5,     -- Duración del fade a negro (FadeOutBlack Storyboard)
    updateWhenPaused = true
}

local isFadingOut = false
local canvas = nil
local finished = false
local splashTimer = 0 -- Temporizador para la animación Intro
local fadeOutTimer = 0 -- Temporizador para el Storyboard FadeOutBlack

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")
    
    -- Si venimos desde el juego y queremos ir directo al menú
    if _G.SkipSplash then
        _G.SkipSplash = nil
        finished = true
        if canvas then
            local path = self.public.nextXaml
            if type(path) == "table" then path = path.value end
            
            Engine.Log("Splash Screen: Saltando intro por petición global")
            canvas:LoadXAML(path)
            canvas:SetOpacity(1.0)
            _G._MenuManager_NeedReinit = true
            _G.CurrentXAML = path
        end
        return
    end

    if canvas then
        -- Iniciar la animación de Noesis definida en el XAML
        canvas:PlayStoryboard("Intro")
        Engine.Log("Splash Screen: Iniciando animación Intro")
    end
end

function Update(self, dt)
    if finished then return end

    splashTimer = splashTimer + dt
    
    -- Detectar entrada para omitir (X, Espacio o Enter)
    local skipInput = Input.GetKeyDown("Space") or Input.GetKeyDown("X") or Input.GetKeyDown("Enter")
    
    if skipInput and not isFadingOut then
        isFadingOut = true
        if canvas then canvas:PlayStoryboard("FadeOutBlack") end -- Inicia el fade a negro rápido
        fadeOutTimer = 0 -- Reiniciar el contador para el fade rápido
        Engine.Log("Splash Screen: Omitido por el usuario")
    end
    
    -- Fin natural de la animación
    if splashTimer >= self.public.totalDuration and not isFadingOut then
        isFadingOut = true
        if canvas then canvas:PlayStoryboard("FadeOutBlack") end -- Inicia el fade a negro
        fadeOutTimer = 0 -- Reiniciar el contador para el fade a negro
    end
    
    -- Lógica de desvanecimiento y transición
    if isFadingOut then
        fadeOutTimer = fadeOutTimer + dt
        
        -- Esperar a que el storyboard de fade a negro termine
        if fadeOutTimer >= self.public.fadeSpeed then
            finished = true
            if canvas then
                local path = self.public.nextXaml
                if type(path) == "table" then path = path.value end
                
                Engine.Log("Splash Screen: Transición a " .. path)
                canvas:LoadXAML(path)
                canvas:SetOpacity(1.0) -- Asegurar que el nuevo XAML esté completamente visible
                _G._MenuManager_NeedReinit = true
                _G.CurrentXAML = path
            end
        end
    end
end