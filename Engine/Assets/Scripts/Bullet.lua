-- BULLET CONTROLLER - SIMPLE PROJECTILE

public = {
    speed = 5.0,
    lifetime = 5.0,
    damage = 15.0
}

local timeAlive = 0
local direction = nil
local initialized = nil
local rb = nil
local hasHit = false
local pendingDamage = false

function Start(self)
    self.direction = { x = 0, y = 0, z = 1 }

    local data = _G.nextBulletData
    if data and data.x and data.y and data.z then
        _G.nextBulletData = nil
        self.transform:SetPosition(data.x, data.y, data.z)
        local s = data.scale or 1.0
        self.transform:SetScale(s, s, s)
        self.direction.x = data.dirX or 0
        self.direction.y = 0
        self.direction.z = data.dirZ or 1
    end

    self.initialized = true
    rb = self.gameObject:GetComponent("Rigidbody")
end

function Update(self, dt)
    if hasHit then
        if pendingDamage then

        end
        self:Destroy()
        return
    end

    if not self.initialized then
        local data = _G.nextBulletData
        if data and data.x and data.y and data.z then
            _G.nextBulletData = nil
            self.transform:SetPosition(data.x, data.y, data.z)
            self.transform:SetRotation(-90, data.angle or 0, 0)
            local bulletScale = data.scale or 1.0
            self.transform:SetScale(bulletScale, bulletScale, bulletScale)

            self.direction.x = data.dirX or 0
            self.direction.y = 0
            self.direction.z = data.dirZ or 1

            self.initialized = true
            self.pendingRedirect = nil
            return
        else
            Engine.Log("[Bullet] WARNING: No spawn data - using defaults")
            self.initialized = true
            self.pendingRedirect = nil
        end
    end

    local pos = self.transform.position
    if pos == nil then
        Engine.Log("[Bullet] ERROR: Position is nil")
        return
    end

    local speed   = self.public and self.public.speed   or 20.0
    local lifetime = self.public and self.public.lifetime or 5.0

    -- Check if a statue has redirected this bullet
    if self.pendingRedirect then
        local r = self.pendingRedirect
        self.direction.x = r.x
        self.direction.y = r.y
        self.direction.z = r.z
        self.pendingRedirect = nil
        self.wasRedirected = true
        if self.pendingPosition then
            local pp = self.pendingPosition
            self.transform:SetPosition(pp.x, pos.y, pp.z)
            self.pendingPosition = nil
        end
        Engine.Log("[Bullet] wasRedirected set to true")
        local p = self.transform.position
        Engine.Log("[Bullet] Redirected at pos: " .. p.x .. ", " .. p.y .. ", " .. p.z)
    end

    if self.rb then
        self.rb:SetLinearVelocity(
            self.direction.x * speed,
            0,
            self.direction.z * speed
        )
    else
        local newX = pos.x + self.direction.x * speed * dt
        local newY = pos.y + self.direction.y * speed * dt
        local newZ = pos.z + self.direction.z * speed * dt
        self.transform:SetPosition(newX, newY, newZ)
    end

    timeAlive = timeAlive + dt
    if timeAlive >= lifetime then
        self:Destroy()
        return
    end
end

function OnTriggerEnter(self, other)
    if hasHit then return end
    if other:CompareTag("Water") or other:CompareTag("Player") or other:CompareTag("Bullet") or other:CompareTag("Statue") then return end

    if other:CompareTag("Enemy") then
        if _EnemyPendingDamage == nil then _EnemyPendingDamage = {} end
        _EnemyPendingDamage[other.name] = self.public.damage
    end

    hasHit = true
    Engine.Log("Hit : " ..tostring(other.name))
end