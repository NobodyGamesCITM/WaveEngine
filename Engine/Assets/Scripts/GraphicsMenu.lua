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

local pending = {
    resolutionIndex = 1,
    fullScreen = false,
    antiAliasing = false
}

local lastFocusedButton = ""

local function RefreshUI(self, animate)
    local res = RESOLUTIONS[pending.resolutionIndex]
    UI.SetElementText("ResolutionValue", res)
    
    -- Sincronizamos el estado visual de los checkboxes con los valores pendientes
    UI.SetCheckBox("FullScreen",   pending.fullScreen)
    UI.SetCheckBox("AntiAliasing", pending.antiAliasing)

    if animate then
        local canvas = self.gameObject:GetComponent("Canvas")
        if canvas then
            canvas:PlayStoryboard("OnResolutionChanged")
        end
    end
end

local function ApplyChanges(self)
    _G.GraphicsSettings.resolutionIndex = pending.resolutionIndex
    _G.GraphicsSettings.fullScreen      = pending.fullScreen
    _G.GraphicsSettings.antiAliasing    = pending.antiAliasing

    local res = RESOLUTIONS[_G.GraphicsSettings.resolutionIndex]
    local w, h = res:match("(%d+) x (%d+)")
    if w and h then
        Engine.SetResolution(tonumber(w), tonumber(h))
    end

    Engine.SetFullScreen(_G.GraphicsSettings.fullScreen)
    -- Verificamos si la función existe en el motor antes de llamarla
    if Engine.SetAntiAliasing then
        Engine.SetAntiAliasing(_G.GraphicsSettings.antiAliasing)
    end

    Engine.Log("[GraphicsMenu] Applied: " .. res .. ", FullScreen: " .. tostring(_G.GraphicsSettings.fullScreen))
end

function Initialize(self)
    Engine.Log("[GraphicsMenu] Initialize")

    pending.resolutionIndex = _G.GraphicsSettings.resolutionIndex
    pending.fullScreen      = _G.GraphicsSettings.fullScreen
    pending.antiAliasing    = _G.GraphicsSettings.antiAliasing

    RefreshUI(self, false)
    
    -- Recuperamos referencias de audio
    self.selectSource = GameObject.Find("UISelectSound")
    if self.selectSource then self.selectSFX = self.selectSource:GetComponent("Audio Source") end
    self.pressSource = GameObject.Find("UIPressSound")
    if self.pressSource then self.pressSFX = self.pressSource:GetComponent("Audio Source") end
end

function Start(self)
    self.isMenuOpened = false
end

-- ── Update 
function Update(self, dt)
    local currentXAML = _G.CurrentXAML or ""
    local isGraphics = (currentXAML:find("GraphicsMenu.xaml") ~= nil)

    if isGraphics and not self.isMenuOpened then
        self.isMenuOpened = true
        Engine.Log("[GraphicsMenu] Menu opened, initializing UI from global settings...")
        lastFocusedButton = ""
        Initialize(self)
        local canvas = self.gameObject:GetComponent("Canvas")
        if canvas then
            canvas:PlayStoryboard("Intro")
        end
    elseif not isGraphics then
        self.isMenuOpened = false
        return
    end

    -- ── Lógica de flechas de resolución
    local function PrevRes()
        pending.resolutionIndex = pending.resolutionIndex - 1
        if pending.resolutionIndex < 1 then pending.resolutionIndex = #RESOLUTIONS end
        RefreshUI(self, true)
        if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
    end

    local function NextRes()
        pending.resolutionIndex = pending.resolutionIndex + 1
        if pending.resolutionIndex > #RESOLUTIONS then pending.resolutionIndex = 1 end
        RefreshUI(self, true)
        if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
    end

    if UI.WasClicked("ResolutionPrev") then PrevRes() end
    if UI.WasClicked("ResolutionNext") then NextRes() end

    -- ── FULLSCREEN toggle 
    if UI.WasClicked("FullScreen") then
        pending.fullScreen = not pending.fullScreen
        RefreshUI(self, false)
        if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
    end

    -- ── ANTIALIASING toggle
    if UI.WasClicked("AntiAliasing") then
        pending.antiAliasing = not pending.antiAliasing
        RefreshUI(self, false)
        if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
    end

    -- ── APPLY button
    if UI.WasClicked("ApplyButton") then
        ApplyChanges(self)
        if self.pressSFX then self.pressSFX:SelectPlayAudioEvent("UI_ButtonPress") end
    end

    if UI.WasFocused("ResolutionPrev") or UI.WasFocused("ResolutionNext") then
        if Input.GetGamepadButtonDown("Left") then PrevRes()
        elseif Input.GetGamepadButtonDown("Right") then NextRes() end
    end

    local buttons = UI.GetCanvasButtons()
    for _, button in ipairs(buttons) do
        local btnName = tostring(button)
        if UI.WasFocused(btnName) then
            if btnName ~= lastFocusedButton then
                if self.selectSFX then
                    self.selectSFX:SelectPlayAudioEvent("UI_ButtonSelect")
                end
                lastFocusedButton = btnName
            end
        end
    end
end