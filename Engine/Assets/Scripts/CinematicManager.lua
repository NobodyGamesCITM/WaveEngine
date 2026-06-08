-- CinematicManager.lua

public = {
    updateWhenPaused = true
}

local cinematicCamComp = nil
local wasPlaying = false

local function SendTrackToCamera(track, blendBackTime)
    local camObj = GameObject.Find("MainCamera")
    if not camObj then 
        Engine.Log("[CinematicManager] ERROR: MainCamera no encontrada.")
        return 
    end
    
    cinematicCamComp = camObj:GetComponent("CinematicCamera")
    if cinematicCamComp then
        _G.CinematicActive = true
        
        if _G.TargetLockManager_ClearLock then _G.TargetLockManager_ClearLock() end
        if _G.TargetLockManager_SetParticleVisibility then _G.TargetLockManager_SetParticleVisibility(false) end
        
        local uiManager = GameObject.Find("UIManager")
        if uiManager then
            local uiCanvas = uiManager:GetComponent("Canvas")
            if uiCanvas then
                uiCanvas:SetOpacity(0.0)
            end
        end

        cinematicCamComp:PlayCinematic(track, blendBackTime)
        wasPlaying = true
        
        if _G.PlayerInstance then 
            _G.PlayerInstance.public.canMove = false 
            local duration = blendBackTime
            if track and #track > 0 then duration = duration + track[#track].time end
            if _G.SetPlayerAnimTimer then _G.SetPlayerAnimTimer(duration) end
        end
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
                { time = 0.0,  pos = { 204.246, 37.367, -171.199 }, rot = { 0, -0.094, 0 } },
                { time = 2.0,  pos = { 204.246, 37.136, -171.951 }, rot = { 0, -0.094, 0 } },
                { time = 3.0,  pos = { 204.246, 37.562, -170.778 }, rot = { 0, -0.094, 0 } },
                { time = 7.0,  pos = { 204.246, 38.562, -172.631 }, rot = { 0, -0.094, 0 } },
                { time = 8.0,  pos = { 204.246, 38.562, -172.631 }, rot = { 11.1, 24.996, 0 } },
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
                { time = 0.0,  pos = { -60.878, 4.257, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 2.0,  pos = { -61.929, 4.257, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 3.0,  pos = { -59.599, 4.604, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 7.0,  pos = { -61.148, 4.604, -323.548 }, rot = { 0, 90.0, 0 } },
                { time = 8.0,  pos = { -61.148, 4.604, -323.548 }, rot = { 6.9, 120.98, 0 } },
                { time = 10.0, pos = { -61.148, 4.604, -323.548 }, rot = { 6.9, 120.98, 0 } },
                { time = 11.0, pos = { -60.074, 6.635, -314.913 }, rot = { 0, 51.98, 0 } },
                { time = 14.0, pos = { -57.336, 6.635, -313.792 }, rot = { 0, 55.58, 0 } },
                { time = 15.0, pos = { -57.861, 6.635, -320.419 }, rot = { 0, 100.0, 0 } },
                { time = 18.0, pos = { -57.861, 6.635, -320.419 }, rot = { 0, 100.0, 0 } },
                { time = 19.0, pos = { -57.861, 6.635, -320.419 }, rot = { -17.9, 100.0, 0 } },
                { time = 21.0, pos = { -57.861, 6.635, -320.419 }, rot = { -17.9, 100.0, 0 } },
                { time = 25.0, pos = { -62.528, 5.573, -314.910 }, rot = { -7.5, 50.4, 0 } },
                { time = 26.0, pos = { -66.423, 4.173, -314.120 }, rot = { 0, 18.0, 0 } },
                { time = 30.0, pos = { -66.423, 4.173, -314.120 }, rot = { 0, 18.0, 0 } }
            }
            SendTrackToCamera(track, 3.0)
        elseif maskName == "Ares" then
            local track = {
                { time = 0.0,  pos = { 82.006, 11.253, -108.783 }, rot = { 0, 90.0, 0 } },
                { time = 2.0,  pos = { 81.819, 11.254, -108.780 }, rot = { 0, 90.0, 0 } },
                { time = 3.0,  pos = { 84.532, 12.100, -108.772 }, rot = { 0, 90.0, 0 } },
                { time = 7.0,  pos = { 83.232, 12.100, -108.769 }, rot = { 0, 90.0, 0 } },
                { time = 8.0,  pos = { 82.646, 12.252, -107.753 }, rot = { -173.1, 66.6, 180.0 } },
                { time = 10.0, pos = { 82.646, 12.252, -107.753 }, rot = { -173.1, 66.6, 180.0 } },
                { time = 11.0, pos = { 83.412, 13.481, -101.922 }, rot = { 0, 60.8, 0 } },
                { time = 14.0, pos = { 82.399, 13.481, -102.044 }, rot = { 0, 60.8, 0 } },
                { time = 15.0, pos = { 82.853, 13.581, -108.777 }, rot = { 180, 55, 180 } },
                { time = 18.0, pos = { 82.853, 13.581, -108.777 }, rot = { 180, 55, 180 } },
                { time = 19.0, pos = { 82.853, 13.581, -108.777 }, rot = { 158.2, 57, 180 } },
                { time = 21.0, pos = { 82.853, 13.581, -108.777 }, rot = { 158.2, 57, 180 } },
                { time = 25.0, pos = { 81.5, 12.16, -101.312 }, rot = { -10.4, 66.4, 0 } },
                { time = 26.0, pos = { 78.5, 10.717, -101.0 }, rot = { 0, 13.5, 0 } },
                { time = 30.0, pos = { 78.5, 10.717, -102.0 }, rot = { 0, 13.5, 0 } }
            }
            SendTrackToCamera(track, 3.0)
        end
    end

    _G.PlayStatueCinematic = function(statueId)
        local track = {}
        if statueId == "Circle" then
            track = {
                { time = 0.00, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                { time = 2.98, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                { time = 2.99, pos = { 86.162, 24.024, -339.759 }, rot = { 0, -1.465, 0 } },
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } },
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } },
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }
            }
        elseif statueId == "Arch" then
            track = {
                { time = 0.00, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                { time = 2.98, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                { time = 2.99, pos = { 40.211, 20.273, -217.416 }, rot = { 0, -36.076, 0 } }, 
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }  
            }
        elseif statueId == "T" then
            track = {
                { time = 0.00, pos = { 158.871, 13.489, -217.612 }, rot = { 160.5, -88.906, -180 } }, 
                { time = 2.98, pos = { 158.871, 13.489, -217.612 }, rot = { 160.5, -88.906, -180 } }, 
                { time = 2.99, pos = { 158.871, 13.489, -217.612 }, rot = { 160.5, -88.906, -180 } }, 
                { time = 3.00, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 3.01, pos = { 96.217, 19.671, -144.390 }, rot = { -31.169, 0, 0 } }, 
                { time = 10.00, pos = { 114.142, 16.863, -154.432 }, rot = { -31.169, 37.6, 0 } }  
            }
        end
        SendTrackToCamera(track, 0)
    end
    
    _G.PlayWinBossCinematic = function()
        local track = {
            { time = 0.0,  pos = { 130.677, -5.185, -649.282 }, rot = { 0, 0, 0 } },
            { time = 5.0,  pos = { 130.677, -5.185, -649.282 }, rot = { 0, 0, 0 } },
            { time = 8.0, pos = { 130.677, -5.185, -645.161 }, rot = { 0, 0, 0 } },
            { time = 10.0, pos = { 136.165, -5.185, -653.307 }, rot = { 180, 57.172, 180 } },
            { time = 12.0, pos = { 138.832, -5.185, -664.079 }, rot = { 180, 56.315, 180 } },
            { time = 22.0, pos = { 138.832, -5.185, -664.079 }, rot = { 180, 56.315, 180 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayPortalEnterCinematic = function()
        local track = {
            { time = 0.0, pos = { 104.718, 3.422, -176.426 }, rot = { -20.0, 86.164, 0.0 } },
            { time = 15.0, pos = { 112.0, 4.7, -176.426 }, rot = { -20.0, 86.164, 5.0 } },
            { time = 20.0, pos = { 112.0, 4.7, -176.426 }, rot = { -20.0, 86.164, 5.0 } }
        }
        SendTrackToCamera(track, 20.0)
    end

    _G.PlayPortalExitCinematic = function()
        local track = {
            { time = 0.0,  pos = { 79.969, 2.200, 94.524 }, rot = { 168.200, 19.880, 180.000 } },
            { time = 4.0,  pos = { 79.969, 2.200, 94.524 }, rot = { 168.200, 19.880, 180.000 } },
            { time = 6.0,  pos = { 84.469, 0.800, 102.724 }, rot = { 174.000, 88.780, 180.000 } },
            { time = 8.0,  pos = { 82.769, -0.300, 106.924 }, rot = { 185.800, 143.480, 180.000 } },
            { time = 14.0, pos = { 82.769, -0.300, 106.924 }, rot = { 185.800, 143.480, 180.000 } }
        }
        SendTrackToCamera(track, 2.0)
    end

    _G.PlayApolo1DoorCinematic = function()
        local track = {
            { time = 0.0, pos = { 170.891, 42.774, -188.327 }, rot = { -25.699, 0.0, -1.0 } },
            { time = 3.0, pos = { 170.891, 42.774, -188.327 }, rot = { -25.699, 0.0, -1.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayApolo2Door2Cinematic = function()
        local track = {
            { time = 0.0, pos = { 110.837, 57.545, -323.940 }, rot = { -26.011, -7.535, 0.0 } },
            { time = 3.0, pos = { 110.837, 57.545, -323.940 }, rot = { -26.011, -7.535, 0.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayPreApoloHermes3TripleCinematic = function()
        local track = {
            { time = 0.0, pos = { 87.248, 25.194, -204.308 }, rot = { -18.011, -53.135, 0.0 } },
            { time = 4.0, pos = { 87.248, 25.194, -204.308 }, rot = { -18.011, -53.135, 0.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayApoloHermes3Door2Cinematic = function()
        local track = {
            { time = 0.0, pos = { 144.501, 20.794, -213.317 }, rot = { -23.511, -78.035, 0.0 } },
            { time = 3.0, pos = { 144.501, 20.794, -213.317 }, rot = { -23.511, -78.035, 0.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayAres1DoorCinematic = function()
        local track = {
            { time = 0.0, pos = { -30.029, 19.456, -142.973 }, rot = { -19.800, -90.0, 0.0 } },
            { time = 3.0, pos = { -30.029, 19.456, -142.973 }, rot = { -19.800, -90.0, 0.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayCombined2DoorCinematic = function()
        local track = {
            { time = 0.0, pos = { 81.742, 36.446, -258.252 }, rot = { -19.800, -51.2, 0.0 } },
            { time = 3.0, pos = { 81.742, 36.446, -258.252 }, rot = { -19.800, -51.2, 0.0 } }
        }
        SendTrackToCamera(track, 3.0)
    end

    _G.PlayDoorCinematic = function(doorId)
        local track = {}
        
        if doorId == "Door_Default" then
            track = {
                { time = 0.0, pos = { 0.0, 10.0, 0.0 }, rot = { 0, 0, 0 } },
                { time = 2.0, pos = { 0.0, 10.0, 0.0 }, rot = { 0, 0, 0 } }
            }
        elseif doorId == "Apolo1Door" then
            track = {
                { time = 0.0, pos = { 170.891, 42.774, -188.327 }, rot = { -25.699, 0.0, -1.0 } },
                { time = 3.0, pos = { 170.891, 42.774, -188.327 }, rot = { -25.699, 0.0, -1.0 } }
            }
        elseif doorId == "Apolo2Door2" then
            track = {
                { time = 0.0, pos = { 110.837, 57.545, -323.940 }, rot = { -26.011, -7.535, 0.0 } },
                { time = 3.0, pos = { 110.837, 57.545, -323.940 }, rot = { -26.011, -7.535, 0.0 } }
            }
        elseif doorId == "PreApoloHermes3Triple" then
            track = {
                { time = 0.0, pos = { 87.248, 25.194, -204.308 }, rot = { -18.011, -53.135, 0.0 } },
                { time = 4.0, pos = { 87.248, 25.194, -204.308 }, rot = { -18.011, -53.135, 0.0 } }
            }
        elseif doorId == "ApoloHermes3Door2" then
            track = {
                { time = 0.0, pos = { 144.501, 20.794, -213.317 }, rot = { -23.511, -78.035, 0.0 } },
                { time = 3.0, pos = { 144.501, 20.794, -213.317 }, rot = { -23.511, -78.035, 0.0 } }
            }
        elseif doorId == "Ares1Door" then
            track = {
                { time = 0.0, pos = { -30.029, 19.456, -142.973 }, rot = { -19.800, -90.0, 0.0 } },
                { time = 3.0, pos = { -30.029, 19.456, -142.973 }, rot = { -19.800, -90.0, 0.0 } }
            }
        elseif doorId == "Combined2Door" then
            track = {
                { time = 0.0, pos = { 81.742, 36.446, -258.252 }, rot = { -19.800, -51.2, 0.0 } },
                { time = 3.0, pos = { 81.742, 36.446, -258.252 }, rot = { -19.800, -51.2, 0.0 } }
            }
        else
            Engine.Log("[CinematicManager] WARNING: Cinematic track not found for door: " .. tostring(doorId))
            track = {
                { time = 0.0, pos = { 0, 10, 0 }, rot = { 0, 0, 0 } },
                { time = 2.0, pos = { 0, 10, 0 }, rot = { 0, 0, 0 } }
            }
        end
        
        SendTrackToCamera(track, 1.5)
    end

    _G.PlayBoss2IntroCinematic = function()
        local track = {
            { time = 0.0,  pos = { 118.862, -0.390, -641.972 }, rot = { -9.193, 12.800, 0.0 } },
            { time = 4.0,  pos = { 118.862, -0.390, -641.972 }, rot = { -9.193, 12.800, 0.0 } },
            { time = 6.0,  pos = { 124.962, -2.590, -655.972 }, rot = { -4.693, -36.100, 0.0 } },
            { time = 8.0,  pos = { 129.862, -5.650, -653.572 }, rot = { 5.207, -180.000, 0.0 } },
            { time = 10.0, pos = { 129.862, -5.650, -653.572 }, rot = { 5.207, -180.000, 0.0 } },
            { time = 14.0, pos = { 130.162, 3.410, -650.272 }, rot = { -35.493, -180.000, 0.0 } },
            { time = 14.98, pos = { 130.162, 3.410, -650.272 }, rot = { -35.493, -180.000, 0.0 } },
            { time = 14.99, pos = { 130.162, 3.410, -650.272 }, rot = { -35.493, -180.000, 0.0 } },
            { time = 15.0, pos = { 130.162, 3.410, -650.272 }, rot = { -35.493, -180.000, 0.0 } },
            { time = 15.01,pos = { 135.232, -4.661, -635.663 }, rot = { -6.200, 86.700, 0.0 } },
            { time = 15.02,pos = { 135.232, -4.661, -635.663 }, rot = { -6.200, 86.700, 0.0 } },
            { time = 17.0, pos = { 136.232, -4.661, -635.663 }, rot = { -3.600, 84.300, 0.0 } },
            { time = 21.0, pos = { 138.532, -4.661, -635.763 }, rot = { 3.200, 62.600, 0.0 } },
            { time = 25.0, pos = { 138.532, -4.661, -635.763 }, rot = { 3.200, 62.600, 0.0 } },
            { time = 27.0, pos = { 138.532, -4.661, -635.763 }, rot = { 3.200, 62.600, 0.0 } }
        }
        Engine.Log("Sending Play2BossIntroCinematic to camera")
        SendTrackToCamera(track, 1.5)
    end

    _G.PlayGauntletAresCinematic = function()
        local track = {
            { time = 0.0, pos = { 95.608, 22.819, -60.763 }, rot = { -17.300, 38.600, 0.0 } },
            { time = 3.0, pos = { 95.608, 22.819, -60.763 }, rot = { -17.300, 38.600, 0.0 } }
        }
        SendTrackToCamera(track, 0.5)
    end
end

function Update(self, dt)
    if wasPlaying and cinematicCamComp then
        if not cinematicCamComp:IsPlayingCinematic() then
            wasPlaying = false
            _G.CinematicActive = false
            
            if _G.PlayerInstance then 
                _G.PlayerInstance.public.canMove = true 
            end
            
            if _G.TargetLockManager_SetParticleVisibility then
                _G.TargetLockManager_SetParticleVisibility(true)
            end
            -- Dejamos que el HUDController gestione la restauración de opacidad con su propio fade-in
        end
    end
end