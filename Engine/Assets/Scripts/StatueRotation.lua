public = {
    rotationSpeed = 180.0,  -- speed
    targetDegrees = 90.0 
}

local baseRotX, baseRotY, baseRotZ = 0.0, 0.0, 0.0
local currentOffset = 0.0
local targetOffset  = 0.0

function Start(self)
    local rot = self.transform.rotation
    baseRotX = rot.x
    baseRotY = rot.y
    baseRotZ = rot.z
    currentOffset = 0.0
    targetOffset  = 0.0
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") and _G._PlayerController_lastAttack == "light" then
        targetOffset = targetOffset + self.public.targetDegrees
    end
end

function Update(self, dt)

    if currentOffset ~= targetOffset then
        local step = self.public.rotationSpeed * dt
        local diff = targetOffset - currentOffset

        if math.abs(diff) <= step then
            currentOffset = targetOffset
        else
            currentOffset = currentOffset + (diff > 0 and step or -step)
        end

        self.transform:SetRotation(baseRotX, baseRotY + currentOffset, baseRotZ)
    end
end
