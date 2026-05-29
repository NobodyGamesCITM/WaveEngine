public = {
    updateWhenPaused   = true,
    delayBetweenPanels = 3.5,
    delayBetweenPages  = 1.0,
    debugSkip          = true,
}

local FADE_DURATION = 0.6

local sequence = {
    { page = "Page1", panel = "Page1_V1" },
    { page = "Page1", panel = "Page1_V2" },
    { page = "Page1", panel = "Page1_V3" },
    { page = "Page2", panel = "Page2_V1" },
    { page = "Page2", panel = "Page2_V2" },
    { page = "Page2", panel = "Page2_V3" },
}

local currentStep  = 0
local currentPage  = ""
local timer        = 0.0
local state        = "blackin"
local initialized  = false
local canvas       = nil

local pageTurnSFX  = nil
local owlHootSFX   = nil
local owlWingSFX   = nil
local ambianceSFX  = nil


local function show(name, v)
    UI.SetElementVisibility(name, v)
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
        show("CinematicFade", true)
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

    if self.gameObject:IsActive() then 
        if entry.panel == "Page1_V1" then
            if owlHootSFX  then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot")     end
            if owlWingSFX  then owlWingSFX:SelectPlayAudioEvent("UI_OwlFly")      end
            if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_TreeAmbience") end
        elseif entry.panel == "Page1_V2" or entry.panel == "Page2_V2" then
            if ambianceSFX then ambianceSFX:StopAudioEvent() end
            if owlHootSFX  then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot")     end
        elseif entry.panel == "Page2_V3" then
            if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_SeaWater")  end
        else
            if ambianceSFX then ambianceSFX:StopAudioEvent() end
        end
    else
        Engine.Log("Viñetas no visibles, SFX muteados")
    end
end

local function FindAudioSources(self)
    local pageTurnObj = GameObject.FindInChildren(self.gameObject, "PageTurnSource")
    if pageTurnObj then
        pageTurnSFX = pageTurnObj:GetComponent("Audio Source")
        if not pageTurnSFX then Engine.Log("[Cinematic] Unable to retrieve Page Turn SFX") end
    else
        Engine.Log("[Cinematic] Couldn't find PageTurnSource")
    end

    local owlHootObj = GameObject.FindInChildren(self.gameObject, "OwlHootSource")
    if owlHootObj then
        owlHootSFX = owlHootObj:GetComponent("Audio Source")
        if not owlHootSFX then Engine.Log("[Cinematic] Unable to retrieve Owl Hoot SFX") end
    else
        Engine.Log("[Cinematic] Couldn't find OwlHootSource")
    end

    local owlWingObj = GameObject.FindInChildren(self.gameObject, "OwlWingSource")
    if owlWingObj then
        owlWingSFX = owlWingObj:GetComponent("Audio Source")
        if not owlWingSFX then Engine.Log("[Cinematic] Unable to retrieve Owl Wing SFX") end
    else
        Engine.Log("[Cinematic] Couldn't find OwlWingSource")
    end
    

    local player = GameObject.Find("Player")
    if not player then
        Engine.Log("[Cinematic] Player Not Found")
    else
        local ambianceSource = GameObject.FindInChildren(player, "ItemSource")
        if ambianceSource then
            ambianceSFX = ambianceSource:GetComponent("Audio Source")
            if not ambianceSFX then Engine.Log("[Cinematic] Unable to retrieve Ambiance SFX") end
        else
            Engine.Log("[Cinematic] Could not find ItemSource")
        end
    end
end

function Start(self)
    _G.CinematicActive = true
    if _G.UpdatePauseState then _G.UpdatePauseState() end
    Game.Pause()

    canvas = self.gameObject:GetComponent("Canvas")

    hidePanelsOfPage("Page1")
    hidePanelsOfPage("Page2")
    show("Page1", false)
    show("Page2", false)
    show("CinematicFade", true)
    show("CinematicPanel", true)

    FindAudioSources(self)

    state       = "blackin"
    timer       = 0.0
    currentStep = 0
    initialized = true
    Engine.Log("[Cinematic] Listo")

    
end

function Update(self, dt)
    if not initialized then return end

    

    if state == "done" then
    if timer >= FADE_DURATION then
        if canvas then canvas:SetOpacity(0) end
        _G.CinematicActive = false
        _G._PlayerController_introAnim = true
        if _G.UpdatePauseState then _G.UpdatePauseState() end
        Game.Resume()
        state = "finished"
    end
    timer = timer + math.min(dt, 0.05)
    return
    end
    if state == "finished" then return end

    if not pageTurnSFX then FindAudioSources(self) end

    if self.public.debugSkip and (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A")) then
        loadStep(#sequence + 1)
        return
    end

    timer = timer + math.min(dt, 0.05)

    if state == "blackin" then
        if timer >= FADE_DURATION then
            timer = 0.0
            show("CinematicFade", false)
            state       = "wait"
            currentStep = 1
            loadStep(currentStep)
        end

    elseif state == "wait" then
        local nextStep     = currentStep + 1
        local isPageChange = nextStep <= #sequence and sequence[nextStep].page ~= sequence[currentStep].page
        local delay        = isPageChange and self.public.delayBetweenPages or self.public.delayBetweenPanels

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