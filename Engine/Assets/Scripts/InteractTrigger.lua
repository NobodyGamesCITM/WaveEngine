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

local CANVAS_W = 1920
local CANVAS_H = 1080
local PROMPT_W = 220
local PROMPT_H = 50

local function onAction(self)
    Engine.Log("[InteractTrigger] Acción ejecutada: " .. tostring(self.public.sequenceId))
end

local function updatePrompt(self)
    local input = _G.LastInputType or "keyboard"
    local icon = input == "gamepad" and GAMEPAD_ICON or KEYBOARD_ICON
    UI.SetElementText("InputKeyText", icon)
    UI.SetElementText("InteractText", self.public.actionText)
end

local function showPrompt(self, canInteract)
    updatePrompt(self)

    -- Mostrar u ocultar la tecla según si puede interactuar
    if canInteract then
        UI.SetElementVisibility("InputKeyBorder", true)
    else
        UI.SetElementVisibility("InputKeyBorder", false)
    end

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

    local shown = dialogShownMap[self.public.sequenceId] or false

    -- Radio prompt (lejos) - solo muestra el indicador
    if dist < self.public.promptRadius and not inPromptRange then
        inPromptRange = true
    end

    if dist >= self.public.promptRadius and inPromptRange then
        inPromptRange = false
        inActionRange = false
        hidePrompt()
    end

    -- Radio acción (cerca) - permite interactuar
    if dist < self.public.radius and not inActionRange then
        inActionRange = true
    end

    if dist >= self.public.radius and inActionRange then
        inActionRange = false
    end

    -- Actualizar prompt cada frame si está en rango
    if inPromptRange and not _G.DialogActive then
        showPrompt(self, inActionRange)
    end

    -- Input
    if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
        if _G.DialogActive and inputCooldown <= 0 then
            if _G.AdvanceDialog then _G.AdvanceDialog() end
            inputCooldown = COOLDOWN_TIME
        elseif inActionRange and not _G.DialogActive and inputCooldown <= 0 then
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

    if inActionRange and shown and not (_G.DialogActive) and inputCooldown <= 0 then
        showPrompt(self, true)
    end
end