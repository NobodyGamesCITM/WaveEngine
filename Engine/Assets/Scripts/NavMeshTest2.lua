
local atan2  = math.atan
local pi     = math.pi
local sqrt   = math.sqrt
local min    = math.min
local abs    = math.abs

public = {
    moveSpeed      = 10.0,
    rotationSpeed  = 15.0,
    dirSmoothing   = 12.0,   -- más alto = más reactivo, menos suave
    stopSmoothing  = 10.0    -- qué tan rápido frena al llegar
}

-- ─── helpers ───────────────────────────────────────────────────────────────

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

-- ─── lifecycle ─────────────────────────────────────────────────────────────

function Start(self)
    self.nav      = self.gameObject:GetComponent("Navigation")
    self.rb       = self.gameObject:GetComponent("Rigidbody")
    self.currentY = 0
    self.smoothDx = 0
    self.smoothDz = 0

    if self.nav then
        self.nav:SetDestination(0, 0, 0)
    end
end

function Update(self, dt)
    -- Reintentar obtener componentes si faltan
    if not self.nav or not self.rb then
        self.nav      = self.gameObject:GetComponent("Navigation")
        self.rb       = self.gameObject:GetComponent("Rigidbody")
        self.currentY = 0
        self.smoothDx = 0
        self.smoothDz = 0
        if self.nav and self.transform then
            local p = self.transform.position
            self.nav:SetDestination(p.x, p.y, p.z)
        end
        return
    end

    -- ── Input: nuevo destino con Space + clic ─────────────────────────────
    if Input.GetKeyDown("Space") then
        local mX, mY = Input.GetMousePosition()
        if mX then
            local wX, wZ = Camera.GetScreenToWorldPlane(mX, mY, 0)
            if wX then
                Engine.Log("Destino: " .. wX .. ", 0, " .. wZ)
                self.nav:SetDestination(wX, 0, wZ)
            end
        end
    end

    -- ── Movimiento ────────────────────────────────────────────────────────
    local _, vy, _ = self.rb:GetLinearVelocity()
    local isMoving  = self.nav:IsMoving()
    local dx, dz    = self.nav:GetMoveDirection(0.3)

    -- Si nav está en movimiento pero GetMoveDirection devuelve 0
    -- (transición entre waypoints), conservamos la última dirección suavizada
    local hasFreshDir = (dx ~= 0 or dz ~= 0)

    if hasFreshDir then
        -- Normalizar la dirección cruda antes de suavizar
        local mag = sqrt(dx * dx + dz * dz)
        dx = dx / mag
        dz = dz / mag
    end

    if not isMoving then
        -- Frenar suavemente hasta parar
        self.smoothDx = lerp(self.smoothDx, 0, dt * self.public.stopSmoothing)
        self.smoothDz = lerp(self.smoothDz, 0, dt * self.public.stopSmoothing)

        -- Snap a cero cuando sea casi nulo para evitar drift
        if abs(self.smoothDx) < 0.01 and abs(self.smoothDz) < 0.01 then
            self.smoothDx = 0
            self.smoothDz = 0
            self.rb:SetLinearVelocity(0, vy, 0)
            return
        end
    elseif hasFreshDir then
        -- Solo actualizamos la dirección suavizada si tenemos datos frescos
        local t = min(1.0, dt * self.public.dirSmoothing)
        self.smoothDx = self.smoothDx + (dx - self.smoothDx) * t
        self.smoothDz = self.smoothDz + (dz - self.smoothDz) * t
    end
    -- Si isMoving pero !hasFreshDir: mantenemos smoothDx/smoothDz actuales (no frenamos)

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
        local speed = self.public.moveSpeed
        local vFinalX = (self.smoothDx / sMag) * speed
        local vFinalZ = (self.smoothDz / sMag) * speed
        self.rb:SetLinearVelocity(vFinalX, vy, vFinalZ)

        Engine.Log(string.format(
            vFinalX, vFinalZ,
            sqrt(vFinalX * vFinalX + vFinalZ * vFinalZ),
            tostring(isMoving),
            tostring(hasFreshDir)
        ))
    end
end