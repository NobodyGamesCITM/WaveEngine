-- BULLET CONTROLLER - SIMPLE PROJECTILE

public = {
    speed = 5.0,
    lifetime = 5.0,
    damage = 15.0
}

if _Bullet_PendingDamage == nil then
    _Bullet_PendingDamage = 0
end

local timeAlive = 0
local direction = {x = 0, y = 0, z = 1}
local initialized = false
local rb = nil
local hasHit = false
local pendingDamage = false

function Start(self)
    rb = self.gameObject:GetComponent("Rigidbody")

    if _BulletRegistry == nil then _BulletRegistry = {} end
    bulletId = tostring(self.gameObject) .. tostring(os.clock())
    _BulletRegistry[tostring(self.gameObject)] = bulletId
end

function Update(self, dt)
    if hasHit then
        if pendingDamage then

        end
        self:Destroy()
        return
    end

    if not initialized then
        local data = _G.nextBulletData
        if data and data.x and data.y and data.z then
            _G.nextBulletData = nil
            self.transform:SetPosition(data.x, data.y, data.z)
            self.transform:SetRotation(-90, data.angle or 0, 0)
            local bulletScale = data.scale or 1.0
            self.transform:SetScale(bulletScale, bulletScale, bulletScale)
            direction.x = data.dirX or 0
            direction.y = 0
            direction.z = data.dirZ or 1
            initialized = true
            return
        else
            Engine.Log("[Bullet] WARNING: No spawn data - using defaults")
            initialized = true
        end
    end

    local pos = self.transform.position
    if pos == nil then
        Engine.Log("[Bullet] ERROR: Position is nil")
        return
    end

    local speed   = self.public and self.public.speed   or 20.0
    local lifetime = self.public and self.public.lifetime or 5.0

    local newX = pos.x + direction.x * speed * dt
    local newY = pos.y + direction.y * speed * dt
    local newZ = pos.z + direction.z * speed * dt

    if rb then
        rb:MovePosition(newX, newY, newZ)
    else
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
    if other:CompareTag("Water") or other:CompareTag("Player") or other:CompareTag("Bullet") then return end

    if other:CompareTag("Enemy") then
        if _EnemyPendingDamage == nil then _EnemyPendingDamage = {} end
        _EnemyPendingDamage[other.name] = self.public.damage
    end

    hasHit = true
end