-- TitleTrigger.lua
-- Detecta al player por distancia (no necesita collider físico).
-- Controla el canvas del UIManager para mostrar SonOfIthaca.xaml
-- antes del HUD.

local TRIGGER_RADIUS     = 5.0
local FADE_IN_DURATION   = 1.2
local HOLD_DURATION      = 2.5
local FADE_OUT_DURATION  = 1.0
local HUD_FADE_DURATION  = 0.8

local triggered = false
local phase     = "idle"
local timer     = 0.0
local myPos     = nil
local canvas    = nil

local function EaseInOutQuad(t)
    if t < 0.5 then return 2*t*t
    else return 1 - (-2*t+2)^2/2 end
end

local function FindCanvas()
    local mm = _G.GlobalMenuManagerInstance
    if mm and mm.canvas then
        Engine.Log("[TitleTrigger] Canvas encontrado via GlobalMenuManagerInstance")
        return mm.canvas
    end
    local obj = GameObject.Find("UIManager")
    if obj then
        local c = obj:GetComponent("Canvas")
        if c then
            Engine.Log("[TitleTrigger] Canvas encontrado via GameObject.Find('UIManager')")
            return c
        else
            Engine.Log("[TitleTrigger] WARNING: UIManager encontrado pero sin componente Canvas")
        end
    else
        Engine.Log("[TitleTrigger] WARNING: GameObject 'UIManager' no encontrado en escena")
    end
    return nil
end

local function PlayerInZone(playerPos)
    if not myPos then return false end
    local dx = playerPos.x - myPos.x
    local dz = playerPos.z - myPos.z
    return (dx*dx + dz*dz) <= (TRIGGER_RADIUS * TRIGGER_RADIUS)
end

function Start(self)
    triggered = false
    phase     = "idle"
    timer     = 0.0
    canvas    = nil
    myPos     = self.transform.worldPosition

    _G.TitleTrigger_HUDShouldStartHidden = true
    _G.TitleTrigger_Active = false

    Engine.Log("[TitleTrigger] Iniciado. Pos=("
        .. tostring(myPos.x) .. ", " .. tostring(myPos.z)
        .. ") Radio=" .. TRIGGER_RADIUS)
end

function Update(self, dt)
    if phase == "done" then return end

    myPos = self.transform.worldPosition

    -- Esperar deteccion del player
    if phase == "idle" then
        if triggered then return end

        local player = _G.PlayerInstance
        if not player then return end
        local pPos = player.transform and player.transform.worldPosition
        if not pPos then return end

        if not PlayerInZone(pPos) then return end

        canvas = FindCanvas()
        if not canvas then
            Engine.Log("[TitleTrigger] Canvas no encontrado, reintentando...")
            return
        end

        triggered = true
        _G.TitleTrigger_Active = true
        Engine.Log("[TitleTrigger] Secuencia iniciada.")

        canvas:LoadXAML("SonOfIthaca.xaml")
        canvas:SetOpacity(0.0)
        phase = "fadeIn"
        timer = 0.0
        return
    end

    timer = timer + dt

    if not canvas then
        canvas = FindCanvas()
        if not canvas then return end
    end

    -- Fade in del titulo
    if phase == "fadeIn" then
        local t = math.min(timer / FADE_IN_DURATION, 1.0)
        canvas:SetOpacity(EaseInOutQuad(t))
        if t >= 1.0 then
            canvas:SetOpacity(1.0)
            phase = "hold"
            timer = 0.0
            Engine.Log("[TitleTrigger] Fade in completado.")
        end

    -- Hold
    elseif phase == "hold" then
        if timer >= HOLD_DURATION then
            phase = "fadeOut"
            timer = 0.0
            Engine.Log("[TitleTrigger] Hold terminado, fade out.")
        end

    -- Fade out del titulo
    elseif phase == "fadeOut" then
        local t = math.min(timer / FADE_OUT_DURATION, 1.0)
        canvas:SetOpacity(1.0 - EaseInOutQuad(t))
        if t >= 1.0 then
            -- Canvas invisible: cargamos HUD y preparamos todo ANTES del fade in
            canvas:SetOpacity(0.0)
            canvas:LoadXAML("HUD.xaml")
            canvas:SetOpacity(0.0)

            -- Sincronizamos el MenuManager mientras el canvas esta invisible
            local mm = _G.GlobalMenuManagerInstance
            if mm then
                mm.current     = "HUD.xaml"
                mm.phase       = "idle"
                mm.fadeTimer   = 0.0
                mm.loggedReady = false
            end

            -- ForceRefreshHUD con canvas en opacidad 0:
            -- las mascaras/barras quedan en estado correcto ANTES
            -- de que el usuario vea nada, eliminando el flash.
            if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end

            phase = "hudFade"
            timer = 0.0
            Engine.Log("[TitleTrigger] HUD preparado (invisible), iniciando fade in.")
        end

    -- Fade in del HUD
    elseif phase == "hudFade" then
        local t = math.min(timer / HUD_FADE_DURATION, 1.0)
        canvas:SetOpacity(EaseInOutQuad(t))
        if t >= 1.0 then
            canvas:SetOpacity(1.0)
            _G.TitleTrigger_Active = false
            phase = "done"
            Engine.Log("[TitleTrigger] Secuencia completada. HUD activo.")
        end
    end
end