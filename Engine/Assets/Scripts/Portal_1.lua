-- TriggerSceneChange.lua

local canTransition = false -- Aquí está tu booleano

public = {
    targetScene = "Level_03",               
    transitionObjectName = "CanvasFundido"  
}

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
        canTransition = true
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        canTransition = false
    end
end