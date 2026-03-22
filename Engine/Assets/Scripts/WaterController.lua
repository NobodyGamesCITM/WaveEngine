-- WaterColliderController.lua

local waterCollider = nil
local wasHermes     = false

function Start(self)
    waterCollider = self.gameObject:GetComponent("Box Collider")
    if waterCollider then waterCollider:Enable() end
end

function Update(self, dt)
    if not waterCollider then return end

    local playerObj = GameObject.Find("Player")
    local pScript = playerObj and playerObj:GetComponent("Script")
    local isHermes = pScript and (pScript.currentMask == "Hermes") or false

    if isHermes and not wasHermes then
        waterCollider:Disable()
        wasHermes = true
    elseif not isHermes and wasHermes then
        waterCollider:Enable()
        wasHermes = false
    end
end