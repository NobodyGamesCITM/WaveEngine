public = {
    radius           = 3.0,
    promptRadius     = 6.0,
    sequenceId       = "",
    actionText       = "Interactuar",
    oneShot          = true,
    updateWhenPaused = true,
    promptOffsetY    = 150,  -- pixeles hacia arriba en pantalla, ajusta desde el inspector
}

local ICON_W = 50
local ICON_H = 50

local inPromptRange  = false
local inActionRange  = false
local lastInput      = "keyboard"
local dialogShownMap = {}
local inputCooldown  = 0.0
local COOLDOWN_TIME  = 0.5

local function onAction(self)
    Engine.Log("[InteractTrigger] Action executed: " .. tostring(self.public.sequenceId))
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
end

local function showPrompt(self, canInteract)
    updatePrompt(self)

    local myPos = self.transform.worldPosition
    local sx, sy = Camera.WorldToScreen(myPos.x, myPos.y, myPos.z)

    if sx == nil or sy == nil then
        UI.SetElementVisibility("InteractPrompt", false)
        return
    end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then
        UI.SetElementVisibility("InteractPrompt", false)
        return
    end

    -- Offset en pixeles de pantalla hacia arriba
    local cx = sx - ICON_W * 0.5
    local cy = sy - self.public.promptOffsetY - ICON_H * 0.5

    -- Si sale de pantalla simplemente no se muestra
    if cx < 0 or cx > vw or cy < 0 or cy > vh then
        UI.SetElementVisibility("InteractPrompt", false)
        return
    end

    UI.SetCanvasPosition("InteractPrompt", cx, cy)
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
            Engine.Log("[ERROR] TriggerSequence not registered in _G")
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