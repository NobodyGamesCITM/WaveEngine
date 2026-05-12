--chest interact script

public = {
    radius     = 2.0,
    actionText = "Abrir cofre",
    itemText   = "¡Poción obtenida!",
    chestAnim  = "Open",
    potionType = "Health", -- "Health" o "Berserk"
    updateWhenPaused = true,  
}

local COOLDOWN_TIME = 0.5
local POPUP_DELAY   = 0.5

local CANVAS_W = 1920
local CANVAS_H = 1080
local PROMPT_W = 220
local PROMPT_H = 50



local function showPrompt(self)
    local myPos = self.transform.worldPosition
    local sx, sy = Camera.WorldToScreen(myPos.x, myPos.y + 1.5, myPos.z)

    if not sx or not sy then return end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then return end

    local cx = (sx / vw) * CANVAS_W
    local cy = (sy / vh) * CANVAS_H

    UI.SetElementMargin("InteractPrompt", cx - PROMPT_W * 0.5, cy - PROMPT_H, 0, 0)
    UI.SetElementVisibility("InteractPrompt", true)
end

local function hidePrompt()
    UI.SetElementVisibility("InteractPrompt", false)
end

local function onChestOpened(self)
    if _G.PotionSystem and _G.PotionSystem.public then
        local ps = _G.PotionSystem.public
        
        -- Incrementamos tanto el contador actual como el máximo (capacidad)
        if self.public.potionType == "Berserk" then
            ps.berserkCount = (ps.berserkCount or 0) + 1
            ps.maxBerserk = (ps.maxBerserk or 0) + 1
            Engine.Log("[Chest] Poción de Berserk obtenida. Nueva capacidad: " .. ps.maxBerserk)
        else
            ps.potionCount = (ps.potionCount or 0) + 1
            ps.maxPotions = (ps.maxPotions or 0) + 1
            Engine.Log("[Chest] Poción de Vida obtenida. Nueva capacidad: " .. ps.maxPotions)
        end

        if _G.ForceRefreshHUD then
            _G.ForceRefreshHUD()
        end
    end
    Engine.Log("[Chest] Poción reclamada")
end

local function showPopup(self)
    if _G.ShowItemObtained then
        _G.ShowItemObtained(
            self.public.itemText,
            nil,
            function() onChestOpened(self) end
        )
    else
        Engine.Log("[Chest] ERROR: _G.ShowItemObtained es nil")
    end
end



function Initialize(self)
    self.inRange       = false
    self.opened        = false
    self.inputCooldown = 0.0
    self.waitingPopup  = false
    self.popupTimer    = 0.0

    self.potionObject = GameObject.FindInChildren(self.gameObject, self.public.potionName or "PotionVisual")
    if self.potionObject then
        self.potionObject:SetActive(false)
    end
end

function Start(self)
    Initialize(self)
    Engine.Log("[Chest] Ready")
end



function Update(self, dt)

    -- Cooldown
	if not self.inputCooldown then self.inputCooldown = 0.0 end
	
    if self.inputCooldown > 0 then
        self.inputCooldown = self.inputCooldown - dt
    end

    -- Esperando popup
    if self.waitingPopup then
        self.popupTimer = self.popupTimer + dt
        if self.popupTimer >= POPUP_DELAY then
            self.waitingPopup = false
            showPopup(self)
        end
        return
    end

    -- Si popup activo (esperando input para cerrarlo)
    if _G.ItemObtainedActive and self.inputCooldown <= 0 then
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            self.inputCooldown = COOLDOWN_TIME
            if _G.HideItemObtained then
                _G.HideItemObtained()
            end
        end
        return
    end

    if self.opened then return end

   

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition

    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

   

    if dist < self.public.radius then
        if not self.inRange then
            self.inRange = true
            showPrompt(self)
        end
    else
        if self.inRange then
            self.inRange = false
            hidePrompt()
        end
    end



    if self.inRange
        and not _G.ItemObtainedActive
        and self.inputCooldown <= 0
        and (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A")) then

        Engine.Log("[Chest] Abriendo cofre")

        self.opened = true
        hidePrompt()
        self.inputCooldown = COOLDOWN_TIME

        -- Animación cofre
        local chestAnimComp = self.gameObject:GetComponent("Animation")
        if chestAnimComp then
            pcall(function()
                chestAnimComp:Play(self.public.chestAnim, 0.0)
            end)
        end

        -- Animación player
        if _G.PlayerInstance and _G.TriggerChestAnimation then
            _G.TriggerChestAnimation(_G.PlayerInstance)
        end

        -- Lanzar popup con delay
        self.waitingPopup = true
        self.popupTimer   = 0.0
    end
end
