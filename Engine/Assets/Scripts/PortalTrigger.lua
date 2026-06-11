public = {
    targetScene          = "Level2",
    transitionObjectName = "SceneManager",
    radius               = 4.0,
    updateWhenPaused     = true,
}

local inRange           = false
local playerObj         = nil
local sqrRadius         = 16.0
local transitionStarted = false

local function startTransition(self)
    if transitionStarted then return end
    if not (_G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen()) then
        Engine.Log("[Portal] El portal aún no está activo. Faltan llaves.")
        return
    end

    transitionStarted = true

    _G.UnregisterInteractable(self.gameObject)

    local transObj = GameObject.Find(self.public.transitionObjectName)
    if not transObj then
        Engine.Log("[Portal] ERROR: No se encontró: " .. self.public.transitionObjectName)
        return
    end

    local transScript = transObj:GetComponent("Script")
    if not (transScript and transScript.StartTransition) then return end

    Engine.Log("[Portal] Iniciando transición a: " .. self.public.targetScene)

    if _G.PortalManagerInstance.StartFireTransition then
        _G.PortalManagerInstance:StartFireTransition(14.0)
    end

    if _G.PlayerInstance then
        _G.PlayerInstance.public.canMove = false
        if _G.SetPlayerAnimTimer    then _G.SetPlayerAnimTimer(20.0)       end
        if _G.StartPortalEnterAnim  then _G.StartPortalEnterAnim()         end
        if _G.PlayPortalEnterCinematic then _G.PlayPortalEnterCinematic()  end

        _G.PlayerInstance.transform:SetPosition(97.633, -0.811, -178.289)
        local anim = _G.PlayerInstance.gameObject:GetComponent("Animation")
        if anim then pcall(function() anim:Play("PortalEnter", 0.0) end) end
    end

    _G._PendingPortalTransition = {
        script = transScript,
        scene  = self.public.targetScene,
        timer  = 25.0,
    }
end

function Start(self)
    sqrRadius = self.public.radius * self.public.radius
    playerObj = GameObject.Find("Player")

    _G._InteractCallbacks = _G._InteractCallbacks or {}
    _G._InteractCallbacks[self.gameObject] = function()
        startTransition(self)
    end
end

function Update(self, dt)
    if _G._PendingPortalTransition then
        _G._PendingPortalTransition.timer = _G._PendingPortalTransition.timer - dt
        if _G._PendingPortalTransition.timer <= 0 then
            local pending = _G._PendingPortalTransition
            _G._PendingPortalTransition = nil
            pending.script:StartTransition(pending.scene)
        end
    end

    if transitionStarted then return end

    if not playerObj then
        playerObj = GameObject.Find("Player")
        if not playerObj then return end
    end

    local myPos = self.transform.worldPosition
    local pPos  = playerObj.transform.worldPosition
    local dx    = myPos.x - pPos.x
    local dz    = myPos.z - pPos.z
    local sqrDist = dx * dx + dz * dz

    if sqrDist <= sqrRadius then
        if not inRange then
            inRange = true
            if _G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen() then
                _G.RegisterInteractable(self.gameObject, "portal")
                if _G.ShowControlsHint then _G.ShowControlsHint("travel") end
            end
        end
    else
        if inRange then
            inRange = false
            _G.UnregisterInteractable(self.gameObject)
            if _G.HideControlsHint then _G.HideControlsHint() end
        end
    end
end