--  GamepadExample.lua  —  Referencia y test de la API de mando
--
--  Add as a Script component to any GameObject in the scene
--  Will show the info with or without a connected gamepad
--  All output appears in the engine console during Play

public = {
-- seconds between each full state log
    logInterval = 2.0
}

local timer      = 0
local frameCount = 0
-- nil forces the first connection log
local lastHasPad = nil


function Start(self)
    Engine.Log("------------ GamepadExample: Start --------------------------------------------")
    Engine.Log("  Connected gamepads: " .. Input.GetGamepadCount())
    Engine.Log("  HasGamepad:        " .. tostring(Input.HasGamepad()))
    Engine.Log("  Logging state every " .. self.public.logInterval .. "s")
    Engine.Log("  Press any gamepad button to see ButtonDown instantly")
end

function Update(self, dt)
    frameCount = frameCount + 1
    timer      = timer + dt

    local hasPad   = Input.HasGamepad()
    local interval = self.public and self.public.logInterval or 2.0
    -- Detect connection change on any frame
    if hasPad ~= lastHasPad then
        if hasPad then
            Engine.Log("[Gamepad] CONNECTED - total: " .. Input.GetGamepadCount())
        else
            Engine.Log("[Gamepad] DISCONNECTED")
        end
        lastHasPad = hasPad
    end

    if hasPad then
        local buttons = {
            "A","B","X","Y",
            "LB","RB","Start","Back",
            "LeftStick","RightStick",
            "DPadUp","DPadDown","DPadLeft","DPadRight"
        }
        for _, name in ipairs(buttons) do
            if Input.GetGamepadButtonDown(name) then
                Engine.Log("[Gamepad] ButtonDOWN: " .. name)
            end
        end
    end

    -- Full Log
    if timer < interval then return end
    timer = 0

    Engine.Log("--- frame " .. frameCount .. " ------------------------------")
    Engine.Log("  HasGamepad:      " .. tostring(hasPad))
    Engine.Log("  GetGamepadCount: " .. Input.GetGamepadCount())

    -- No gamepad show values either but neutral
    if not hasPad then
        local lx, ly = Input.GetLeftStick()
        Engine.Log("------------ NO GAMEPAD - Default Values --------------------------------------------")
        Engine.Log("  GetLeftStick:       " .. lx .. ", " .. ly)
        Engine.Log("  GetGamepadButton A: " .. tostring(Input.GetGamepadButton("A")))
        Engine.Log("  GetGamepadAxis LT:  " .. Input.GetGamepadAxis("LT"))
        return
    end

    -- WITH GAMEPAD

    -- Sticks
    local lx, ly = Input.GetLeftStick()
    local rx, ry = Input.GetRightStick()
    Engine.Log(string.format("  LeftStick:   %.3f, %.3f", lx, ly))
    Engine.Log(string.format("  RightStick:  %.3f, %.3f", rx, ry))

    -- Individual axes for GetLeftStick and GetRightStick
    Engine.Log(string.format("  LeftX=%.3f  LeftY=%.3f  RightX=%.3f  RightY=%.3f",
        Input.GetGamepadAxis("LeftX"), Input.GetGamepadAxis("LeftY"),
        Input.GetGamepadAxis("RightX"), Input.GetGamepadAxis("RightY")))

    -- Triggers 0 or 1
    Engine.Log(string.format("  LT=%.3f  RT=%.3f",
        Input.GetGamepadAxis("LT"), Input.GetGamepadAxis("RT")))

    -- Held buttons
    Engine.Log("  A="      .. tostring(Input.GetGamepadButton("A"))          ..
               "  B="      .. tostring(Input.GetGamepadButton("B"))          ..
               "  X="      .. tostring(Input.GetGamepadButton("X"))          ..
               "  Y="      .. tostring(Input.GetGamepadButton("Y")))
    Engine.Log("  LB="     .. tostring(Input.GetGamepadButton("LB"))         ..
               "  RB="     .. tostring(Input.GetGamepadButton("RB"))         ..
               "  Start="  .. tostring(Input.GetGamepadButton("Start"))      ..
               "  Back="   .. tostring(Input.GetGamepadButton("Back")))
    Engine.Log("  L3="     .. tostring(Input.GetGamepadButton("LeftStick"))  ..
               "  R3="     .. tostring(Input.GetGamepadButton("RightStick")))
    Engine.Log("  DUp="    .. tostring(Input.GetGamepadButton("DPadUp"))     ..
               "  DDown="  .. tostring(Input.GetGamepadButton("DPadDown"))   ..
               "  DLeft="  .. tostring(Input.GetGamepadButton("DPadLeft"))   ..
               "  DRight=" .. tostring(Input.GetGamepadButton("DPadRight")))

    -- PlayStation
    Engine.Log("  [PS] South=" .. tostring(Input.GetGamepadButton("South")) ..
               "  L1="         .. tostring(Input.GetGamepadButton("L1"))    ..
               "  R1="         .. tostring(Input.GetGamepadButton("R1"))    ..
               "  L2="         .. tostring(Input.GetGamepadAxis("L2"))      ..
               "  R2="         .. tostring(Input.GetGamepadAxis("R2")))

    -- Out of bounds check, prevent crash
    Engine.Log("  [OOB] Button idx99=" .. tostring(Input.GetGamepadButton("A", 99)) ..
               "  Axis idx99="         .. tostring(Input.GetGamepadAxis("LT", 99)))
end

-- VIBRATION

local function checkRumble(self)
    if not Input.HasGamepad() then return end

    -- A - Strong Vibration 300 ms LEFT ENGINE FULL AND RIGHT ENGINE 20%
    if Input.GetGamepadButtonDown("A") then
        Input.RumbleGamepad(1.0, 0.2, 300)
        Engine.Log("[VIBRATION] STRONG (L=1.0 R=0.2 300ms)")
    end

    -- B - Soft Vibration 200 ms LEFT ENGINE 0 AND RIGHT 80%
    if Input.GetGamepadButtonDown("B") then
        Input.RumbleGamepad(0.0, 0.8, 200)
        Engine.Log("[VIBRATION] SOFT (L=0.0 R=0.8 200ms)")
    end

    -- X - Medium Equal Vibration 150 ms BOTH ENGINES 50%
    if Input.GetGamepadButtonDown("X") then
        Input.RumbleGamepad(0.5, 0.5, 150)
        Engine.Log("[VIBRATION] MEDIUM (L=0.5 R=0.5 150ms)")
    end

    -- Y - Stop vibration instantly
    if Input.GetGamepadButtonDown("Y") then
        Input.StopRumble()
        Engine.Log("[VIBRATION] STOPPED")
    end

    -- LT - Vibration is proportional to the % triggered
    local lt = Input.GetGamepadAxis("LT")
    if lt > 0.05 then
        -- Has no duration in ms because is called every frame when the trigger is actioned
        Input.RumbleGamepad(lt * 0.6, lt * 0.4, 32)
    end
end

-- Saved the function in the Original Update and extend with checkRumble
-- is the same as write the function inside the update but is more organised like this
-- Lua can rewrite itself and for us is better visually
local _Update = Update
Update = function(self, dt)
    if Input.HasGamepad() then checkRumble(self) end
    _Update(self, dt)
end