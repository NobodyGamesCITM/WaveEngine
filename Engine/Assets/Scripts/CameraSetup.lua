-- PuzzlesTeleport.lua

function Start(self)
    local player = GameObject.Find("Player")
    local camObj = GameObject.Find("MainCamera")
    
    if camObj and player then
        local cineCam = camObj:GetComponent("CinematicCamera")
        
        if cineCam then
            cineCam:ClearTargets()
            cineCam:AddTarget(player, 1.0)
            Engine.Log("[CameraSetup] Camara enlazada al Player exitosamente.")
        else
            Engine.Log("[CameraSetup] ERROR: MainCamera no tiene el componente CinematicCamera.")
        end
    else
        Engine.Log("[CameraSetup] ERROR: No se encontro el objeto 'Player' o 'MainCamera' en la escena.")
    end
end

function Update(self, dt)
end