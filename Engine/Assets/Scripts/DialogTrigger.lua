public = {
    radius     = 3.0,
    sequenceId = "intro",
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
    local dist = math.sqrt(dx*dx + dz*dz)

    if dist < self.public.radius then
        triggered = true
        TriggerSequence(self.public.sequenceId)
        Engine.Log("[DialogTrigger] Activado: " .. self.public.sequenceId)
    end
end