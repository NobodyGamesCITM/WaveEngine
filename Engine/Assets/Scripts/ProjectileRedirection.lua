-- ProjectileRedirection.lua

public = {
    dirX           = 0.0,
    dirY           = 0.0,
    dirZ           = 1.0,
    onlyRedirected = false  -- false: any bullet / true: only already redirected bullets
}

local dirX, dirY, dirZ = 0.0, 0.0, 1.0
local onlyRedirected = false

function Start(self)
    dirX           = self.public.dirX
    dirY           = self.public.dirY
    dirZ           = self.public.dirZ
    onlyRedirected = self.public.onlyRedirected
end

function OnTriggerEnter(self, other)
    if not other:CompareTag("Bullet") then return end

    local bulletScript = GameObject.GetScript(other)
    if not bulletScript then
        Engine.Log("[Redirection] ERROR: no script found on bullet")
        return
    end

    if onlyRedirected and not bulletScript.wasRedirected then return end

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
end
