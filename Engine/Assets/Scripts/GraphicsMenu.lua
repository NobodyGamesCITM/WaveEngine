local RESOLUTIONS = {
    "1280 x 720",
    "1920 x 1080",
    "2560 x 1440",
    "3840 x 2160",
}

if _G.GraphicsSettings == nil then
    _G.GraphicsSettings = {
        resolutionIndex = 2,  
        fullScreen      = false,
        antiAliasing    = false,
    }
end

local settings = _G.GraphicsSettings

-- ── Helpers 
local function ApplyResolution(self, animate)
    local res = RESOLUTIONS[settings.resolutionIndex]
    UI.SetElementText("ResolutionValue", res)
    Engine.Log("[GraphicsMenu] Resolution -> " .. res)

    local w, h = res:match("(%d+) x (%d+)")
    if w and h then
        Engine.SetResolution(tonumber(w), tonumber(h))
    end

    if animate then
        local canvas = self.gameObject:GetComponent("Canvas")
        if canvas then
            canvas:PlayStoryboard("OnResolutionChanged")
        end
    end
end

local function ApplyFullScreen(self)
    if settings.fullScreen then
        UI.SetCheckBox("FullScreen", true)
        Engine.SetFullScreen(true)
    else
        UI.SetCheckBox("FullScreen", false)
        Engine.SetFullScreen(false)
    end
    Engine.Log("[GraphicsMenu] FullScreen -> " .. tostring(settings.fullScreen))
end

local function ApplyAntiAliasing(self)
    if settings.antiAliasing then
        UI.SetCheckBox("AntiAliasing", true)
        Engine.SetAntiAliasing(true)
    else
        UI.SetCheckBox("AntiAliasing", false)
        Engine.SetAntiAliasing(false)
    end
    Engine.Log("[GraphicsMenu] AntiAliasing -> " .. tostring(settings.antiAliasing))
end

function Initialize(self)
    Engine.Log("[GraphicsMenu] Initialize")

    -- Sin animación al inicializar: evita conflicto con el storyboard Intro
    ApplyResolution(self, false)
    ApplyFullScreen(self)
    ApplyAntiAliasing(self)
end

function Start(self)
    Initialize(self)
    local canvas = self.gameObject:GetComponent("Canvas")
    if canvas then
        canvas:PlayStoryboard("Intro")
    end
end

-- ── Update 
function Update(self, dt)

    if UI.WasClicked("ResolutionPrev") then
        settings.resolutionIndex = settings.resolutionIndex - 1
        if settings.resolutionIndex < 1 then
            settings.resolutionIndex = #RESOLUTIONS
        end
        ApplyResolution(self, true)
        if self.pressSFX then
            self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress")
        end
    end
    if UI.WasClicked("ResolutionNext") then
        settings.resolutionIndex = settings.resolutionIndex + 1
        if settings.resolutionIndex > #RESOLUTIONS then
            settings.resolutionIndex = 1
        end
        ApplyResolution(self, true)
        if self.pressSFX then
            self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress")
        end
    end

    -- ── FULLSCREEN toggle 
    if UI.WasClicked("FullScreen") then
        settings.fullScreen = not settings.fullScreen
        ApplyFullScreen(self)
        if self.pressSFX then
            self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress")
        end
    end

    -- ── ANTIALIASING toggle
    if UI.WasClicked("AntiAliasing") then
        settings.antiAliasing = not settings.antiAliasing
        ApplyAntiAliasing(self)
        if self.pressSFX then
            self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress")
        end
    end

    if UI.WasFocused("ResolutionPrev") or UI.WasFocused("ResolutionNext") then
        if Input.GetGamepadButtonDown("Left") then
            settings.resolutionIndex = settings.resolutionIndex - 1
            if settings.resolutionIndex < 1 then
                settings.resolutionIndex = #RESOLUTIONS
            end
            ApplyResolution(self, true)
        elseif Input.GetGamepadButtonDown("Right") then
            settings.resolutionIndex = settings.resolutionIndex + 1
            if settings.resolutionIndex > #RESOLUTIONS then
                settings.resolutionIndex = 1
            end
            ApplyResolution(self, true)
        end
    end

    -- ── Sons de focus
    local buttons = UI.GetCanvasButtons()
    for _, button in ipairs(buttons) do
        if UI.WasFocused(tostring(button)) then
            if self.selectSFX then
                self.selectSFX:SelectPlayAudioEvent("UI_ButtonSelect")
            end
        end
    end
end