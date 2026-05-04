public = {
    updateWhenPaused   = true,
    delayBetweenPanels = 3.5,
    delayBetweenPages  = 1.0,
}

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

local currentStep = 0
local currentPage = ""
local timer       = 0.0
local state       = "wait"
local initialized = false

local function show(name, visible)
    UI.SetElementVisibility(name, visible)
end

local function loadStep(index)
    if index > #sequence then
        state = "done"
        show("CinematicPanel", false)
        show("CinematicFade", false)
        _G.DialogActive = false
        Game.Resume()
        Engine.Log("[Cinematic] Terminado, gameplay activo")
        return
    end

    local entry   = sequence[index]
    local newPage = entry.page

    if newPage ~= currentPage then
        if currentPage ~= "" then show(currentPage, false) end
        show(newPage, true)
        currentPage = newPage
        Engine.Log("[Cinematic] Página: " .. newPage)
    end

    show(entry.panel, true)
    Engine.Log("[Cinematic] Viñeta: " .. entry.panel)
end

function Start(self)
    Game.Pause()
    _G.DialogActive = true

    for _, e in ipairs(sequence) do show(e.panel, false) end
    show("Page1", false)
    show("Page2", false)
    show("Page3", false)
    show("CinematicFade", false)
    show("CinematicPanel", true)

    state       = "wait"
    timer       = 0.0
    currentStep = 1
    loadStep(currentStep)

    initialized = true
    Engine.Log("[Cinematic] Iniciando")
end

function Update(self, dt)
    if not initialized then return end
    if state == "done" then return end

    _G.DialogActive = true

    local delta = math.min(dt, 0.05)
    timer = timer + delta

    if state == "wait" then
        local nextStep     = currentStep + 1
        local isPageChange = nextStep <= #sequence and
                             sequence[nextStep] ~= nil and
                             sequence[nextStep].page ~= sequence[currentStep].page
        local delay = isPageChange and self.public.delayBetweenPages
                                    or self.public.delayBetweenPanels

        if timer >= delay then
            timer = 0.0
            currentStep = currentStep + 1

            if currentStep <= #sequence and sequence[currentStep].page ~= currentPage then
                show("CinematicFade", true)
                state = "pagebreak"
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
