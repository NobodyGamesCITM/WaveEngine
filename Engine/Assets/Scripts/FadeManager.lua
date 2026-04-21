-- FadeManager.lua

public = {
    fadeDuration = 0.8,         -- Seconds for the fade effect
    targetScene  = "Blockout2", -- The scene to load after fading out
    autoFadeIn   = true,        -- Start the scene with a Fade In effect
    sceneMusic   = "Level1",    -- The music track for this specific level
}

local lastScene = ""

function Start(self)
    -- Initiation moved to Update to ensure components are ready
    self.lastSceneCounter = -1
end

function Update(self, dt)
    -- PERSISTENCE: If scene changed, reset initialized to re-run Fade In logic
    local currentCounter = _G._SceneCounter or 0
    if (self.lastSceneCounter or 0) ~= currentCounter then
        Engine.Log("[FadeManager] New scene count detected: " .. currentCounter .. ". Resetting for Fade IN. Current initialized: " .. tostring(self.initialized))
        self.initialized = false
        self.lastSceneCounter = currentCounter
        self.currentST = 1 -- Forced Fade In 
    end

    -- Delayed Initialization to ensure everything is ready
    if not self.initialized then
        Engine.Log("[FadeManager] Initializing on " .. (self.gameObject and self.gameObject.name or "Unknown"))
        self.canvasComp = self.gameObject:GetComponent("Canvas")
        self.fadeTimer = 0.0
        self.currentST = 0 -- 0: idle, 1: in, 2: out
        
        if self.public.autoFadeIn then
            self.currentST = 1
            if self.canvasComp then 
                self.canvasComp:SetOpacity(1.0) 
                Engine.Log("[FadeManager] Opacity set to 1.0 for Fade IN")
            end
            self.fadeTimer = 0
            Audio.SetGlobalVolume(0.0) -- Start muted for fade in
        else
            if self.canvasComp then self.canvasComp:SetOpacity(0.0) end
            Audio.SetGlobalVolume(100.0)
            Engine.Log("[FadeManager] No autoFadeIn - Audio volume reset to 100")
        end

        _G.TransitionToScene = function(scene) self:StartFadeOut(scene) end
        
        self.initialized = true
        
        -- MUSIC INITIALIZATION: Force the correct music state for this specific scene
        local mGo = GameObject.Find("MusicSource")
        if mGo then
            local musicComp = mGo:GetComponent("Audio Source")
            if musicComp then
                local track = self.public.sceneMusic or "Level1"
                Engine.Log("[FadeManager] Setting music state to: " .. tostring(track))
                Audio.SetMusicState(track)
                musicComp:PlayAudioEvent()
                
                -- Reposition to player to avoid 3D attenuation
                local ply = GameObject.Find("Player")
                if ply then
                    local p = ply.transform.position
                    mGo.transform:SetPosition(p.x, p.y + 2.0, p.z)
                end
            end
        end
    end

    if not self.initialized then return end

    -- Cap delta time to prevent skipping frames (especially after loading)
    local delta = math.min(dt, 0.05)

    if self.currentST == 1 then -- FADE IN 
        self.fadeTimer = self.fadeTimer + delta
        local duration = self.public.fadeDuration or 0.8
        if duration <= 0 then duration = 0.01 end 
        
        local t = math.min(self.fadeTimer / duration, 1.0)
        local alpha = 1.0 - t
        
        if self.canvasComp then 
            self.canvasComp:SetOpacity(alpha) 
        end
        
        -- Restore audio volume during fade in
        local vol = math.min(t * 100.0, 100.0)
        Audio.SetGlobalVolume(vol)
        
        if t >= 1.0 then
            self.currentST = 0
            Audio.SetGlobalVolume(100.0)
            Engine.Log("[FadeManager] Fade IN Finished - Global Volume at 100")
            Engine.Log("[FadeManager] Fade IN finished. Keep object alive for other scripts.")
        end

    elseif self.currentST == 2 then -- FADE OUT
        self.fadeTimer = self.fadeTimer + delta
        local duration = self.public.fadeDuration or 0.8
        if duration <= 0 then duration = 0.01 end
        
        local t = math.min(self.fadeTimer / duration, 1.0)
        local alpha = t
        
        if self.canvasComp then 
            self.canvasComp:SetOpacity(alpha) 
        end
        
        -- Optional: Music fade
        Audio.SetGlobalVolume((1.0 - alpha) * 100.0)
        
        if t >= 1.0 then
            self.currentST = 0
            local target = self.public.targetScene or "MainMenu"
            Engine.Log("[FadeManager] Fade OUT Finished. Loading scene: " .. target)
            self.lastSceneCounter = -1
            _G._SceneCounter = (_G._SceneCounter or 0) + 1
            _G._NewSceneLoaded = true
            _G._MenuManager_NeedReinit = true
            Engine.LoadScene(Engine.GetScenesPath(), target)
        end
    end
end

-- Force trigger from any external script
function StartFadeOut(self, sceneName)
    if sceneName then
        self.public.targetScene = sceneName
    end
    
    if self.currentST ~= 2 then
        self.gameObject:SetActive(true)
        self.currentST = 2
        self.fadeTimer = 0.0
        Engine.Log("[FadeManager] Transition triggered towards: " .. tostring(self.public.targetScene))
    end
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        self:StartFadeOut()
    end
end