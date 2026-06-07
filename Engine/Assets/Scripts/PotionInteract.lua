--Potion Interact Script 

public = {

    radius = 2.0,
    actionText = "Obtener Poción",
    itemText   = "¡Poción obtenida!",
    --chestAnim  = "Open",
    potionType = "Health", -- "Health" o "Berserk"
    updateWhenPaused = true,  
    meshName = "",
    interactPromptName = "",
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


local function PotionGet(self)
    if _G.PotionSystem and _G.PotionSystem.public then
        local ps = _G.PotionSystem.public
        
        -- Incrementamos tanto el contador actual como el máximo (capacidad)
        if self.public.potionType == "Berserk" then
            ps.berserkCount = (ps.berserkCount or 0) + 1
            ps.maxBerserk = (ps.maxBerserk or 0) + 1
            Engine.Log("[Potion] Poción de Berserk obtenida. Nueva capacidad: " .. ps.maxBerserk)

            -- Mostrar hint la primera vez que se recoge una poción Berserk
            if not _G._FirstBerserkObtained then
                _G._FirstBerserkObtained = true
                if _G.ShowControlsHint then
                    _G.ShowControlsHint("potion_berserk")
                end
            end
        else
            ps.potionCount = (ps.potionCount or 0) + 1
            ps.maxPotions = (ps.maxPotions or 0) + 1
            Engine.Log("[Potion] Poción de Vida obtenida. Nueva capacidad: " .. ps.maxPotions)

            -- Mostrar hint la primera vez que se recoge una poción de Vida
            if not _G._FirstHealthPotionObtained then
                _G._FirstHealthPotionObtained = true
                if _G.ShowControlsHint then
                    _G.ShowControlsHint("potion_health")
                end
            end
        end

        if _G.ForceRefreshHUD then
            _G.ForceRefreshHUD()
        end
    end
    Engine.Log("[Potion] Poción reclamada")
end

local function showPopup(self)
    if _G.ShowItemObtained then
        -- Pasamos potionType como segundo argumento para que ItemObtained
        -- muestre el icono correcto (Pocion.png o Berserk.png)
        _G.ShowItemObtained(
            self.public.itemText,
            self.public.potionType,
            function() PotionGet(self) end
        )
        --hidePrompt(self)

        self.gameObject:SetActive(false)
        --GameObject.Destroy(self.gameObject)
        
    else
        Engine.Log("[Potion] ERROR: _G.ShowItemObtained es nil")
    end
end

local function FindPotionMesh(self)
    --self.meshObj = GameObject.FindInChildren(self.gameObject, tostring(self.public.meshName))
    --if not self.meshObj then Engine.Log("[Potion] Unable to retrieve Mesh Object") end
end

function Initialize(self)
    self.inRange       = false
    self.obtained        = false
    self.inputCooldown = 0.0
    self.waitingPopup  = false
    self.popupTimer    = 0.0
    --self.closed = false
    --self.meshObj = nil

    --FindPotionMesh(self)
    
end


function Start(self)
    
    Initialize(self)
end

function Update(self, dt)

    if not self.inputCooldown then self.inputCooldown = 0.0 end

    --if not self.meshObj then FindPotionMesh(self) end
	
    if self.inputCooldown > 0 then
        self.inputCooldown = self.inputCooldown - dt
    end

    --Engine.Log("[Potion] Is obtainable potion active?: " ..tostring(_G.ItemObtainedActive))
    --Engine.Log("[Potion] Input cooldown = "..tostring(self.inputCooldown))

    --Esperando popup
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
            self.closed = true
            
            --_G.ItemObtainedActive = false
            --Initialize(self)
            
        end
        return
    end


    if self.obtained then return end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition

    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx*dx + dz*dz)

   

    if dist < self.public.radius then
        self.inRange = true
        if not _G.ItemObtainedActive then
            showPrompt(self)
        end
    else
        
            self.inRange = false
            hidePrompt(self)
        
    end

    if self.inRange and not _G.ItemObtainedActive and self.inputCooldown <= 0 and (Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A")) then

        Engine.Log("[Potion] Obteniendo Poción")

        self.obtained = true
        hidePrompt(self)
        self.inputCooldown = COOLDOWN_TIME

        --Lanzar popup con delay
        self.waitingPopup = true
        self.popupTimer   = 0.0
    end



end