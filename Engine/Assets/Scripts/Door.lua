-- Door.lua
public = {
    distance = 10.0,
    speed = 1.0,
    myColision = "Puerta_Sala_1_Colision"
}
local openDoor2 = false
local rb = nil
local initialY = 0.0
local openY = 0.0
local ColisionDisabled = false
local doorSFX = nil
local isMoving = false
local localToWorldRatioY = 1.0

function Start(self)
    self.isOpen = false 

    distance = self.public.distance
    speed = self.public.speed
    rb =  self.gameObject:GetComponent("Rigidbody")
    
    local startLocalY = self.transform.position.y
    local startWorldY = self.transform.worldPosition.y
    self.transform:SetPosition(self.transform.position.x, startLocalY + 1.0, self.transform.position.z)
    local nextWorldY = self.transform.worldPosition.y
    self.transform:SetPosition(self.transform.position.x, startLocalY, self.transform.position.z)
    
    localToWorldRatioY = nextWorldY - startWorldY
    if localToWorldRatioY == 0 then localToWorldRatioY = 1.0 end
    
    local localDistance = distance / localToWorldRatioY

    local p = self.transform.position
    initialY = p.y
    openY = p.y - localDistance

    doorSFX = self.gameObject:GetComponent("Audio Source")

    self.OpenDoor = function(self)
        if not self.isOpen then openDoor2 = true end
        return self.isOpen
    end

    self.ForceOpen = function(self)
        self.isOpen = true
        openDoor2 = false
        local p = self.transform.position
        self.transform:SetPosition(p.x, openY, p.z)
        if rb then rb:SetLinearVelocity(0,0,0) end
        
        local colision = GameObject.Find(self.public.myColision)
        if colision then
            local Box = colision:GetComponent("Box Collider")
            if Box then 
                Box:Disable() 
                ColisionDisabled = true
            end
        end
    end
    
    self.ForceClose = function(self)
        self.isOpen = false
        openDoor2 = false
        local p = self.transform.position
        self.transform:SetPosition(p.x, initialY, p.z)
        if rb then rb:SetLinearVelocity(0,0,0) end
        
        local colision = GameObject.Find(self.public.myColision)
        if colision then
            local Box = colision:GetComponent("Box Collider")
            if Box then 
                Box:Enable()
                ColisionDisabled = false
            end
        end
    end
end

local function DisableColision(self) 
    local colision = GameObject.Find(self.public.myColision)
    if colision then
        local Box = colision:GetComponent("Box Collider")
        if Box then 
            Box:Disable() 
            ColisionDisabled = true
        end
    end
end

function Update (self, deltaTime) 
    if not doorSFX then doorSFX = self.gameObject:GetComponent("Audio Source") end

    if Input.GetKeyDown("F5") then openDoor2 = true end

    if Input.GetKeyDown("F4") then
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position
        local p = self.transform.worldPosition

        if (math.abs(p.x - playerPos.x) < 3) then
            if (math.abs(p.z - playerPos.z) < 3) then openDoor2 = true end
        end 
    end     

    if openDoor2 then 
        local p = self.transform.position
        if not self.isOpen then
            if p.y >= openY then 
                rb:SetLinearVelocity(0, -self.public.speed, 0)
                if not isMoving then 
                    if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorMove") end
                    isMoving = true
                end
            else 
                if not ColisionDisabled then DisableColision(self) end
                rb:SetLinearVelocity(0, 0, 0)
                if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorStop") end
                openDoor2 = false
                self.isOpen = true
                isMoving = false
            end
        end
    end
end