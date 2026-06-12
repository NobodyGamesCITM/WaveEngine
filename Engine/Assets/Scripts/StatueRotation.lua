public = {
    rotationSpeed = 180.0,
    targetDegrees = 90.0,
    promptRadius  = 5.0,
}

local PROMPT_ROOT     = "StatuePrompt"
local ICON_KEYBOARD   = "Statue_Keyboard"
local ICON_GAMEPAD    = "Statue_Gamepad"
local ICON_W          = 50.0
local ICON_H          = 50.0
local PROMPT_OFFSET_Y = 80.0

local baseRotX, baseRotY, baseRotZ = 0.0, 0.0, 0.0
local currentOffset = 0.0
local targetOffset  = 0.0
local rotateSFX     = nil
local hasTurned     = false
local hitCooldown   = 0.0
local inRange       = false

local function getPromptAnchorPos(self)
    local anchor = GameObject.FindInChildren(self.gameObject, "InteractAnchor")
    if anchor and anchor.transform then
        return anchor.transform.worldPosition
    end

    if self.public and self.public.interactionHeight then
        local pos = self.transform.worldPosition
        return { x = pos.x, y = pos.y + self.public.interactionHeight, z = pos.z }
    end

    return self.transform.worldPosition
end

local function updatePromptPosition(self)
    local pos = getPromptAnchorPos(self)
    local sx, sy = Camera.WorldToScreen(pos.x, pos.y, pos.z)
    if not sx or not sy then return false end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 then return false end

    local cx = sx - ICON_W * 0.5 + 5.0
    local cy = sy - ICON_H * 0.5 - PROMPT_OFFSET_Y

    if cx < 0 or cx > vw or cy < 0 or cy > vh then return false end

    UI.SetCanvasPosition(PROMPT_ROOT, cx, cy)
    return true
end

local function showPrompt(self)
    if not updatePromptPosition(self) then return end
    local isGamepad = (_G.LastInputType == "gamepad")
    UI.SetElementVisibility(ICON_KEYBOARD, not isGamepad)
    UI.SetElementVisibility(ICON_GAMEPAD,  isGamepad)
    UI.SetElementVisibility(PROMPT_ROOT,   true)
end

local function hidePrompt()
    UI.SetElementVisibility(PROMPT_ROOT,   false)
    UI.SetElementVisibility(ICON_KEYBOARD, false)
    UI.SetElementVisibility(ICON_GAMEPAD,  false)
end

function Start(self)
    local rot = self.transform.rotation
    baseRotX = rot.x
    baseRotY = rot.y
    baseRotZ = rot.z
    currentOffset = 0.0
    targetOffset  = 0.0
    rotateSFX = self.gameObject:GetComponent("Audio Source")
    print("Estatua inicializada correctamente.")
end

function Update(self, dt)
    -- Re-find audio si se pierde
    if not rotateSFX then
        rotateSFX = self.gameObject:GetComponent("Audio Source")
    end

    if hitCooldown > 0.0 then
        hitCooldown = hitCooldown - dt
    end

    local player = _G.PlayerInstance or GameObject.Find("Player")
    if player then
        local myPos     = self.transform.worldPosition
        local playerPos = player.transform.worldPosition
        local dx   = myPos.x - playerPos.x
        local dz   = myPos.z - playerPos.z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist < self.public.promptRadius then
            if not inRange then inRange = true end
            
            -- UI Prompt
            if not _G.DialogActive and not _G.CinematicActive then
                showPrompt(self)
            else
                hidePrompt()
            end

            -- DETECCIÓN DEL GOLPE (reemplaza a los Triggers)
            if _G._PlayerController_lastAttack == "light" and hitCooldown <= 0.0 then
                print("¡Golpe detectado! Rotando 90° a la derecha.")
                targetOffset = targetOffset - self.public.targetDegrees -- El signo '-' rota a la derecha
                hitCooldown  = 0.6 -- Cooldown para evitar que gire sin parar durante la animación
            end
        else
            if inRange then
                inRange = false
                hidePrompt()
            end
        end
    end

    -- Lógica de interpolación de la rotación
    if currentOffset ~= targetOffset then
        if not hasTurned then
            if rotateSFX then rotateSFX:SelectPlayAudioEvent("SFX_StatueTurn") end
            hasTurned = true
        end

        local step = self.public.rotationSpeed * dt
        local diff = targetOffset - currentOffset

        if math.abs(diff) <= step then
            currentOffset = targetOffset
            hasTurned     = false 
        else
            currentOffset = currentOffset + (diff > 0 and step or -step)
        end

        self.transform:SetRotation(baseRotX, baseRotY + currentOffset, baseRotZ)
    end
end