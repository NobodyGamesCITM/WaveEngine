-- WaterColliderController.lua

local waterCollider = nil
local waterGroundCollider = nil
local wasHermes = false
local wasDead = false
local pushFrame = false

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if waterCollider ~= nil then waterCollider:Enable() end

    waterGroundCollider = self.gameObject:GetComponent("Convex Collider")
    if waterGroundCollider ~= nil then waterGroundCollider:Enable() end

    if not waterCollider then Engine.Log("Water collider missing on water gameobject " ..tostring(self.gameObject))

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

    if pushFrame then
        waterCollider:Enable()
        pushFrame = false
    elseif isHermes then
        waterCollider:Disable()
        wasHermes = true
    else
        waterCollider:Enable()
        wasHermes = false
    end

    if isDead then
        waterGroundCollider:Disable()
    else
        waterGroundCollider:Enable()
    end
end