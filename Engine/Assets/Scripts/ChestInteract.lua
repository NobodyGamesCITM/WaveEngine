public = {
    radius       = 2.0,
    actionText   = "Abrir cofre",
    itemText     = "¡Potion Obtained!",
    chestAnim    = "Open",
    potionType   = "Health",  
    updateWhenPaused = true,
}

local POPUP_DELAY = 0.5

local function onChestOpened(self)
    if _G.PotionSystem and _G.PotionSystem.public then
        local ps = _G.PotionSystem.public
        if self.public.potionType == "Berserk" then
            ps.berserkCount = (ps.berserkCount or 0) + 1
            ps.maxBerserk   = (ps.maxBerserk   or 0) + 1
            Engine.Log("[Chest] Berserk obtenida. Capacidad: " .. ps.maxBerserk)
            if not _G._FirstBerserkObtained then
                _G._FirstBerserkObtained = true
                if _G.ShowControlsHint then _G.ShowControlsHint("potion_berserk") end
            end
        else
            ps.potionCount = (ps.potionCount or 0) + 1
            ps.maxPotions  = (ps.maxPotions  or 0) + 1
            Engine.Log("[Chest] Vida obtenida. Capacidad: " .. ps.maxPotions)
            if not _G._FirstHealthPotionObtained then
                _G._FirstHealthPotionObtained = true
                if _G.ShowControlsHint then _G.ShowControlsHint("potion_health") end
            end
        end
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
    end
end

local function showPopup(self)
    if _G.ShowItemObtained then
        _G.ShowItemObtained(
            self.public.itemText,
            self.public.potionType,
            function() onChestOpened(self) end
        )
    else
        Engine.Log("[Chest] ERROR: _G.ShowItemObtained es nil")
    end
end

local function openChest(self)
    if self.opened then return end

    self.opened = true
    Engine.Log("[Chest] Abriendo cofre")

    _G.UnregisterInteractable(self.gameObject)

    local anim = self.gameObject:GetComponent("Animation")
    if anim then pcall(function() anim:Play(self.public.chestAnim, 0.0) end) end

    if _G.PlayerInstance and _G.TriggerChestAnimation then
        _G.TriggerChestAnimation(_G.PlayerInstance)
    end

    self.waitingPopup = true
    self.popupTimer   = 0.0
end
function Initialize(self)
    self.inRange      = false
    self.opened       = false
    self.waitingPopup = false
    self.popupTimer   = 0.0

    self.potionObject = GameObject.FindInChildren(
        self.gameObject, self.public.potionName or "PotionVisual"
    )
    if self.potionObject then self.potionObject:SetActive(false) end

    -- Registrar callback
    _G._InteractCallbacks = _G._InteractCallbacks or {}
    _G._InteractCallbacks[self.gameObject] = function()
        openChest(self)
    end
end

function Start(self)
    Initialize(self)
    Engine.Log("[Chest] Ready")
end

function Update(self, dt)
    if self.waitingPopup then
        self.popupTimer = self.popupTimer + dt
        if self.popupTimer >= POPUP_DELAY then
            self.waitingPopup = false
            showPopup(self)
        end
        return
    end

    if self.opened then return end

    local player = _G.PlayerInstance or GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx  = myPos.x - playerPos.x
    local dz  = myPos.z - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist < self.public.radius then
        if not self.inRange then
            self.inRange = true
            _G.RegisterInteractable(self.gameObject, "chest")
        end
    else
        if self.inRange then
            self.inRange = false
            _G.UnregisterInteractable(self.gameObject)
        end
    end
end