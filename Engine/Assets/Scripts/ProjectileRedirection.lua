-- ProjectileRedirection.lua

public = {
    dirX           = 0.0,
    dirY           = 0.0,
    dirZ           = 1.0,
    onlyRedirected = false,  -- false: any bullet / true: only already redirected bullets
    doorName       = "",
    fordwardOffset = 0.5,
    heightOffset   = 2.5,
    shootMode      = false,
    shootDelay     = 0.5,
    shootDuration  = 1.0,
    lockRange      = 8.0,    -- rango para mostrar el icono de lock-on
}

-- Lock-on prompt (icono encima de estatuas catalizadoras)
local PROMPT_ROOT     = "LockOnPrompt"
local ICON_KEYBOARD   = "LockOn_Keyboard"
local ICON_GAMEPAD    = "LockOn_Gamepad"
local PROMPT_OFFSET_Y = 50.0
local ICON_W          = 40.0
local ICON_H          = 40.0

local dirX, dirY, dirZ = 0.0, 0.0, 1.0
local onlyRedirected = false
local doorActivated  = false
local anim           = nil
local shooting       = false
local shootTimer     = 0.0
local delaying       = false
local delayTimer     = 0.0
local fireCooldown   = 0.0
local shootParticle  = nil

local lockVisible = false

local function getAnchorPos(self)
    local anchor = GameObject.FindInChildren(self.gameObject, "InteractAnchor")
    if anchor and anchor.transform then
        return anchor.transform.worldPosition
    end
    return self.transform.worldPosition
end

local function updateLockPosition(self)
    local pos = getAnchorPos(self)
    local sx, sy = Camera.WorldToScreen(pos.x, pos.y, pos.z)
    if not sx or not sy then return false end

    local vw, vh = Camera.GetViewportSize()
    if not vw or vw == 0 or not vh or vh == 0 then return false end

    local cx = sx - ICON_W * 0.5 + 0.5
    local cy = sy - ICON_H * 0.5 - PROMPT_OFFSET_Y

    if cx < 0 or cx > vw or cy < 0 or cy > vh then return false end

    UI.SetCanvasPosition(PROMPT_ROOT, cx, cy)
    return true
end

local function showLock(self)
    if not updateLockPosition(self) then
        if lockVisible then
            UI.SetElementVisibility(PROMPT_ROOT, false)
            lockVisible = false
        end
        return
    end

    local isGamepad = (_G.LastInputType == "gamepad")
    UI.SetElementVisibility(ICON_KEYBOARD, not isGamepad)
    UI.SetElementVisibility(ICON_GAMEPAD,  isGamepad)
    UI.SetElementVisibility(PROMPT_ROOT,   true)
    lockVisible = true
end

local function hideLock()
    if not lockVisible then return end
    UI.SetElementVisibility(PROMPT_ROOT, false)
    lockVisible = false
end

function Start(self)
    dirX           = self.public.dirX
    dirY           = self.public.dirY
    dirZ           = self.public.dirZ
    onlyRedirected = self.public.onlyRedirected
    doorName       = self.public.doorName

    anim = self.gameObject:GetComponent("Animation")
    if anim then anim:Play("Idle", 0.0) end

    -- NOTA: las estatuas catalizadoras (shootMode = true) ya NO se registran
    -- como interactuables normales, para que no aparezca el prompt de F/A
    -- (el mismo que cofres/checkpoints). Solo muestran el icono de lock-on.
    -- if self.public.shootMode then
    --     _G.RegisterInteractable(self.gameObject, "redirector_shoot")
    -- end

    local vfx = GameObject.FindInChildren(self.gameObject, "Particle")
    if vfx then shootParticle = vfx:GetComponent("ParticleSystem") end
end

