public = {
    updateWhenPaused = true,
}

local lastInput = "keyboard"

local KEYBOARD_ICON = "F"

function Start(self)
    UI.SetElementVisibility("InputGamepadIcon", false)
    UI.SetElementVisibility("InputKeyText", true)
    UI.SetElementText("InputKeyText", KEYBOARD_ICON)
end

function Update(self, dt)
    local changed = false

    if Input.GetKeyDown("W") or Input.GetKeyDown("A") or
       Input.GetKeyDown("S") or Input.GetKeyDown("D") or
       Input.GetKeyDown("F") then
        if lastInput ~= "keyboard" then
            lastInput = "keyboard"
            changed = true
        end
    end

    if Input.GetGamepadButtonDown("A") or
       Input.GetGamepadAxis("LeftX") ~= 0 or
       Input.GetGamepadAxis("LeftY") ~= 0 then
        if lastInput ~= "gamepad" then
            lastInput = "gamepad"
            changed = true
        end
    end

    if changed then
        _G.LastInputType = lastInput
        if lastInput == "gamepad" then
            UI.SetElementVisibility("InputKeyText", false)
            UI.SetElementVisibility("InputGamepadIcon", true)
        else
            UI.SetElementVisibility("InputGamepadIcon", false)
            UI.SetElementVisibility("InputKeyText", true)
            UI.SetElementText("InputKeyText", KEYBOARD_ICON)
        end
    end
end