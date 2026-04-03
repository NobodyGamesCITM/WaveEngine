-- WaterColliderController.lua

local waterCollider = nil
local waterGroundCollider = nil
local wasHermes     = false

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if waterCollider ~= nil then waterCollider:Enable() end

    waterGroundCollider = self.gameObject:GetComponent("Convex Collider")
    if waterGroundCollider ~= nil then waterGroundCollider:Enable() end

    wasHermes = false
end

function Update(self, dt)
    --Engine.Log("[Player] MASK: " .. tostring(_PlayerController_currentMask))
    local isHermes = (_PlayerController_currentMask == "Hermes")
    local isDead = _G._PlayerController_isDead

    if isHermes and not wasHermes then
        waterCollider:Disable()
        wasHermes = true
    elseif not isHermes and wasHermes then
        waterCollider:Enable()
        wasHermes = false
    end

    if isDead then
        waterGroundCollider:Disable()
        wasDrowned = true
    elseif not isDead then
        waterGroundCollider:Enable()
        wasDrowned = false
    end
end