function Update(self, dt)
    -- Lock-on icon (estatuas catalizadoras con shootMode)
    if self.public.shootMode then
        if _G.DialogActive or _G.CinematicActive or _G.PlayerInAnim then
            hideLock()
        else
            local player = _G.PlayerInstance or GameObject.Find("Player")
            if player then
                local myPos = self.transform.worldPosition
                local pPos  = player.transform.worldPosition
                local dx, dy, dz = myPos.x - pPos.x, myPos.y - pPos.y, myPos.z - pPos.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                if dist <= self.public.lockRange then
                    showLock(self)
                else
                    hideLock()
                end
            else
                hideLock()
            end
        end
    end

    if not self.public.shootMode then return end

    if fireCooldown > 0 then fireCooldown = fireCooldown - dt end

    if delaying then
        delayTimer = delayTimer - dt
        if delayTimer <= 0 then
            delaying   = false
            shooting   = true
            shootTimer = self.public.shootDuration
            if anim then anim:Play("Shoot", 0.0) end
        end
        return
    end

    if not shooting then return end

    shootTimer = shootTimer - dt
    if shootTimer > 0 then return end

    shooting     = false
    fireCooldown = 0.5

    if shootParticle then shootParticle:Burst(40) end

    local fwd = self.transform.worldForward
    local rgt = self.transform.worldRight
    local up  = self.transform.worldUp

    local worldX = dirX * rgt.x + dirY * up.x + dirZ * fwd.x
    local worldZ = dirX * rgt.z + dirY * up.z + dirZ * fwd.z

    local len = math.sqrt(worldX * worldX + worldZ * worldZ)
    if len > 0.001 then
        worldX = worldX / len
        worldZ = worldZ / len
    end

    local center = self.transform.worldPosition
    local angle  = math.atan(worldX, worldZ) * (180.0 / math.pi)

    _G.nextBulletData = {
        x             = center.x + worldX * self.public.fordwardOffset,
        y             = center.y + self.public.heightOffset,
        z             = center.z + worldZ * self.public.fordwardOffset,
        dirX          = worldX,
        dirZ          = worldZ,
        angle         = angle,
        wasRedirected = true,
    }

    if anim then anim:Play("Idle", 0.2) end
end

function OnTriggerEnter(self, other)
    if not other:CompareTag("Bullet") then return end
    if shooting or delaying or fireCooldown > 0 then return end

    --Engine.Log("HOLAAA")

    local bulletScript = GameObject.GetScript(other)
    if not bulletScript then
        Engine.Log("[Redirection] ERROR: no script found on bullet")
        return
    end

    if onlyRedirected and not bulletScript.wasRedirected then return end

    if self.public.doorName ~= "" and not doorActivated then
        local door = GameObject.Find(self.public.doorName)
        if not door then
            Engine.Log("[Redirection] ERROR: Door not found")
        else
            local doorScript = GameObject.GetScript(door)
            if not doorScript then
                Engine.Log("[Redirection] ERROR: Script not found")
            else
                Engine.Log("[Redirection] Trying open")
                doorScript:OpenDoor(door)
                doorActivated = true
            end
        end
    end

    if self.public.shootMode then
        bulletScript.pendingHide = true
        delaying   = true
        delayTimer = self.public.shootDelay
    else
        local fwd = self.transform.worldForward
        local rgt = self.transform.worldRight
        local up  = self.transform.worldUp

        local worldX = dirX * rgt.x + dirY * up.x + dirZ * fwd.x
        local worldY = dirX * rgt.y + dirY * up.y + dirZ * fwd.y
        local worldZ = dirX * rgt.z + dirY * up.z + dirZ * fwd.z

        local len = math.sqrt(worldX * worldX + worldY * worldY + worldZ * worldZ)
        if len > 0.001 then
            worldX = worldX / len
            worldY = worldY / len
            worldZ = worldZ / len
        end

        bulletScript.pendingRedirect = { x = worldX, y = worldY, z = worldZ }

        local center = self.transform.worldPosition
        local offset = self.public.fordwardOffset
        bulletScript.pendingPosition = {
            x = center.x + worldX * offset,
            y = center.y + worldY * offset + self.public.heightOffset,
            z = center.z + worldZ * offset
        }
    end
end