public = {
    updateWhenPaused   = true,
    delayBetweenPanels = 3.5,
    delayBetweenPages  = 3.5,
    debugSkip          = true,
}

local FADE_DURATION       = 0.6
local PANEL_FADE_DURATION = 0.5
local PAGE_BREAK_DURATION = 0.6

local sequence = {
    { page = "Page1", panel = "Page1_V1" },
    { page = "Page1", panel = "Page1_V2" },
    { page = "Page1", panel = "Page1_V3" },
    { page = "Page2", panel = "Page2_V1" },
    { page = "Page2", panel = "Page2_V2" },
    { page = "Page2", panel = "Page2_V3" },
    { page = "Page3", panel = "Page3_V1" },
    { page = "Page3", panel = "Page3_V2" },
    { page = "Page3", panel = "Page3_V3" },
}

local currentStep  = 0
local currentPage  = ""
local timer        = 0.0
local state        = "blackin"
local initialized  = false
local canvas       = nil

local fadePanel    = nil
local fadePanelT   = 0.0

local pageTurnSFX  = nil
local owlHootSFX   = nil
local owlWingSFX   = nil
local ambianceSFX  = nil
local televoiceSFX = nil


local function show(name, v)
    UI.SetElementVisibility(name, v)
end

local function setOpacity(name, alpha)
    if canvas then canvas.SetElementOpacity(name, alpha) end
end

local function resetAllPanels()
    for _, e in ipairs(sequence) do
        setOpacity(e.panel, 0)
    end
    setOpacity("Page1", 0)
    setOpacity("Page2", 0)
    setOpacity("Page3", 0)
end

local function showPanel(name)
    fadePanel  = name
    fadePanelT = 0.0
    setOpacity(name, 0.01)
end

local function hidePanelsOfPage(pageName)
    for _, e in ipairs(sequence) do
        if e.page == pageName then
            setOpacity(e.panel, 0)
        end
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
            setOpacity(currentPage, 0)
        end
        setOpacity(newPage, 1)
        currentPage = newPage
        Engine.Log("[Cinematic] Pagina: " .. newPage)
    end

    showPanel(entry.panel)
    Engine.Log("[Cinematic] Panel: " .. entry.panel)

    if entry.panel == "Page1_V1" then
        if owlHootSFX then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot") end
        if owlWingSFX then owlWingSFX:SelectPlayAudioEvent("UI_OwlFly") end
        if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_TreeAmbience") end

    elseif entry.panel == "Page1_V2" or entry.panel == "Page2_V2" then
        if ambianceSFX then ambianceSFX:StopAudioEvent() end
        if owlHootSFX then owlHootSFX:SelectPlayAudioEvent("UI_OwlHoot") end
        if televoiceSFX then
            if entry.panel == "Page1_V2" then
                Audio.SetSwitch("Player_Voice", "Scared", televoiceSFX)
            elseif entry.panel == "Page2_V2" then
                Audio.SetSwitch("Player_Voice", "Generic", televoiceSFX)
            end
            televoiceSFX:SelectPlayAudioEvent("UI_Televocals")
        end

    elseif entry.panel == "Page2_V1" then
        if televoiceSFX then
            Audio.SetSwitch("Player_Voice", "Scared", televoiceSFX)
            televoiceSFX:SelectPlayAudioEvent("UI_Televocals")
        end

    elseif entry.panel == "Page2_V3" then
        if ambianceSFX then ambianceSFX:SelectPlayAudioEvent("SFX_SeaWater") end

    elseif entry.panel == "Page3_V1" then
        if ambianceSFX and not Audio.IsEventPlaying("UI_ThunderStorm") then ambianceSFX:SelectPlayAudioEvent("UI_ThunderStorm") end
        if televoiceSFX then 
            Audio.SetSwitch("Player_Voice", "Scared", televoiceSFX)
            televoiceSFX:SelectPlayAudioEvent("UI_Televocals")
        end

    elseif entry.panel == "Page3_V2" then
        if ambianceSFX and not Audio.IsEventPlaying("UI_ThunderStorm") then ambianceSFX:SelectPlayAudioEvent("UI_ThunderStorm") end

    elseif entry.panel == "Page3_V3" then
        if owlWingSFX then owlWingSFX:SelectPlayAudioEvent("UI_OwlFly") end
        if ambianceSFX and not Audio.IsEventPlaying("UI_ThunderStorm") then ambianceSFX:SelectPlayAudioEvent("UI_ThunderStorm") end
        if televoiceSFX then 
            Audio.SetSwitch("Player_Voice", "Scared", televoiceSFX)
            televoiceSFX:SelectPlayAudioEvent("UI_Televocals")
        end

    else
        if ambianceSFX then ambianceSFX:StopAudioEvent() end
    end
