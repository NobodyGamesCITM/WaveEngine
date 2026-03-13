-- EnemyController.lua
--provisional

local hp
local isDead
local alreadyHit = false

local DAMAGE_LIGHT = 10
local DAMAGE_HEAVY = 25

public = {
    maxHp            = 30,
    knockbackForce   = 5.0,
}

local function TakeDamage(self, amount, attackerPos)
    if isDead then return end

    hp = hp - amount
    Engine.Log("[Enemy] HP left: " .. hp .. "/" .. self.public.maxHp)

    _PlayerController_triggerCameraShake = true

    local rb = self.gameObject:GetComponent("Rigidbody")
    if rb and attackerPos then
        local enemyPos = self.transform.worldPosition

        local dx = enemyPos.x - attackerPos.x
        local dz = enemyPos.z - attackerPos.z

        local len = math.sqrt(dx*dx + dz*dz)
        if len > 0.001 then
            dx = dx / len
            dz = dz / len
        end

        rb:AddForce(dx * self.public.knockbackForce, 0, dz * self.public.knockbackForce, 2)
    end

    if hp <= 0 then
        isDead = true
        Engine.Log("[Enemy] DEAD")
        Game.SetTimeScale(0.2)
        _impactFrameTimer = 0.07
        self:Destroy()
    end
end

function Start(self)
    hp         = self.public.maxHp
    isDead     = false
    alreadyHit = false
end

function Update(self, dt)
end

function OnTriggerEnter(self, other)
    if isDead then return end
    if alreadyHit then return end

    if other:CompareTag("Player") then
        local attack = _PlayerController_lastAttack
        if attack == "" then return end

        alreadyHit = true
        local attackerPos = other.transform.worldPosition

        if attack == "light" then
            TakeDamage(self, DAMAGE_LIGHT, attackerPos)
        elseif attack == "heavy" then
            TakeDamage(self, DAMAGE_HEAVY, attackerPos)
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end