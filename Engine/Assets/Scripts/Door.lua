-- Door.lua
public = {
    isOpen = false,
    distance = 10.0,
    speed = 1
}
function Start(self)
    isOpen = self.public.isOpen 
    distance = self.public.distance
    speed = self.public.speed
    Engine.Log("Start Door")

    rb =  self.gameObject:GetComponent("Rigidbody")

    local p = self.transform.worldPosition
    finalY = p.y - distance
    openDoor2 = false

    self.OpenDoor = function(self)
        openDoor2 = true
    end
end
    
function Update (self, deltaTime) 

    if Input.GetKeyDown("F5") then openDoor2 = true end

    if openDoor2 then 
        local p = self.transform.worldPosition
        if not isOpen then  
            if p.y >= finalY then rb:SetLinearVelocity(0, -1, 0)
            else 
                Engine.Log("---------------------------------------------------------------------")
                Engine.Log("[Door] Bad Gyal, Govana - Open The Door ft. DJ Papis")
                Engine.Log("---------------------------------------------------------------------")
                rb:SetLinearVelocity(0, 0, 0)
                openDoor2 = false
                isOpen =  true
            end
        end
    end
end