end

local function FindAudioSources(self)
    local pageTurnObj = GameObject.FindInChildren(self.gameObject, "PageTurnSource")
    if pageTurnObj then
        pageTurnSFX = pageTurnObj:GetComponent("Audio Source")
    end

    local owlHootObj = GameObject.FindInChildren(self.gameObject, "OwlHootSource")
    if owlHootObj then
        owlHootSFX = owlHootObj:GetComponent("Audio Source")
    end

    local owlWingObj = GameObject.FindInChildren(self.gameObject, "OwlWingSource")
    if owlWingObj then
        owlWingSFX = owlWingObj:GetComponent("Audio Source")
    end

    local player = GameObject.Find("Player")

    if not player then
        Engine.Log("[Cinematic] Player Not Found")
    else
        local ambianceSource = GameObject.FindInChildren(player, "ItemSource")
        if ambianceSource then
            ambianceSFX = ambianceSource:GetComponent("Audio Source")
        end

        local voiceSource = GameObject.FindInChildren(player, "VoiceSource")
        if voiceSource then
            televoiceSFX = voiceSource:GetComponent("Audio Source")
            if not televoiceSFX then
                Engine.Log("[Cinematic] Unable to retrieve TeleVoice SFX")
            end
        else
            Engine.Log("[Cinematic] Could not find VoiceSource")
        end
    end
end

function Start(self)
    if _G.LoadedFromSave then
        state = "finished"
        initialized = false

        local c = self.gameObject:GetComponent("Canvas")
        if c then c:SetOpacity(0) end

        return
    end

    _G.CinematicActive = true

    Audio.SetMusicState("Vignettes")
    if _G.UpdatePauseState then _G.UpdatePauseState() end

    Game.Pause()

    canvas = self.gameObject:GetComponent("Canvas")

    resetAllPanels()

    show("CinematicFade", true)
    show("CinematicPanel", true)

    FindAudioSources(self)

    state       = "blackin"
    timer       = 0.0
    currentStep = 0
    fadePanel   = nil
    fadePanelT  = 0.0
    initialized = true

    Engine.Log("[Cinematic] Listo")
end

function Update(self, dt)
    if not initialized then return end

    if fadePanel then
        fadePanelT = fadePanelT + math.min(dt, 0.05)
        local alpha = math.min(fadePanelT / PANEL_FADE_DURATION, 1.0)
        setOpacity(fadePanel, alpha)

        if alpha >= 1.0 then fadePanel = nil end
    end

    if state == "done" then
        if ambianceSFX then 
            if ambianceSFX:IsPlaying("UI_ThunderStorm") then ambianceSFX:StopAudioEvent() end
        end
        if timer >= FADE_DURATION then
            if canvas then canvas:SetOpacity(0) end
            _G.CinematicActive = false
            _G._PlayerController_introAnim = true
            if _G.UpdatePauseState then _G.UpdatePauseState() end
            Game.Resume()
            state = "finished"
        end

        timer = timer + math.min(dt, 0.05)
        if Audio.GetMusicState() ~= "Level1_Intro" then
            Audio.SetMusicState("Level1_Intro")
        end
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
            state = "wait"
            currentStep = 1
            loadStep(currentStep)
        end

    elseif state == "wait" then
        local delay = PANEL_FADE_DURATION + self.public.delayBetweenPanels
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
        if timer >= PAGE_BREAK_DURATION then
            timer = 0.0
            show("CinematicFade", false)
            loadStep(currentStep)
            state = "wait"
        end
    end
end
