
public = {
    radius           = 3.0,
    promptRadius     = 6.0,
    sequenceId       = "",
    actionText       = "Interactuar",
    oneShot          = true,
    updateWhenPaused = true,
}

local inPromptRange  = false
local inActionRange  = false
local lastInput      = "keyboard"
local dialogShownMap = {}
local inputCooldown  = 0.0
local COOLDOWN_TIME  = 0.5

local KEYBOARD_ICON = "F"
local GAMEPAD_ICON  = "ⓐ"

local CANVAS_W = 1280
local CANVAS_H = 720
local PROMPT_W = 220
local PROMPT_H = 50

local function onAction(self)
    Engine.Log("[InteractTrigger] Acción ejecutada: " .. tostring(self.public.sequenceId))
end

local function updatePrompt(self)
    local input = _G.LastInputType or "keyboard"

    if input == "gamepad" then
        UI.SetElementVisibility("InputKeyText",     false)
        UI.SetElementVisibility("InputGamepadIcon", true)
    else
        UI.SetElementVisibility("InputKeyText",     true)
        UI.SetElementVisibility("InputGamepadIcon", false)
    end

    UI.SetElementText("InteractText", self.public.actionText)
end

local function showPrompt(self, canInteract)
    updatePrompt(self)

    UI.SetElementVisibility("InputKeyBorder", canInteract)

    local myPos = self.transform.worldPosition
    local sx, sy = Camera.WorldToScreen(myPos.x, myPos.y + 1.5, myPos.z)

    if sx == nil or sy == nil then
        UI.SetElementVisibility("InteractPrompt", false)
        return
    end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then
        UI.SetElementVisibility("InteractPrompt", false)
        return
    end

    local cx = (sx / vw) * CANVAS_W
    local cy = (sy / vh) * CANVAS_H

    local marginLeft = cx - PROMPT_W * 0.5
    local marginTop  = cy - PROMPT_H

    UI.SetElementMargin("InteractPrompt", marginLeft, marginTop, 0, 0)
    UI.SetElementVisibility("InteractPrompt", true)
end

local function hidePrompt()
    UI.SetElementVisibility("InteractPrompt", false)
end

local function triggerDialog(self)
    local shown = dialogShownMap[self.public.sequenceId] or false
    if not shown then
        if self.public.oneShot then
            dialogShownMap[self.public.sequenceId] = true
        end
        hidePrompt()
        inputCooldown = COOLDOWN_TIME
        if _G.TriggerSequence then
            _G.TriggerSequence(self.public.sequenceId)
        else
            Engine.Log("[ERROR] TriggerSequence no registrado en _G")
        end
    else
        onAction(self)
    end
end

function Update(self, dt)
    if inputCooldown > 0 then
        inputCooldown = inputCooldown - dt
    end

    if Input.GetKeyDown("W") or Input.GetKeyDown("A")
       or Input.GetKeyDown("S") or Input.GetKeyDown("D") then
        lastInput = "keyboard"
        if inPromptRange then updatePrompt(self) end
    end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

  
    if dist < self.public.promptRadius then
        inPromptRange = true
    elseif inPromptRange then
        inPromptRange = false
        inActionRange = false
        hidePrompt()
    end

    if dist < self.public.radius then
        inActionRange = true
    elseif inActionRange then
        inActionRange = false
    end

  
    if inPromptRange and not _G.DialogActive then
        showPrompt(self, inActionRange)
    end

   
    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        if inputCooldown > 0 then return end

        if _G.DialogActive then
            
            if _G.AdvanceDialog then _G.AdvanceDialog() end
            inputCooldown = COOLDOWN_TIME
        elseif inActionRange then
            
            triggerDialog(self)
        end
    end
end
