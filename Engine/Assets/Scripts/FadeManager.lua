-- FadeManager.lua


public = {
    fadeDuration = 0.8,         -- Seconds for the fade effect
    targetScene  = "Blockout2", -- The scene to load after fading out
    autoFadeIn   = true,        -- Start the scene with a Fade In effect
}

function Start(self)
    -- Initiation moved to Update to ensure components are ready
end

function Update(self, dt)
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
        else
            if self.canvasComp then self.canvasComp:SetOpacity(0.0) end
        end

        _G.TransitionToScene = function(scene) self:StartFadeOut(scene) end
        
        -- Ensure world is moving
        Game.Resume()
        Game.SetTimeScale(1.0)
        
        self.initialized = true
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
        
        if t >= 1.0 then
            self.currentST = 0
            Engine.Log("[FadeManager] Fade IN Finished.")
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
            self.currentST = 0 -- Stop state to avoid loops
            local target = self.public.targetScene or "MainMenu"
            Engine.Log("[FadeManager] Fade OUT Finished. Loading scene: " .. target)
            _G._NewSceneLoaded = true
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
