local hp = 30
local isDead = false
local alreadyHit  = false
local attackCol   = nil
local attackTimer = 0
local isAttacking = false

local DAMAGE_LIGHT       = 10
local DAMAGE_HEAVY       = 25
local ATTACK_DURATION    = 0.5
local ATTACK_COL_DELAY   = 0.25

_EnemyDamage_skeleton        = 20

public = {
    maxHp          = 30,
    knockbackForce = 5.0,
    attackDamage   = 10,
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
        if len > 0.001 then dx = dx / len; dz = dz / len end
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

    attackCol = self.gameObject:GetComponent("Box Collider")
    if attackCol then 
        attackCol:Disable()
        Engine.Log("[Enemy] Attack collider disabled")
    else
        Engine.Log("[Enemy] ERROR: No attack collider found")
    end
end

function Update(self, dt)
    --DEBUG PROVISIONAL !!!
    if Input.GetKeyDown("0") and not isAttacking then
        isAttacking = true
        attackTimer = 0
        Engine.Log("[Enemy] ATTACKING")
    end

    if isAttacking then
        attackTimer = attackTimer + dt

        if attackTimer >= ATTACK_COL_DELAY and attackCol then
            attackCol:Enable()
        end

        if attackTimer >= ATTACK_DURATION then
            isAttacking = false
            if attackCol then attackCol:Disable() end
            attackTimer = 0
        end
    end
end

function OnTriggerEnter(self, other)
    if isDead then return end

    if other:CompareTag("Player") then
        if not alreadyHit then
            local attack = _PlayerController_lastAttack
            if attack ~= "" then
                alreadyHit = true
                local attackerPos = other.transform.worldPosition
                if attack == "light" then
                    TakeDamage(self, DAMAGE_LIGHT, attackerPos)
                elseif attack == "heavy" then
                    TakeDamage(self, DAMAGE_HEAVY, attackerPos)
                end
            end
        end

        if isAttacking and _PlayerController_pendingDamage == 0 then
            _PlayerController_pendingDamage    = _EnemyDamage_skeleton
            _PlayerController_pendingDamagePos = self.transform.worldPosition
            Engine.Log("[Enemy] HIT PLAYER for " .. tostring(self.public.attackDamage))
        end
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        alreadyHit = false
    end
end