local TRIGGER_RADIUS    = 5.0
local TOTAL_DURATION    = 5.25
local HUD_FADE_DURATION = 0.8

local function EaseInOutQuad(t)
    if t < 0.5 then return 2*t*t
    else return 1 - (-2*t+2)^2/2 end
end

local function FindCanvas()
    local mm = _G.GlobalMenuManagerInstance
    if mm and mm.gameObject and mm.canvas then
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

function Start(self)
    self.triggered = false
    self.phase     = "idle"
    self.timer     = 0.0
    self.canvas    = nil
    self.myPos     = self.transform.worldPosition

    if _G.LoadedFromSave then
        _G.TitleTrigger_HUDShouldStartHidden = false
        _G.TitleTrigger_Active = false
        self.phase = "done"
        local c = FindCanvas()
        if c then c:SetOpacity(1.0) end
        return
    end

    _G.TitleTrigger_HUDShouldStartHidden = true
    _G.TitleTrigger_Active = false

    Engine.Log("[TitleTrigger] Iniciado. Pos=("
        .. tostring(self.myPos.x) .. ", " .. tostring(self.myPos.z)
        .. ") Radio=" .. TRIGGER_RADIUS)
end

function Update(self, dt)
    if self.phase == "done" then return end

    if _G._PlayerController_isDead then
        _G.TitleTrigger_Active = false
        self.phase = "done"
        return
    end

    if not self.canvas then
        self.canvas = FindCanvas()
        if not self.canvas and self.phase ~= "idle" then return end
    end

    self.myPos = self.transform.worldPosition

    if self.phase == "idle" then
        if self.triggered then return end

        local player = _G.PlayerInstance
        if not player or not player.gameObject then return end
        local pPos = player.transform and player.transform.worldPosition
        if not pPos then return end

        local dx = pPos.x - self.myPos.x
        local dz = pPos.z - self.myPos.z
        if (dx*dx + dz*dz) > (TRIGGER_RADIUS * TRIGGER_RADIUS) then return end
        if _G.SceneManagerState and _G.SceneManagerState ~= 1 then return end
        if not self.canvas then
            Engine.Log("[TitleTrigger] Canvas no encontrado, reintentando...")
            return
        end

        self.triggered = true
        _G.TitleTrigger_Active = true
        Engine.Log("[TitleTrigger] Secuencia iniciada.")

        self.canvas:LoadXAML("SonOfIthaca.xaml")
        self.canvas:SetOpacity(1.0)
        self.canvas:PlayStoryboard("TitleAnim", "Title")

        local mm = _G.GlobalMenuManagerInstance
        if mm then
            mm.current     = "SonOfIthaca.xaml"
            _G.CurrentXAML = "SonOfIthaca.xaml"
        end

        self.phase = "playing"
        self.timer = 0.0
        return
    end

    self.timer = self.timer + Time.GetRealDeltaTime()

    if self.phase == "playing" then
        if self.timer >= TOTAL_DURATION then
            self.canvas:LoadXAML("HUD.xaml")
            self.canvas:SetOpacity(0.0)

            local mm = _G.GlobalMenuManagerInstance
            if mm then
                mm.current     = "HUD.xaml"
                _G.CurrentXAML = "HUD.xaml"
                mm.phase       = "idle"
                mm.fadeTimer   = 0.0
                mm.loggedReady = false
            end

            if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end

            _G.HUD_IsFading = true
            self.phase = "hudFade"
            self.timer = 0.0
            Engine.Log("[TitleTrigger] HUD preparado (invisible), iniciando fade in.")
        end

    elseif self.phase == "hudFade" then
        local t = math.min(self.timer / HUD_FADE_DURATION, 1.0)
        self.canvas:SetOpacity(EaseInOutQuad(t))
        if t >= 1.0 then
            self.canvas:SetOpacity(1.0)
            _G.TitleTrigger_HUDShouldStartHidden = false
            _G.TitleTrigger_Active = false
            _G.HUD_IsFading = false
            self.phase = "done"
            Engine.Log("[TitleTrigger] Secuencia completada. HUD activo.")
        end
    end
end