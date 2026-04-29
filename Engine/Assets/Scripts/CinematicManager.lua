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
            { time = 0.0,  pos = { 27, 0.053, 22 }, rot = { 0, 0, 0 } },
            { time = 10.0,  pos = { 27, 1.308, 24 }, rot = { -7.797, 0, 0 } },
            { time = 15.0,  pos = { 27, 1.308, 24 }, rot = { -7.797, 0, 0 } },
			{ time = 17.0,  pos = { 27, 7, 26.5 }, rot = { -35.586, 0, -1.287 } }
        }
        
        SendTrackToCamera(track, 2.0)
    end

    _G.PlayMaskCinematic = function()
		
    end
end

function Update(self, dt)
	
end