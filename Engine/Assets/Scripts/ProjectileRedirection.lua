-- ProjectileRedirection.lua

public = {
    dirX           = 0.0,
    dirY           = 0.0,
    dirZ           = 1.0,
    onlyRedirected = false,  -- false: any bullet / true: only already redirected bullets
    doorName       = "",
    fordwardOffset     = 1.0
}

local dirX, dirY, dirZ = 0.0, 0.0, 1.0
local onlyRedirected = false
local doorActivated  = false

function Start(self)
    dirX           = self.public.dirX
    dirY           = self.public.dirY
    dirZ           = self.public.dirZ
    onlyRedirected = self.public.onlyRedirected
    doorName       = self.public.doorName
end

function OnTriggerEnter(self, other)
    if not other:CompareTag("Bullet") then return end

    Engine.Log("HOLAAA")

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

    local center  = self.transform.worldPosition
    local offset  = self.public.fordwardOffset
    bulletScript.pendingPosition = {
        x = center.x + worldX * offset,
        y = center.y + worldY * offset,
        z = center.z + worldZ * offset
    }

end
