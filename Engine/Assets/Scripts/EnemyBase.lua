local atan2  = math.atan
local pi     = math.pi
local sqrt   = math.sqrt
local min    = math.min
local abs    = math.abs

public = {
    moveSpeed      = 10.0,
    rotationSpeed  = 15.0,
    dirSmoothing   = 12.0,
    stopSmoothing  = 10.0,
    chaseRange     = 15.0,
    chaseUpdateRate = 0.5,
    attackRange    = 2.0,   -- distancia a la que se detiene frente al player
}

local function lerp(a, b, t)
    t = min(1.0, t)
    return a + (b - a) * t
end

local function shortAngleDiff(a, b)
    local d = b - a
    if d >  180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

function Start(self)
    self.nav      = self.gameObject:GetComponent("Navigation")
    self.rb       = self.gameObject:GetComponent("Rigidbody")
    self.currentY = 0
    self.smoothDx = 0
    self.smoothDz = 0
    self.chaseTimer = 0
    self.playerGO = nil

    if self.nav then
        local rx, ry, rz = self.nav:GetRandomPoint()
        if rx then self.nav:SetDestination(rx, ry, rz) end
    end
end

function Update(self, dt)
    if not self.nav or not self.rb then
        self.nav = self.gameObject:GetComponent("Navigation")
        self.rb  = self.gameObject:GetComponent("Rigidbody")
        self.currentY = 0
        self.smoothDx = 0
        self.smoothDz = 0
        if self.nav and self.transform then
            local p = self.transform.position
            self.nav:SetDestination(p.x, p.y, p.z)
        end
        return
    end

    if not self.playerGO then
        self.playerGO = GameObject.Find("Player")
        if self.playerGO then Engine.Log("Player encontrado") end
    end

    local myPos    = self.transform.position
    local isMoving = self.nav:IsMoving()

    -- ── Persecución / Patrulla ────────────────────────────────────────────
    local chasing  = false
    local blocking = false  -- quieto esperando al player
    if self.playerGO then
        local pp = self.playerGO.transform.position
        if pp then
            local distX = pp.x - myPos.x
            local distZ = pp.z - myPos.z
            local dist  = sqrt(distX * distX + distZ * distZ)

            if dist < self.public.chaseRange then
                chasing = true

                if dist <= self.public.attackRange then
                    -- Está en rango de ataque: pararse y mirar al player
                    blocking = true
                    self.nav:StopMovement()
                else
                    -- Seguir persiguiendo
                    self.chaseTimer = self.chaseTimer - dt
                    if self.chaseTimer <= 0 then
                        self.chaseTimer = self.public.chaseUpdateRate
                        self.nav:SetDestination(pp.x, pp.y, pp.z)
                    end
                end
            end
        end
    end

    -- ── Patrulla random ───────────────────────────────────────────────────
    if not chasing then
        if not isMoving and abs(self.smoothDx) < 0.01 and abs(self.smoothDz) < 0.01 then
            local rx, ry, rz = self.nav:GetRandomPoint()
            if rx then self.nav:SetDestination(rx, ry, rz) end
        end
    end

    -- ── Freno total si está en rango de ataque ────────────────────────────
    if blocking then
        self.smoothDx = 0
        self.smoothDz = 0
        local vel = self.rb:GetLinearVelocity()
        self.rb:SetLinearVelocity(0, vel.y, 0)
        return
    end

    -- ── Movimiento ────────────────────────────────────────────────────────
    local vel  = self.rb:GetLinearVelocity()
    local dx, dz = self.nav:GetMoveDirection(0.3)
    local hasFreshDir = (dx ~= 0 or dz ~= 0)

    if hasFreshDir then
        local mag = sqrt(dx * dx + dz * dz)
        dx = dx / mag
        dz = dz / mag
    end

    if not isMoving then
        self.smoothDx = lerp(self.smoothDx, 0, dt * self.public.stopSmoothing)
        self.smoothDz = lerp(self.smoothDz, 0, dt * self.public.stopSmoothing)

        if abs(self.smoothDx) < 0.01 and abs(self.smoothDz) < 0.01 then
            self.smoothDx = 0
            self.smoothDz = 0
            self.rb:SetLinearVelocity(0, vel.y, 0)
            return
        end
    elseif hasFreshDir then
        local t = min(1.0, dt * self.public.dirSmoothing)
        self.smoothDx = self.smoothDx + (dx - self.smoothDx) * t
        self.smoothDz = self.smoothDz + (dz - self.smoothDz) * t
    end

    -- ── Rotación ──────────────────────────────────────────────────────────
    if self.smoothDx ~= 0 or self.smoothDz ~= 0 then
        local targetAngle = atan2(self.smoothDx, self.smoothDz) * (180.0 / pi)
        local diff = shortAngleDiff(self.currentY, targetAngle)
        self.currentY = self.currentY + diff * self.public.rotationSpeed * dt
        if self.transform then
            self.transform:SetRotation(0, self.currentY, 0)
        end
    end

    -- ── Velocidad ─────────────────────────────────────────────────────────
    local sMag = sqrt(self.smoothDx * self.smoothDx + self.smoothDz * self.smoothDz)
    if sMag > 0.01 then
        local speed   = self.public.moveSpeed
        local vFinalX = (self.smoothDx / sMag) * speed
        local vFinalZ = (self.smoothDz / sMag) * speed
        local pos = self.transform.position
        self.transform:SetPosition(
            pos.x + vFinalX * dt,
            pos.y,
            pos.z + vFinalZ * dt
        )
    end
end