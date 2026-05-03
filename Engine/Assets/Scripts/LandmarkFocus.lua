-- LandmarkFocus.lua

public = {
    focusDistance = 20.0, 
    landmarkWeight = 0.3
}

local isFocused = false
local cineCam = nil
local player = nil

function Start(self)
    player = GameObject.Find("Player")
    local camObj = GameObject.Find("MainCamera")
    if camObj then cineCam = camObj:GetComponent("CinematicCamera") end
end

function Update(self, dt)
    if not player or not cineCam or _G.TargetLockManager_IsLocked then return end

    local p1 = self.transform.position
    local p2 = player.transform.position
    
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    local sqrDist = (dx*dx) + (dz*dz)
    local sqrFocusDist = self.public.focusDistance * self.public.focusDistance

    if sqrDist < sqrFocusDist and not isFocused then
        cineCam:AddTarget(self.gameObject, self.public.landmarkWeight)
        isFocused = true
    elseif sqrDist >= sqrFocusDist and isFocused then
        cineCam:RemoveTarget(self.gameObject)
        isFocused = false
    end
    	-- Examples
	-- cineCam:AddTarget(self.gameObject, 0.8) on Start to focus on the enemy by lua or any object, like a landmark
	-- cineCam:AddTarget(self.gameObject, 0.3) Landmark
	-- cineCam:RemoveTarget(self.gameObject) When the enemy is dead in the script.
end