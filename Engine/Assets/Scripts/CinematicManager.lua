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
                { time = 0.0,  pos = { 203.746, 38.367, -171.199 }, rot = { 0, -0.094, 0 } },
                { time = 2.0,  pos = { 203.746, 38.136, -171.951 }, rot = { 0, -0.094, 0 } },
                { time = 3.0,  pos = { 203.746, 38.562, -170.778 }, rot = { 0, -0.094, 0 } },
                { time = 7.0,  pos = { 203.746, 38.562, -172.631 }, rot = { 0, -0.094, 0 } },
                { time = 8.0,  pos = { 203.746, 38.562, -172.631 }, rot = { 11.1, 24.996, 0 } },
                { time = 10.0, pos = { 203.746, 38.562, -172.631 }, rot = { 11.1, 24.996, 0 } },
                { time = 11.0, pos = { 197.172, 40.572, -170.960 }, rot = { -3.7, -32.552, 0 } },
                { time = 14.0, pos = { 197.692, 40.572, -169.849 }, rot = { -3.7, -32.552, 0 } },
                { time = 15.0, pos = { 199.001, 40.932, -171.411 }, rot = { -5.1, -30.327, 0 } },
                { time = 18.0, pos = { 199.001, 40.932, -171.411 }, rot = { -5.1, -30.327, 0 } },
                { time = 19.0, pos = { 199.001, 40.932, -171.411 }, rot = { -27.6, -30.327, 0 } },
                { time = 21.0, pos = { 199.001, 40.932, -171.411 }, rot = { -27.6, -30.327, 0 } },
                { time = 25.0, pos = { 196.841, 37.941, -171.308 }, rot = { -0.9, -35.673, 0 } },
                { time = 26.0, pos = { 196.905, 36.936, -176.291 }, rot = { 5.3, -73.973, 0 } },
                { time = 30.0, pos = { 196.905, 36.936, -176.291 }, rot = { 5.3, -73.973, 0 } }
            }
            SendTrackToCamera(track, 3.0)
            
        elseif maskName == "Hermes" then
            local track = {
                { time = 0.0,  pos = { -60.878, 5.180, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 2.0,  pos = { -61.929, 5.180, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 3.0,  pos = { -59.599, 5.527, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 7.0,  pos = { -61.148, 5.527, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 8.0,  pos = { -61.148, 5.527, -323.548 }, rot = { 6.9, 120.98, 0 } },
                { time = 10.0, pos = { -61.148, 5.527, -323.548 }, rot = { 6.9, 120.98, 0 } },
                { time = 11.0, pos = { -60.074, 7.558, -314.913 }, rot = { 0, 51.98, 0 } },
                { time = 14.0, pos = { -57.336, 7.558, -313.792 }, rot = { 0, 55.58, 0 } },
                { time = 15.0, pos = { -57.861, 7.558, -320.419 }, rot = { 0, 100.0, 0 } },
                { time = 18.0, pos = { -57.861, 7.558, -320.419 }, rot = { 0, 100.0, 0 } },
                { time = 19.0, pos = { -57.861, 7.558, -320.419 }, rot = { -17.9, 100.0, 0 } },
                { time = 21.0, pos = { -57.861, 7.558, -320.419 }, rot = { -17.9, 100.0, 0 } },
                { time = 25.0, pos = { -62.528, 6.496, -314.910 }, rot = { -7.5, 50.4, 0 } },
                { time = 26.0, pos = { -66.423, 5.096, -314.120 }, rot = { 0, 18.0, 0 } },
                { time = 30.0, pos = { -66.423, 5.096, -314.120 }, rot = { 0, 18.0, 0 } }
            }
            SendTrackToCamera(track, 3.0)
            
        elseif maskName == "Ares" then
            local track = {
                { time = 0.0,  pos = { 85.006, 11.253, -106.783 }, rot = { 0, 90.0, 0 } },
                { time = 2.0,  pos = { 83.819, 11.254, -106.780 }, rot = { 0, 90.0, 0 } },
                { time = 3.0,  pos = { 86.532, 12.100, -106.772 }, rot = { 0, 90.0, 0 } },
                { time = 7.0,  pos = { 85.232, 12.100, -106.769 }, rot = { 0, 90.0, 0 } },
                { time = 8.0,  pos = { 84.646, 12.252, -105.753 }, rot = { -173.1, 61.6, 180.0 } },
                { time = 10.0, pos = { 84.646, 12.252, -105.753 }, rot = { -173.1, 61.6, 180.0 } },
                { time = 11.0, pos = { 85.412, 13.481, -100.922 }, rot = { 0, 62.8, 0 } },
                { time = 14.0, pos = { 84.399, 13.481, -101.044 }, rot = { 0, 62.8, 0 } },
                { time = 15.0, pos = { 84.853, 13.581, -106.777 }, rot = { 180, 61, 180 } },
                { time = 18.0, pos = { 84.853, 13.581, -106.777 }, rot = { 180, 61, 180 } },
                { time = 19.0, pos = { 84.853, 13.581, -106.777 }, rot = { 158.2, 61, 180 } },
                { time = 21.0, pos = { 84.853, 13.581, -106.777 }, rot = { 158.2, 61, 180 } },
                { time = 25.0, pos = { 85.5, 12.16, -99.312 }, rot = { -10.4, 66.4, 0 } },
                { time = 26.0, pos = { 79.989, 10.717, -97.479 }, rot = { 0, 13.5, 0 } },
                { time = 30.0, pos = { 79.989, 10.717, -97.479 }, rot = { 0, 13.5, 0 } }
            }
            SendTrackToCamera(track, 3.0)
            
        else
            Engine.Log("[CinematicManager] ERROR: Mascara desconocida para CinematicManager.")
        end
    end

    _G.PlayStatueCinematic = function(statueId)
        local track = {}

        if statueId == "Circle" then
            track = {
                -- Estatua del Círculo
                { time = 0.00, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                { time = 2.98, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                { time = 2.99, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                
                -- HARD CUT Portal
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } },
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } },
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }
            }
        elseif statueId == "Arch" then
            track = {
                -- Estatua Arco
                { time = 0.00, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                { time = 2.98, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                { time = 2.99, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                
                -- HARD CUT Portal
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }  
            }
        elseif statueId == "T" then
            track = {
                -- Estatua T
                { time = 0.00, pos = { 154.742, 8.695, -209.378 }, rot = { -180, -88.906, 180 } }, 
                { time = 2.98, pos = { 154.742, 8.695, -209.378 }, rot = { -180, -88.906, 180 } }, 
                { time = 2.99, pos = { 154.742, 8.695, -209.378 }, rot = { -180, -88.906, 180 } }, 
                
                -- HARD CUT Portal
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }  
            }
        else
            Engine.Log("[CinematicManager] ERROR: statueId desconocido: " .. tostring(statueId))
            return
        end

        SendTrackToCamera(track, 0)
    end
	
	_G.PlayWinBossCinematic = function()
        local track = {
            { time = 0.0,  pos = { 130.677, 0.217, -649.282 }, rot = { 0, 0, 0 } },
            { time = 5.0,  pos = { 130.677, 0.217, -649.282 }, rot = { 0, 0, 0 } },
            { time = 8.0, pos = { 130.677, 0.217, -645.161 }, rot = { 0, 0, 0 } },
            { time = 10.0, pos = { 136.165, 0.217, -653.307 }, rot = { 180, 57.172, 180 } },
            { time = 12.0, pos = { 138.832, 0.217, -664.079 }, rot = { 180, 56.315, 180 } },
            { time = 22.0, pos = { 138.832, 0.217, -664.079 }, rot = { 180, 56.315, 180 } }
        }
        SendTrackToCamera(track, 3.0)
    end
end

function Update(self, dt)
	
end