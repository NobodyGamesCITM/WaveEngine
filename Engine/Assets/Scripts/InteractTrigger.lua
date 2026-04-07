public = {
    radius           = 3.0,
    sequenceId       = "",
    actionText       = "Interactuar",
    oneShot          = true,
    updateWhenPaused = true,
}

local inRange        = false
local lastInput      = "keyboard"
local dialogShownMap = {}
local inputCooldown  = 0.0
local COOLDOWN_TIME  = 0.5

local KEYBOARD_ICON = "F"
local GAMEPAD_ICON  = "ⓐ"

local function onAction(self)
    Engine.Log("[InteractTrigger] Acción ejecutada: " .. tostring(self.public.sequenceId))
end

local function updatePrompt(self)
    local input = _G.LastInputType or "keyboard"
    local icon = input == "gamepad" and GAMEPAD_ICON or KEYBOARD_ICON
    UI.SetElementText("InputKeyText", icon)
    UI.SetElementText("InteractText", self.public.actionText)
end

local function showPrompt(self)
    updatePrompt(self)
    UI.SetElementVisibility("InteractPrompt", true)
end

local function hidePrompt()
    UI.SetElementVisibility("InteractPrompt", false)
end

function Update(self, dt)
    if inputCooldown > 0 then
        inputCooldown = inputCooldown - dt
    end

    if Input.GetKeyDown("W") or Input.GetKeyDown("A")
       or Input.GetKeyDown("S") or Input.GetKeyDown("D") then
        lastInput = "keyboard"
        if inRange then updatePrompt(self) end
    end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

    local shown = dialogShownMap[self.public.sequenceId] or false

    if dist < self.public.radius and not inRange then
        inRange = true
        showPrompt(self)
    end

    if dist >= self.public.radius and inRange then
        inRange = false
        hidePrompt()
    end

    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        if _G.DialogActive and inputCooldown <= 0 then
            if _G.AdvanceDialog then _G.AdvanceDialog() end
            inputCooldown = COOLDOWN_TIME
        elseif inRange and not _G.DialogActive and inputCooldown <= 0 then
            if not shown then
                if self.public.oneShot then
                    dialogShownMap[self.public.sequenceId] = true
                end
                hidePrompt()
                inputCooldown = COOLDOWN_TIME
                if _G.TriggerSequence then
                    _G.TriggerSequence(self.public.sequenceId)
                else
                    TriggerSequence(self.public.sequenceId)
                end
            else
                onAction(self)
            end
        end
    end

    if inRange and shown and not (_G.DialogActive) and inputCooldown <= 0 then
        showPrompt(self)
    end
end