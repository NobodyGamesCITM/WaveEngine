--- SceneLoader_lvl2.lua


public = {
    targetScene = { type = "Scene", value = "" },
    musicState  = "Level1"   
}



function Start(self)
    self.playerInside = false
    Engine.Log("[SceneLoader_lvl2] Script iniciado en: " .. self.gameObject:GetName())

    if self.public.targetScene == "" then
        Engine.Log("[SceneLoader_lvl2] AVISO: 'targetScene' esta vacio. Asignalo en el Inspector.")
    else
        Engine.Log("[SceneLoader_lvl2] Escena destino: " .. tostring(self.public.targetScene))
    end
end


function Update(self, dt)
    if self.playerInside and Input.GetKeyDown("Space") then
        local sceneName = self.public.targetScene
        if sceneName == nil or sceneName == "" then
            Engine.Log("[SceneLoader_lvl2] ERROR: No hay escena asignada en 'targetScene'.")
            return
        end

        Engine.Log("[SceneLoader_lvl2] Cargando escena: " .. sceneName)

        -- Cambiar estado de musica si se ha configurado
        if self.public.musicState and self.public.musicState ~= "" then
            Audio.SetMusicState(self.public.musicState)
        end

        local scenesPath = Engine.GetScenesPath()
        Engine.LoadScene(scenesPath, sceneName)
    end
end


function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        self.playerInside = true
        Engine.Log("[SceneLoader_lvl2] Jugador entro en el trigger. Pulsa Espacio para cambiar de escena.")
    end
end


function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        self.playerInside = false
        Engine.Log("[SceneLoader_lvl2] Jugador salio del trigger.")
    end
end
