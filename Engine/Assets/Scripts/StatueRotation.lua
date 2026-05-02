public = {
    rotationSpeed = 180.0,  -- speed
    targetDegrees = 90.0 
}

local baseRotX, baseRotY, baseRotZ = 0.0, 0.0, 0.0
local currentOffset = 0.0
local targetOffset  = 0.0
local rotateSFX = nil
local hasTurned = false
local hitCooldown = 0.0

function Start(self)
    local rot = self.transform.rotation
    baseRotX = rot.x
    baseRotY = rot.y
    baseRotZ = rot.z
    currentOffset = 0.0
    targetOffset  = 0.0
	rotateSFX = self.gameObject:GetComponent("Audio Source")

	if not rotateSFX then Engine.Log("[STATUE ROTATION] Could not retrieve Rotate Statue Audio Source") 
	else Engine.Log("[STATUE ROTATION] Rotate Statue Audio Source found!") end
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") and _G._PlayerController_lastAttack == "light" and hitCooldown <= 0.0 then
        targetOffset = targetOffset + self.public.targetDegrees
        hitCooldown = 0.5
    end
end

function Update(self, dt)
	if not turnSFX then
		rotateSFX = self.gameObject:GetComponent("Audio Source")
	end

    if hitCooldown > 0.0 then
        hitCooldown = hitCooldown - dt
    end

    if currentOffset ~= targetOffset then
        if not hasTurned then
            if rotateSFX then rotateSFX:SelectPlayAudioEvent("SFX_StatueTurn") end
            hasTurned = true
        end
        local step = self.public.rotationSpeed * dt
        local diff = targetOffset - currentOffset

        if math.abs(diff) <= step then
            currentOffset = targetOffset
			hasTurned = false
        else
            currentOffset = currentOffset + (diff > 0 and step or -step)
        end

        self.transform:SetRotation(baseRotX, baseRotY + currentOffset, baseRotZ)
    end
end

