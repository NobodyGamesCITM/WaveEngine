public = {
    updateWhenPaused   = true,
    delayBetweenPanels = 3.5,
    delayBetweenPages  = 1.0,
    debugSkip          = true
}

local sequence = {
    { page = "Page1", panel = "Page1_V1" },
    { page = "Page1", panel = "Page1_V2" },
    { page = "Page1", panel = "Page1_V3" },
    { page = "Page2", panel = "Page2_V1" },
    { page = "Page2", panel = "Page2_V2" },
    { page = "Page2", panel = "Page2_V3" },
}

local currentStep = 0
local currentPage = ""
local timer       = 0.0
local state       = "wait"
local initialized = false

--audiosources
local pageTurnSFX = nil
local owlHootSFX = nil
local owlWingSFX = nil
local ambianceSFX = nil

local function show(name, visible)
    UI.SetElementVisibility(name, visible)
end

local function hidePanelsOfPage(pageName)
    for _, e in ipairs(sequence) do
        if e.page == pageName then show(e.panel, false) end
    end
end

local function loadStep(index)
    if index > #sequence then
        state = "done"
        if pageTurnSFX then pageTurnSFX:SelectPlayAudioEvent("UI_PageTurn") end
        if ambianceSFX then ambianceSFX:StopAudioEvent() end
        
        show("CinematicPanel", false)
        show("CinematicFade", false)
        _G.CinematicActive = false
        if _G.UpdatePauseState then _G.UpdatePauseState() end
        Game.Resume()
        Engine.Log("[Cinematic] Terminado")
        
        return
    end

    local entry   = sequence[index]
    local newPage = entry.page

    if newPage ~= currentPage then
        if currentPage ~= "" then
            hidePanelsOfPage(currentPage)
            show(currentPage, false)
        end
        show(newPage, true)
        currentPage = newPage
        Engine.Log("[Cinematic] Página: " .. newPage)

        
        
    end

    show(entry.panel, true)
    Engine.Log("[Cinematic] Viñeta: " .. entry.panel)

    if entry.panel == "Page1_V1" then 
        --play owl hoot and wing, tree ambiance
        if owlHootSFX then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot") end
        if owlWingSFX then owlWingSFX:SelectPlayAudioEvent("UI_OwlFly") end
        if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_TreeAmbience") end
    elseif entry.panel == "Page1_V2" or entry.panel == "Page2_V2" then
        --play hoot
        if ambianceSFX then ambianceSFX:StopAudioEvent() end
        if owlHootSFX then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot") end
    elseif entry.panel == "Page2_V3" then
        --play sea ambiance
        if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_SeaWater") end
        
    else
        if ambianceSFX then ambianceSFX:StopAudioEvent() end
    end
end

local function FindAudioSources(self)

    local pageTurnObj = GameObject.FindInChildren(self.gameObject, "PageTurnSource")
    if pageTurnObj then 
        pageTurnSFX = pageTurnObj:GetComponent("Audio Source")
        if not pageTurnSFX then 
            Engine.Log("[VignetteManager] Unable to retrieve Page Turn SFX Audio Source")
        end
    else 
        Engine.Log("[VignetteManager] Couldn't find Page Turn SFX GameObject")
    end

    local owlHootObj = GameObject.FindInChildren(self.gameObject, "OwlHootSource")
    if owlHootObj then 
        owlHootSFX = owlHootObj:GetComponent("Audio Source")
        if not owlHootSFX then 
            Engine.Log("[VignetteManager] Unable to retrieve Owl Hoot SFX Audio Source")
        end
    else 
        Engine.Log("[VignetteManager] Couldn't find Owl Hoot GameObject")
    end


    local owlWingObj = GameObject.FindInChildren(self.gameObject, "OwlWingSource")
    if owlWingObj then 
        owlWingSFX = owlWingObj:GetComponent("Audio Source")
        if not owlWingSFX then 
            Engine.Log("[VignetteManager] Unable to retrieve Owl Wing SFX Audio Source")
        end
    else 
        Engine.Log("[VignetteManager] Couldn't find Owl Wing SFX GameObject")
    end

    
    --will grab one of the player's audiosources to bypass 3D positioning
    local player = GameObject.Find("Player")
    if not player then 
        Engine.Log("[VignetteManager] Player Not Found")
    else 
        local ambianceSource = GameObject.FindInChildren(player, "ItemSource")
        if ambianceSource then
            ambianceSFX = ambianceSource:GetComponent("Audio Source")
            if not ambianceSFX then 
                Engine.Log("[VignetteManager] Unable to retrieve the Player's Item SFX Audio Source for UI Ambiance")
            end 
        else
            Engine.Log("[VignetteManager] Could not find the Player's ItemSource GameObject")
        end

    end



end

function Start(self)
    _G.CinematicActive = true
    if _G.UpdatePauseState then _G.UpdatePauseState() end
    Game.Pause()
    hidePanelsOfPage("Page1")
    hidePanelsOfPage("Page2")
    hidePanelsOfPage("Page3")
    show("Page1", false)
    show("Page2", false)
    show("Page3", false)
    show("CinematicFade", false)
    show("CinematicPanel", true)

    FindAudioSources(self)

    state       = "wait"
    timer       = 0.0
    currentStep = 1
    loadStep(currentStep)

    initialized = true
    Engine.Log("[Cinematic] Listo")
end

function Update(self, dt)
    if not initialized then return end
    if state == "done" then return end

    if not pageTurnSFX then FindAudioSources(self) end

    if self.public.debugSkip and (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A")) then
        loadStep(#sequence + 1)
        return
    end

    timer = timer + math.min(dt, 0.05)

    if state == "wait" then
        local nextStep     = currentStep + 1
        local isPageChange = nextStep <= #sequence and sequence[nextStep].page ~= sequence[currentStep].page
        local delay = isPageChange and self.public.delayBetweenPages or self.public.delayBetweenPanels

        if timer >= delay then
            timer = 0.0
            currentStep = currentStep + 1

            if currentStep <= #sequence and sequence[currentStep].page ~= currentPage then
                show("CinematicFade", true)
                state = "pagebreak"
                if pageTurnSFX then pageTurnSFX:SelectPlayAudioEvent("UI_PageTurn") end
            else
                loadStep(currentStep)
            end
        end

    elseif state == "pagebreak" then
        if timer >= 0.4 then
            timer = 0.0
            show("CinematicFade", false)
            loadStep(currentStep)
            state = "wait"
        end
    end
end