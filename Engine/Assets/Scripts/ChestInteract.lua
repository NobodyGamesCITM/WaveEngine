public = {
    radius     = 2.0,
    actionText = "Abrir cofre",
    itemText   = "¡Poción obtenida!",
}

local inRange       = false
local opened        = false
local inputCooldown = 0.0
local COOLDOWN_TIME = 0.5

local function showPrompt(self)
    UI.SetElementText("InputKeyText", "F")
    UI.SetElementText("InteractText", self.public.actionText)
    UI.SetElementVisibility("InteractPrompt", true)
end

local function hidePrompt()
    UI.SetElementVisibility("InteractPrompt", false)
end

local function onChestOpened(self)
    if _G.PotionSystem and _G.PotionSystem.public then
        _G.PotionSystem.public.potionCount =
            (_G.PotionSystem.public.potionCount or 0) + 1
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
    end
    if _G.TriggerChestAnimation then
        _G.TriggerChestAnimation()
    end
    Engine.Log("[Chest] Poción añadida")
end

function Update(self, dt)
    if inputCooldown > 0 then
        inputCooldown = inputCooldown - dt
    end

    -- Gestionar cierre del panel desde aquí
    if _G.ItemObtainedActive and inputCooldown <= 0 then
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            inputCooldown = COOLDOWN_TIME
            if _G.HideItemObtained then _G.HideItemObtained() end
        end
        return
    end

    if opened then return end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

    if dist < self.public.radius and not inRange then
        inRange = true
        showPrompt(self)
    end

    if dist >= self.public.radius and inRange then
        inRange = false
        hidePrompt()
    end

    if inRange and Input.GetKeyDown("F") and not (_G.DialogActive)
       and not (_G.ItemObtainedActive) and inputCooldown <= 0 then
        opened = true
        hidePrompt()
        inputCooldown = COOLDOWN_TIME
        if _G.ShowItemObtained then
            _G.ShowItemObtained(
                self.public.itemText,
                nil,
                function() onChestOpened(self) end
            )
        end
    end
end