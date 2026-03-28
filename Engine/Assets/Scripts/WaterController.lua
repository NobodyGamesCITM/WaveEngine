-- WaterColliderController.lua

local waterCollider = nil
local waterGroundCollider = nil
local wasHermes     = false

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if not waterCollider then
        return
    end
    waterCollider:Enable()

    waterGroundCollider = self.gameObject:GetComponent("Convex Collider")
    if not waterGroundCollider then
        return
    end
    waterGroundCollider:Enable()

    wasHermes = false
end

function Update(self, dt)
    if not waterCollider then return end
    if not waterGroundCollider then return end

    local isHermes = (_PlayerController_currentMask == "Hermes")
    local isDead = _G._PlayerController_isDead

    if isHermes and not wasHermes then
        waterCollider:Disable()
        wasHermes = true
    elseif not isHermes and wasHermes then
        waterCollider:Enable()
        wasHermes = false
    end

    if isDead and not wasDrowned then
        waterGroundCollider:Disable()
        wasDrowned = true
    elseif not isDead and wasDrowned then
        waterGroundCollider:Enable()
        wasDrowned = false
    end
end