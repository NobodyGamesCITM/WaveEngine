-- PortalTrigger.lua

public = {
    targetScene = "Level2",
    transitionObjectName = "SceneManager",
    radius = 4.0,
    updateWhenPaused = true
}

local inRange = false
local playerObj = nil
local sqrRadius = 16.0

function Start(self)
    sqrRadius = self.public.radius * self.public.radius
    playerObj = GameObject.Find("Player")
end

function Update(self, dt)
    if not playerObj then 
        playerObj = GameObject.Find("Player")
        if not playerObj then return end
    end

    local myPos = self.transform.worldPosition
    local pPos = playerObj.transform.worldPosition
    
    local dx = myPos.x - pPos.x
    local dz = myPos.z - pPos.z
    local sqrDist = (dx * dx) + (dz * dz)

    if sqrDist <= sqrRadius then
        if not inRange then
            inRange = true
            if _G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen() then
                if _G.ShowControlsHint then _G.ShowControlsHint("travel") end
            end
        end

        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            if _G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen() then
                local transitionObj = GameObject.Find(self.public.transitionObjectName)
                if transitionObj then
                    local transitionScript = transitionObj:GetComponent("Script")
                    if transitionScript and transitionScript.StartTransition then
                        Engine.Log("[Portal] Iniciando transición a: " .. self.public.targetScene)
                        transitionScript:StartTransition(self.public.targetScene)
                    end
                else
                    Engine.Log("[Portal] ERROR: No se encontró el objeto: " .. self.public.transitionObjectName)
                end
            else
                Engine.Log("[Portal] El portal aún no está activo. Faltan llaves.")
            end
        end
    else
        if inRange then
            inRange = false
            if _G.HideControlsHint then _G.HideControlsHint() end
        end
    end
end