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

    _G.PlayMaskCinematic = function(maskName)
        if maskName == "Apolo" then
            local track = {
                { time = 0.0,  pos = { 202.054, 35.158, -162.676 }, rot = { 0, -0.094, 0 } },
                { time = 2.0, pos = { 202.054, 34.927, -163.428 }, rot = { 0, -0.094, 0 } },
                { time = 3.0, pos = { 202.054, 35.353, -162.255 }, rot = { 0, -0.094, 0 } },
                { time = 7.0, pos = { 202.054, 35.353, -163.108 }, rot = { 0, -0.094, 0 } },
                { time = 8.0, pos = { 202.054, 35.353, -163.108 }, rot = { 11.1, 24.996, 0 } },
                { time = 10.0, pos = { 202.054, 35.353, -163.108 }, rot = { 11.1, 24.996, 0 } },
                { time = 11.0, pos = { 197.980, 37.363, -162.437 }, rot = { -3.7, -23.552, 0 } },
                { time = 14.0, pos = { 197.5, 37.363, -161.326 }, rot = { -3.7, -23.552, 0 } },
                { time = 15.0, pos = { 201.809, 37.723, -161.888 }, rot = { -5.1, -21.327, 0 } },
                { time = 18.0, pos = { 201.809, 37.723, -161.888 }, rot = { -5.1, -21.327, 0 } },
                { time = 19.0, pos = { 201.809, 37.723, -161.888 }, rot = { -27,6, -21.327, 0 } },
                { time = 21.0, pos = { 201.809, 37.723, -161.888 }, rot = { -27,6, -21.327, 0 } },
                { time = 25.0, pos = { 195.649, 34.732, -163.785 }, rot = { -0.9, -30.673, 0 } },
                { time = 26.0, pos = { 194.713, 33.727, -166.768 }, rot = { 5.3, -73.973, 0 } },
                { time = 30.0, pos = { 194.713, 33.727, -166.768 }, rot = { 5.3, -73.973, 0 } }
            }
            SendTrackToCamera(track, 3.0)
            
        elseif maskName == "Hermes" then
            -- track de Hermes
            
        elseif maskName == "Ares" then
            -- track de Ares
            
        else
            Engine.Log("[CinematicManager] ERROR: Mascara desconocida para CinematicManager.")
        end
    end
end

function Update(self, dt)
	
end