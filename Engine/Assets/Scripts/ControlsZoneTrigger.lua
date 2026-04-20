public = {
    radius      = 8.0,
    controlsSet = "",
}

local inRange = false
local pendingShow = false

function Update(self, dt)
    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist < self.public.radius and not inRange then
        inRange = true
        pendingShow = true
    end

    if dist >= self.public.radius and inRange then
        inRange = false
        pendingShow = false
        if _G.HideControlsHint then
            _G.HideControlsHint()
        end
    end

    
    if pendingShow and _G.ShowControlsHint then
        _G.ShowControlsHint(self.public.controlsSet)
        pendingShow = false
    end
end