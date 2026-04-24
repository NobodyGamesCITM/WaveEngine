public = {
    radius     = 3.0,
    sequenceId = "intro",
    skipTime   = 5.0,
}

local triggered = false

function Update(self, dt)
    if triggered then return end

    local player = GameObject.Find("Player")
    if not player then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition
    local dx = myPos.x - playerPos.x
    local dz = myPos.z - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist < self.public.radius then
        triggered = true
        if _G.ShowAmbientDialog then
            _G.ShowAmbientDialog(self.public.sequenceId, self.public.skipTime)
        end
    end
end