-- TriggerSceneChange.lua

local canTransition     = false
local warningShown      = false  -- para mostrar portalWarning solo una vez

public = {
    targetScene          = "Level_03",
    transitionObjectName = "CanvasFundido"
}

local function hasAllKeys()
    local varName = _G.MissionVarName or "keysCollected"
    local collected = _G[varName] or 0
    local total     = _G.TotalStatuesToDestroy or 3
    return collected >= total
end

function Update(self, dt)
    if canTransition and Input.GetKeyDown("Space") then

        Engine.Log("[TriggerSceneChange] Tecla pulsada. Buscando el SceneChanger...")

        local transitionObj = GameObject.Find(self.public.transitionObjectName)

        if transitionObj then
            local transitionScript = GameObject.GetScript(transitionObj)

            if transitionScript and transitionScript.StartTransition then
                Engine.Log("[TriggerSceneChange] SceneChanger encontrado. ¡Iniciando viaje a " .. self.public.targetScene .. "!")

                transitionScript:StartTransition(self.public.targetScene)

                canTransition = false
            else
                Engine.Log("[TriggerSceneChange] ERROR: El objeto se encontró, pero no tiene la función StartTransition().")
            end
        else
            Engine.Log("[TriggerSceneChange] ERROR: No existe ningún GameObject llamado '" .. self.public.transitionObjectName .. "' en la escena.")
        end
    end
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        -- if not hasAllKeys() then
        --     Engine.Log("[Portal] Llaves insuficientes, portal bloqueado.")
        --     return
        -- end
        canTransition = true
        -- Disparar portalWarning la primera vez que el player entra con todas las llaves
        if not warningShown then
            warningShown = true
            if _G.TriggerSequence then
                _G.TriggerSequence("portalWarning")
            end
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        canTransition = false
    end
end