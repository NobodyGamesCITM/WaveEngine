-- WaterColliderController.lua

local waterCollider = nil
local wasHermes     = false

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if not waterCollider then
        return
    end

    waterCollider:Enable()
    wasHermes = false
end

function Update(self, dt)
    if not waterCollider then return end

    local isHermes = (_PlayerController_currentMask == "Hermes")

    if isHermes and not wasHermes then
        waterCollider:Disable()
        wasHermes = true
    elseif not isHermes and wasHermes then
        waterCollider:Enable()
        wasHermes = false
    end
end