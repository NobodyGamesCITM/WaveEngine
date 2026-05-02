-- CinematicManager.lua

public = {
    updateWhenPaused = true
}

local function SendTrackToCamera(track, blendBackTime)
    local camObj = GameObject.Find("MainCamera")
    if not camObj then 
        Engine.Log("[CinematicManager] ERROR: MainCamera no encontrada.")
        return 
    end
    
    local cinematicCam = camObj:GetComponent("CinematicCamera")
    if cinematicCam then
        cinematicCam:PlayCinematic(track, blendBackTime)
    else
        Engine.Log("[CinematicManager] ERROR: MainCamera no tiene el componente CinematicCamera.")
    end
end

function Start(self)

    _G.PlayWakeUpCinematic = function()
        
        local track = {
            { time = 0.0,  pos = { 21.2, 0.0, 14.1 }, rot = { -184.6, -67.0, -180.0 } },
            { time = 10.0, pos = { 20.527, 2.0, 13.0 }, rot = { 166.2, -56.365, 180.0 } },
            { time = 15.0, pos = { 20.527, 2.0, 13.0 }, rot = { 166.2, -56.365, 180.0 } },
            { time = 18.0, pos = { 13.670, 7.335, 21.2 }, rot = { -25.0, -69.6, 0.0 } }
        }
        
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayMaskCinematic = function()
		
    end
end

function Update(self, dt)
	
end