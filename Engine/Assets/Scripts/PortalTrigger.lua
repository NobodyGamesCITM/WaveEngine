-- PortalTrigger.lua

public = {
    targetScene = "Level_02",
    transitionObjectName = "SceneManager"
}

local inRange = false

function Update(self, dt)
    if not inRange then return end

    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        
        if _G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen() then
            
            local transitionObj = GameObject.Find(self.public.transitionObjectName)
            if transitionObj then
                local transitionScript = transitionObj:GetComponent("Script")
                if transitionScript and transitionScript.StartTransition then
                    transitionScript:StartTransition(self.public.targetScene)
                end
            end
        else
            Engine.Log("[PortalTrigger] El portal aún no está activo. Faltan llaves.")
        end
    end
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        inRange = true
        if _G.PortalManagerInstance and _G.PortalManagerInstance:IsPortalOpen() then
            if _G.ShowControlsHint then _G.ShowControlsHint("travel") end
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        inRange = false
        if _G.HideControlsHint then _G.HideControlsHint() end
    end
end