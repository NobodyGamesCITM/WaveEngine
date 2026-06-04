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
}

local dirX, dirY, dirZ = 0.0, 0.0, 1.0
local onlyRedirected = false
local doorActivated  = false
local anim           = nil
local shooting       = false
local shootTimer     = 0.0
local delaying       = false
local delayTimer     = 0.0
local fireCooldown   = 0.0

function Start(self)
    dirX           = self.public.dirX
    dirY           = self.public.dirY
    dirZ           = self.public.dirZ
    onlyRedirected = self.public.onlyRedirected
    doorName       = self.public.doorName

    anim = self.gameObject:GetComponent("Animation")
    if anim then anim:Play("Idle", 0.0) end
end

function Update(self, dt)
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
