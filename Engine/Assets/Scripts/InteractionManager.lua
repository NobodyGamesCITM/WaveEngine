public = {
    updateWhenPaused = true,
}

local PROMPT_ROOT    = "InteractPrompt"     
local ICON_KEYBOARD  = "InputKeyText"      
local ICON_GAMEPAD   = "InputGamepadIcon"   

local PROMPT_OFFSET_Y = 50.0
local ICON_W          = 50.0
local ICON_H          = 50.0


local PRIORITY = {
    checkpoint = 1,
    maskstatue = 2,
    keystatue  = 3,
    portal     = 4,
    redirector_shoot = 2, -- Misma prioridad que maskstatue
    chest      = 5,
}

local candidates = {}   
local current    = nil  
local cooldown   = 0.0
local COOLDOWN   = 0.5
local promptVisible = false

local function getPromptAnchorPos(obj)
    local anchor = GameObject.FindInChildren(obj, "InteractAnchor")
    if anchor and anchor.transform then
        return anchor.transform.worldPosition
    end

    local script = GameObject.GetScript(obj)
    if script and script.public and script.public.interactionHeight then
        local pos = obj.transform.worldPosition
        return { x = pos.x, y = pos.y + script.public.interactionHeight, z = pos.z }
    end

    return obj.transform.worldPosition
end

local function updatePromptIcons()
    local isGamepad = (_G.LastInputType == "gamepad")
    UI.SetElementVisibility(ICON_KEYBOARD, not isGamepad)
    UI.SetElementVisibility(ICON_GAMEPAD,  isGamepad)
end

local function movePromptToObj(obj)
    if not obj or not obj.transform then return false end

    local pos = getPromptAnchorPos(obj)
    local sx, sy = Camera.WorldToScreen(pos.x, pos.y, pos.z)
    if not sx or not sy then return false end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then return false end

    local cx = sx - ICON_W * 0.5 + 0.5
    local cy = sy - ICON_H * 0.5 - PROMPT_OFFSET_Y

    if cx < 0 or cx > vw or cy < 0 or cy > vh then
        return false
    end

    UI.SetCanvasPosition(PROMPT_ROOT, cx, cy)
    return true
end

local function showPrompt(obj)
    if not movePromptToObj(obj) then
        UI.SetElementVisibility(PROMPT_ROOT, false)
        promptVisible = false
        return
    end
    updatePromptIcons()
    UI.SetElementVisibility(PROMPT_ROOT, true)
    promptVisible = true
end

local function hidePrompt()
    if not promptVisible then return end
    UI.SetElementVisibility(PROMPT_ROOT,   false)
    UI.SetElementVisibility(ICON_KEYBOARD, false)
    UI.SetElementVisibility(ICON_GAMEPAD,  false)
    promptVisible = false
end

function _G.RegisterInteractable(obj, interactType)
    if not obj then return end
    candidates[obj] = interactType
end

function _G.UnregisterInteractable(obj)
    if not obj then return end
    candidates[obj] = nil
    if current and current.obj == obj then
        current = nil
        hidePrompt()
    end
end

local function pickBest(playerPos)
    local best, bestScore = nil, math.huge
    local MAX_Y_DIFF = 8.0

    for obj, itype in pairs(candidates) do
        if obj and obj.transform then
            local p  = getPromptAnchorPos(obj)
            local dy = math.abs(p.y - playerPos.y)

            if dy < MAX_Y_DIFF then
                local dx   = p.x - playerPos.x
                local dz   = p.z - playerPos.z
                local dist = math.sqrt(dx * dx + dz * dz)
                local score = (PRIORITY[itype] or 99) * 1000 + dist
                if score < bestScore then
                    bestScore = score
                    best = { obj = obj, itype = itype, dist = dist }
                end
            end
        end
    end
    return best
end

function Update(self, dt)
    if cooldown > 0 then cooldown = cooldown - dt end

    local player = _G.PlayerInstance or GameObject.Find("Player")
    if not player then return end

    local prevObj = current and current.obj
    current       = pickBest(player.transform.worldPosition)
    local newObj  = current and current.obj

    if _G.DialogActive or _G.CinematicActive or _G.PlayerInAnim then
        hidePrompt()
    elseif current then
        if newObj ~= prevObj then
            showPrompt(current.obj)
        else
            if not movePromptToObj(current.obj) then
                UI.SetElementVisibility(PROMPT_ROOT, false)
                promptVisible = false
            elseif not promptVisible then
                updatePromptIcons()
                UI.SetElementVisibility(PROMPT_ROOT, true)
                promptVisible = true
            else
                updatePromptIcons()
            end
        end
    else
        if prevObj ~= nil then hidePrompt() end
    end

    if cooldown > 0 then return end
    if not (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A")) then return end

    cooldown = COOLDOWN

    if _G.DialogActive then
        if _G.AdvanceDialog then _G.AdvanceDialog() end
        return
    end

    if _G.ItemObtainedActive then
        if _G.HideItemObtained then _G.HideItemObtained() end
        return
    end

    if _G._IsMaskActive then return end

    if not current then return end

    local cb = _G._InteractCallbacks and _G._InteractCallbacks[current.obj]
    if cb then cb() end
end