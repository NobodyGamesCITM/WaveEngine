-- CombatDoor.lua
public = {
    distance = 5.0,
    speed = 5.0,
    myColision = "Puerta_Final_Colision"
}
local closeDoor = false
local openDoor = false

local rb = nil
local openY = 0.0
local closeY = 0.0
local colisionEnabled = true
local doorSFX = nil
local isMoving = false

local function DisableColision(self) 
    local colision = GameObject.Find(self.public.myColision)
    if colision then
        local Box = colision:GetComponent("Box Collider")
        if Box then 
            Box:Disable() 
            colisionEnabled = false
        end
    end
end

local function EnableColision(self) 
    local colision = GameObject.Find(self.public.myColision)
    if colision then
        local Box = colision:GetComponent("Box Collider")
        if Box then 
            Box:Enable()
            colisionEnabled = true
        end
    end
end

function Start(self)
    self.isClose = false 

    rb = self.gameObject:GetComponent("Rigidbody")
    doorSFX = self.gameObject:GetComponent("Audio Source")

    local startLocalY = self.transform.position.y
    
    local scaleY = self.transform.scale.y
    if scaleY == 0 then scaleY = 1.0 end
    local localTravel = self.public.distance / scaleY

    openY = startLocalY
    closeY = startLocalY + localTravel

    self.CloseDoor = function(self)
        if not self.isClose then closeDoor = true end
        return self.isClose
    end
    self.OpenDoor = function(self)
        if self.isClose then openDoor = true end
        return self.isClose
    end
    
    DisableColision(self)

    self.ForceOpen = function(self)
        self.isClose = false
        closeDoor = false
        openDoor = false
        local p = self.transform.position
        self.transform:SetPosition(p.x, openY, p.z)
        if rb then rb:SetLinearVelocity(0,0,0) end
        if colisionEnabled then DisableColision(self) end
    end
    
    self.ForceClose = function(self)
        self.isClose = true
        closeDoor = false
        openDoor = false
        local p = self.transform.position
        self.transform:SetPosition(p.x, closeY, p.z)
        if rb then rb:SetLinearVelocity(0,0,0) end
        if not colisionEnabled then EnableColision(self) end
    end
end

function Update (self, deltaTime) 
    if not doorSFX then doorSFX = self.gameObject:GetComponent("Audio Source") end

    if closeDoor then 
        local p = self.transform.position
        if not self.isClose then
            if p.y < closeY then 
                rb:SetLinearVelocity(0, self.public.speed, 0)
                if not colisionEnabled then EnableColision(self) end
                if not isMoving then 
                    if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorMove") end
                    isMoving = true
                end
            else 
                self.transform:SetPosition(p.x, closeY, p.z)
                rb:SetLinearVelocity(0, 0, 0)
                if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorStop") end
                closeDoor = false
                self.isClose = true
                isMoving = false
            end
        end
    end

    if openDoor then 
        local p = self.transform.position
        if self.isClose then
            if p.y > openY then
                rb:SetLinearVelocity(0, -self.public.speed, 0)
                if colisionEnabled then DisableColision(self) end
                if not isMoving then 
                    if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorMove") end
                    isMoving = true
                end
            else 
                self.transform:SetPosition(p.x, openY, p.z)
                rb:SetLinearVelocity(0, 0, 0)
                if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorStop") end
                self.isClose = false
                openDoor = false
                isMoving = false
            end
        end
    end
end