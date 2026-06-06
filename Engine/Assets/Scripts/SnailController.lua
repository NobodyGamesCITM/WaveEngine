-- Snail Controller Script

local sqrt  = math.sqrt
local atan2 = math.atan
local pi    = math.pi

public = {
    targetName      = "TargetSnail",
    moveSpeed       = 2.0,
    playerName      = "Player",
    activationRange = 25.0,
    stopRange       = 0.2,
}

local target = nil
local player = nil
local arrived = false

local function FindTarget(self)
    target = GameObject.Find(self.public.targetName)
end

local function FindPlayer(self)
    player = GameObject.Find(self.public.playerName)
end

function Start(self)
    FindTarget(self)
    FindPlayer(self)
end

function Update(self, dt)
    if not target or not target.transform then
        FindTarget(self)
        return
    end
    if not player or not player.transform then
        FindPlayer(self)
        return
    end

    if arrived then return end

    local myPos     = self.transform.worldPosition
    local playerPos = player.transform.worldPosition

    local pdx      = playerPos.x - myPos.x
    local pdz      = playerPos.z - myPos.z
    local playerDist = sqrt(pdx * pdx + pdz * pdz)

    if playerDist > self.public.activationRange then return end

    local tPos = target.transform.worldPosition
    local dx   = tPos.x - myPos.x
    local dz   = tPos.z - myPos.z
    local dist = sqrt(dx * dx + dz * dz)

    if dist <= self.public.stopRange then
        arrived = true
        return
    end

    local dirX = dx / dist
    local dirZ = dz / dist

    local angle = atan2(dirX, dirZ) * (180.0 / pi)
    self.transform:SetRotation(0, angle, 0)

    local step = self.public.moveSpeed * dt
    if step > dist then step = dist end

    self.transform:SetPosition(
        myPos.x + dirX * step,
        myPos.y,
        myPos.z + dirZ * step
    )
end