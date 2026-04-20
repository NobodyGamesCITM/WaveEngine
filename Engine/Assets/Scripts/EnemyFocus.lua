public = {
    focusDistance = 20.0, -- Distance the camera begins to focus on enemy
    enemyWeight = 0.6     -- 1.0 same as Player it will be on the middle of both
	-- 0.6 will still focus more on Player.
}

local isFocused = false
local cineCam = nil
local player = nil

function Start(self)
    player = GameObject.Find("Player")
    local camObj = GameObject.Find("MainCamera")
    
    if camObj then
        cineCam = camObj:GetComponent("CinematicCamera")
    end
end

function Update(self, dt)
    if not player or not cineCam then return end

    local p1 = self.transform.position
    local p2 = player.transform.position
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    local dist = math.sqrt(dx*dx + dz*dz)

	-- Enter distance
    if dist < self.public.focusDistance and not isFocused then
        cineCam:AddTarget(self.gameObject, self.public.enemyWeight)
        isFocused = true
        Engine.Log("[EnemyFocus] Enemigo en rango: Camara ajustando encuadre!")
        
    -- Exit distance
    elseif dist >= self.public.focusDistance and isFocused then
        cineCam:RemoveTarget(self.gameObject)
        isFocused = false
        Engine.Log("[EnemyFocus] Enemigo fuera de rango: Camara soltando encuadre.")
    end
	
	
	-- Examples
	-- cineCam:AddTarget(self.gameObject, 0.8) on Start to focus on the enemy by lua or any object, like a landmark
	-- cineCam:AddTarget(self.gameObject, 0.3) Landmark
	-- cineCam:RemoveTarget(self.gameObject) When the enemy is dead in the script.
end