-- para que funcione hay que pillar el objeto interactuable (ponle por ejemplo una estatua) y meterle a eso el script este. 
--Luego un gameobject empty dentro del interactuable que tenga el nombre anchorName. 
--Lo pones donde quieras y ya te saldra ahi el boton.


--  Icon pack

local Icons = {
    keyboard = {
        Interact = "InputKeyText",
        LockOn   = "LockOn_Keyboard",
    },
    gamepad = {
        Interact = "InputGamepadIcon",
        LockOn   = "LockOn_Gamepad",
    },
    prompt = {
        Interact = "InteractPrompt",
        LockOn   = "LockOnPrompt",
    },
}


--  Config del objeto

public = {
    radius           = 3.0,
    promptRadius     = 6.0,
    sequenceId       = "",
    oneShot          = true,
    updateWhenPaused = true,
    anchorName       = "InteractAnchor",
    action           = "Interact",  -- "Interact" o "LockOn", lockon para enemigos
}

local ICON_W = 50
local ICON_H = 50

local inPromptRange  = false
local inActionRange  = false
local dialogShownMap = {}
local inputCooldown  = 0.0
local COOLDOWN_TIME  = 0.5
local anchorGO       = nil

local function getAnchor(self)
    if anchorGO then return anchorGO end
    anchorGO = GameObject.FindInChildren(self.gameObject, self.public.anchorName)
    if not anchorGO then
        anchorGO = GameObject.Find(self.public.anchorName)
    end
    return anchorGO
end

local function getPromptName(self)
    return Icons.prompt[self.public.action] or "InteractPrompt"
end

local function updatePrompt(self)
    local input  = _G.LastInputType or "keyboard"
    local kbIcon = Icons.keyboard[self.public.action]
    local gpIcon = Icons.gamepad[self.public.action]
    if kbIcon then UI.SetElementVisibility(kbIcon, input ~= "gamepad") end
    if gpIcon then UI.SetElementVisibility(gpIcon, input == "gamepad") end
end

local function showPrompt(self)
    updatePrompt(self)

    local anchor = getAnchor(self)
    local pos    = anchor and anchor.transform.worldPosition
                           or self.transform.worldPosition

    local sx, sy = Camera.WorldToScreen(pos.x, pos.y, pos.z)
    if not sx or not sy then
        UI.SetElementVisibility(getPromptName(self), false)
        return
    end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then
        UI.SetElementVisibility(getPromptName(self), false)
        return
    end

    local cx = sx - ICON_W * 0.5
    local cy = sy - ICON_H * 0.5

    if cx < 0 or cx > vw or cy < 0 or cy > vh then
        UI.SetElementVisibility(getPromptName(self), false)
        return
    end

    UI.SetCanvasPosition(getPromptName(self), cx, cy)
    UI.SetElementVisibility(getPromptName(self), true)
end

local function hidePrompt(self)
    UI.SetElementVisibility(getPromptName(self), false)
end

local function triggerDialog(self)
    local shown = dialogShownMap[self.public.sequenceId] or false
    if not shown then
        if self.public.oneShot then
            dialogShownMap[self.public.sequenceId] = true
        end
        hidePrompt(self)
        inputCooldown = COOLDOWN_TIME
        if _G.TriggerSequence then
            _G.TriggerSequence(self.public.sequenceId)
        else
            Engine.Log("[ERROR] TriggerSequence not registered in _G")
        end
    end
end

function Update(self, dt)
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end

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
        hidePrompt(self)
    end

    if dist < self.public.radius then
        inActionRange = true
    elseif inActionRange then
        inActionRange = false
    end

    if inPromptRange and not _G.DialogActive then
        showPrompt(self)
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