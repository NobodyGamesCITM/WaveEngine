local FADE_DURATION = 0.5

public = {
    targetScene = { type = "Scene", value = "" },
    triggerKey  = "Space",
    conditionVar = "keysCollected",
    conditionValue = 1.0,
}

local function EaseInOutQuad(t)
    return t < 0.5 and 2*t*t or 1 - (-2*t + 2)^2 / 2
end

function Start(self)
    self.state = 4 -- FADE_IN
    self.fadeTimer = 0.0
    self.playerInside = false
    
    Game.Resume()
    Game.SetTimeScale(1.0)
    _G._PlayerController_isDead = false
    _G.PlayerInstance = nil
    
    self.fadeCanvas = self.gameObject:GetComponent("Canvas") or (GameObject.Find("FadeCanvas") and GameObject.Find("FadeCanvas"):GetComponent("Canvas"))
end

function Update(self, dt)
    -- TRUCO DE TECLADO: Tecla 'Z' suma una llave al contador global
    if Input.GetKeyDown("Z") then
        local varName = self.public.conditionVar or "keysCollected"
        local current = _G[varName] or 0
        _G[varName] = current + 1
        Engine.Log("[TRUCO] Llave añadida por tecla Z. Total: " .. tostring(_G[varName]))
    end

    -- BUSCAR Y REPARAR TODO
    local pObj = GameObject.Find("Player")
    local mGo  = GameObject.Find("MusicSource")

    if pObj then
        local pScript = GameObject.GetScript(pObj)
        if pScript and pScript.public then 
            _G.PlayerInstance = pScript
            pScript.public.canMove = true
            pScript.public.health = 100
        end
    end

    if mGo then
        local src = mGo:GetComponent("Audio Source")
        if src then src:PlayAudioEvent() ; Audio.SetGlobalVolume(100.0) end
    end

    -- FADE IN
    if self.state == 4 then
        self.fadeTimer = self.fadeTimer + dt
        local t = math.min(self.fadeTimer / FADE_DURATION, 1.0)
        local alpha = 1.0 - EaseInOutQuad(t)
        if self.fadeCanvas then self.fadeCanvas:SetOpacity(alpha) end
        if t >= 1.0 then
            self.state = 1
            local cv = GameObject.Find("FadeCanvas")
            if cv then cv:SetActive(false) end
            Audio.SetGlobalVolume(100.0)
        end
        return
    end

    -- IDLE (ESPERA DE PORTAL)
    if self.state == 1 then
        local key = self.public.triggerKey or "Space"
        -- Activamos el portal si tenemos llaves o pulsamos '2'
        if (self.playerInside and Input.GetKeyDown(key)) or Input.GetKeyDown("2") then
            local current = _G[self.public.conditionVar or ""] or 0
            if current >= (self.public.conditionValue or 1.0) or Input.GetKeyDown("2") then
                self.state = 2
                self.fadeTimer = 0.0
                local cv = GameObject.Find("FadeCanvas")
                if cv then cv:SetActive(true) end
                if self.fadeCanvas then self.fadeCanvas:SetOpacity(0.0) end
            else
                Engine.Log("[SceneLoader] No puedes pasar. Te faltan llaves.")
            end
        end
    end

    -- FADE OUT (CARGAR ESCENA)
    if self.state == 2 then
        self.fadeTimer = self.fadeTimer + dt
        local t = math.min(self.fadeTimer / FADE_DURATION, 1.0)
        local alpha = EaseInOutQuad(t)
        if self.fadeCanvas then self.fadeCanvas:SetOpacity(alpha) end
        Audio.SetGlobalVolume((1.0 - alpha) * 100.0)
        if t >= 1.0 then
            self.state = 3
            local sn = self.public.targetScene
            if type(sn) == "table" then sn = sn.value end
            Engine.LoadScene(Engine.GetScenesPath(), sn)
        end
    end
end

function OnTriggerEnter(self, other) if other and other:CompareTag("Player") then self.playerInside = true end end
function OnTriggerExit(self, other) if other and other:CompareTag("Player") then self.playerInside = false end end


