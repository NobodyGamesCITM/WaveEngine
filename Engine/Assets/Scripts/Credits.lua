public = {
    scrollSpeed       = 80.0,
    scrollDuration    = 70.0,
    thanksDuration    = 3.0,
    slideshowInterval = 6.0, 
    updateWhenPaused  = true,
}

local PHASE_IDLE      = 0
local PHASE_SCROLL    = 1
local PHASE_THANKS_IN = 2
local PHASE_THANKS    = 3
local PHASE_FADE_OUT  = 4

local phase       = PHASE_IDLE
local scrollY     = 0.0
local scrollTimer = 0.0
local phaseTimer  = 0.0
local updateTimer = 0.0
local triggered   = false
local fadeStarted = false

local UPDATE_RATE          = 0.016
local FADE_DURATION        = 2.5
local THANKS_FADE_DURATION = 1.0

local canvasComp = nil

-- Slideshow
local BG_IMAGE_COUNT = 12
local bgCurrent      = 1
local bgSlideTimer   = 0.0
local bgFinished     = false  


function Start(self)
    _G.CreditsController = self
    canvasComp = self.gameObject:GetComponent("Canvas")
    if canvasComp then canvasComp:SetOpacity(0) end

    -- Todas las imágenes ocultas al inicio
    for i = 1, BG_IMAGE_COUNT do
        UI.SetElementVisibility("BgImage" .. i, false)
    end

    Engine.Log("[Credits] Listo.")
end


function ShowCredits(self)
    if phase ~= PHASE_IDLE then return end

    scrollY       = 0.0
    scrollTimer   = 0.0
    phaseTimer    = 0.0
    updateTimer   = 0.0
    fadeStarted   = false
    phase         = PHASE_SCROLL

    -- Reset slideshow: ocultar todo y mostrar solo la primera
    bgCurrent    = 1
    bgSlideTimer = 0.0
    bgFinished   = false
    for i = 1, BG_IMAGE_COUNT do
        UI.SetElementVisibility("BgImage" .. i, false)
    end
    UI.SetElementVisibility("BgImage1", true)

    if canvasComp then canvasComp:SetOpacity(1) end

    UI.SetElementVisibility("ThanksPanel",    false)
    UI.SetElementVisibility("CreditsFadeOut", false)
    UI.SetElementVisibility("CreditsFade",    false)
    UI.SetElementMargin("CreditsContent", 0, 0, 0, 0)

    if _G.PlayerInstance then
        _G.PlayerInstance.public.canMove = false
    end

    Engine.Log("[Credits] Créditos iniciados.")
end


function OnTriggerEnter(self, other)
    if triggered then return end
    if other.name ~= "Player" and not other:CompareTag("Player") then return end

    triggered = true
    Game.Pause()
    ShowCredits(self)
    Engine.Log("[Credits] Trigger activado por Player.")
end


function UpdateSlideshow(self, dt)
    if bgFinished then return end

    bgSlideTimer = bgSlideTimer + dt
    if bgSlideTimer >= self.public.slideshowInterval then
        bgSlideTimer = 0.0

        local bgNext = bgCurrent + 1
        if bgNext > BG_IMAGE_COUNT then
            bgFinished = true
            return
        end

        UI.SetElementVisibility("BgImage" .. bgCurrent, false)
        UI.SetElementVisibility("BgImage" .. bgNext,    true)
        bgCurrent = bgNext
    end
end


function Update(self, dt)
    if phase == PHASE_IDLE then return end

    UpdateSlideshow(self, dt)

    phaseTimer = phaseTimer + dt

    if phase == PHASE_SCROLL then
        scrollY     = scrollY     + (self.public.scrollSpeed * dt)
        scrollTimer = scrollTimer + dt
        updateTimer = updateTimer + dt

        if updateTimer >= UPDATE_RATE then
            updateTimer = 0.0
            UI.SetElementMargin("CreditsContent", 0, -scrollY, 0, 0)
        end

        if not fadeStarted and scrollTimer >= (self.public.scrollDuration - 2.0) then
            fadeStarted = true
            UI.SetElementVisibility("CreditsFadeOut", true)
            Engine.Log("[Credits] Fade a negro iniciado.")
        end

        if scrollTimer >= self.public.scrollDuration then
            UI.SetElementVisibility("ThanksPanel",    true)
            UI.SetElementVisibility("CreditsFadeOut", false)
            phaseTimer = 0.0
            phase      = PHASE_THANKS_IN
            Engine.Log("[Credits] Scroll completado. Thanks For Playing apareciendo.")
        end

    elseif phase == PHASE_THANKS_IN then
        if phaseTimer >= THANKS_FADE_DURATION then
            phaseTimer = 0.0
            phase      = PHASE_THANKS
            Engine.Log("[Credits] Thanks For Playing visible. Esperando "
                       .. tostring(self.public.thanksDuration) .. "s.")
        end

    elseif phase == PHASE_THANKS then
        if phaseTimer >= self.public.thanksDuration then
            UI.SetElementVisibility("CreditsFadeOut", true)
            phaseTimer = 0.0
            phase      = PHASE_FADE_OUT
            Engine.Log("[Credits] Fade out final iniciado.")
        end

    elseif phase == PHASE_FADE_OUT then
        if phaseTimer >= FADE_DURATION then
            if canvasComp then canvasComp:SetOpacity(0) end
            phase = PHASE_IDLE
            GoToMainMenu()
        end
    end
end


function GoToMainMenu()
    Engine.Log("[Credits] Secuencia completa. Volviendo al menú principal.")
    _G.SkipSplash = true
    if _G.TransitionToScene then
        _G.TransitionToScene("Splash.scene")
    else
        Engine.LoadScene(Engine.GetScenesPath(), "Splash.scene")
    end
end