public = {
    radius     = 2.0,
    actionText = "Abrir cofre",
    itemText   = "¡Poción obtenida!",
    chestAnim  = "Open",
    potionAnim = "Float",
    potionName = "PotionVisual",
    potionTag = "PotionObtained",
}

local inRange       = false
local opened        = false
local inputCooldown = 0.0
local COOLDOWN_TIME = 0.5
local potionObject  = nil
local CANVAS_W = 1920
local CANVAS_H = 1080
local PROMPT_W = 220
local PROMPT_H = 50
local PotionObt = nil

local function showPrompt(self)
    local myPos = self.transform.worldPosition
    local sx, sy = Camera.WorldToScreen(myPos.x, myPos.y + 1.5, myPos.z)
    if sx == nil or sy == nil then return end

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
        _G.PotionSystem.public.potionCount =
            (_G.PotionSystem.public.potionCount or 0) + 1
        if _G.ForceRefreshHUD then _G.ForceRefreshHUD() end
    end
    Engine.Log("[Chest] Poción añadida")
    if potionObject then
        for i, PotionObtain in ipairs(PotionObt) do
            PotionObtain:SetActive(false)
        end
    end
end

function Start(self)
    potionObject = GameObject.Find(self.public.potionName)
    if potionObject then
        Engine.Log("[Chest] PotionVisual encontrado: " .. tostring(potionObject.name))
    else
        Engine.Log("[Chest] AVISO: no encontrado: " .. tostring(self.public.potionName))
    end
    PotionObt = GameObject.FindByTag(self.public.potionTag)
    Engine.Log("[Chest] ShowItemObtained al Start = " .. tostring(_G.ShowItemObtained))
end

function Update(self, dt)
    if inputCooldown > 0 then
        inputCooldown = inputCooldown - dt
    end

    if _G.ItemObtainedActive and inputCooldown <= 0 then
        Engine.Log("[Chest] ItemObtainedActive=true, esperando F para reclamar")
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            Engine.Log("[Chest] Reclamando poción")
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

    if inRange and (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A"))
       and not (_G.ItemObtainedActive) and inputCooldown <= 0 then

        Engine.Log("[Chest] F pulsado, abriendo cofre")
        Engine.Log("[Chest] ShowItemObtained = " .. tostring(_G.ShowItemObtained))


        

        opened = true
        hidePrompt()
        inputCooldown = COOLDOWN_TIME

        local chestAnimComp = self.gameObject:GetComponent("Animation")
        if chestAnimComp then
            local ok, err = pcall(function() chestAnimComp:Play(self.public.chestAnim, 0.0) end)
            if _G.PlayerInstance then _G.TriggerChestAnimation(_G.PlayerInstance) end
            
            if not ok then Engine.Log("[Chest] ERROR anim cofre: " .. tostring(err)) end
        else
            Engine.Log("[Chest] ERROR: sin Animation en cofre")
        end

        Engine.Log("[Chest] potionObject antes de animar = " .. tostring(potionObject))
        if potionObject then
            potionObject:SetActive(true)
            local potAnimComp = potionObject:GetComponent("Animation")
            Engine.Log("[Chest] potAnimComp = " .. tostring(potAnimComp))
            if potAnimComp then
                local ok, err = pcall(function() potAnimComp:Play(self.public.potionAnim, 0.0) end)
                Engine.Log("[Chest] Anim pocion ok=" .. tostring(ok) .. " err=" .. tostring(err))
            else
                Engine.Log("[Chest] ERROR: sin Animation en PotionVisual")
            end
        else
            Engine.Log("[Chest] ERROR: potionObject es nil al pulsar F")
        end

        if _G.ShowItemObtained then
            _G.ShowItemObtained(
                self.public.itemText,
                nil,
                function() onChestOpened(self) end
            )
        else
            Engine.Log("[Chest] ERROR: _G.ShowItemObtained es nil, ItemObtained no inicializado")
        end
    end
end
