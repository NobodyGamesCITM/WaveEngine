-- WaterColliderController.lua

local waterCollider = nil
local waterGroundCollider = nil
local wasHermes = false
local wasDead = false
local pushFrame = false

public = {
    isGround = false
}

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if waterCollider ~= nil then waterCollider:Enable() end

    if not waterCollider then Engine.Log("Water collider missing on water gameobject " ..tostring(self.gameObject)) end

    wasHermes = false
    wasDead = false
    pushFrame = false
end

function Update(self, dt)
    local isHermes = (_PlayerController_currentMask == "Hermes")
    local isDead = _G._PlayerController_isDead

    if wasDead and not isDead and isHermes then
        pushFrame = true
    end
    wasDead = isDead

    if not self.public.isGround then
        if pushFrame then
            if waterCollider then waterCollider:Enable() end
            pushFrame = false
        elseif isHermes then
            if waterCollider then waterCollider:Disable() end
            wasHermes = true
        else
            waterCollider:Enable()
            wasHermes = false
        end
    else
        if isDead then
            if waterCollider then waterCollider:Disable() end
        else
            if waterCollider then waterCollider:Enable() end
        end
    end
end