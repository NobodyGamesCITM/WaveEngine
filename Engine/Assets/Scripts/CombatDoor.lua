-- Door.lua
public = {
    distance = 5.0,
    speed = 5.0,
    myColision = "Puerta_Final_Colision"
}
local closeDoor = false
local openDoor = false

local rb = nil
local finalY = 0.0
local isClose = false
local colisionEnabled = true
local doorSFX = nil
local isMoving = false

local function DisableColision(self) 
    local colision = GameObject.Find(self.public.myColision)
    if colision then
        Engine.Log("Door colision found")
        local Box = colision:GetComponent("Box Collider")
        if Box then 
            Box:Disable() 
            colisionEnabled = false
        else Engine.Log("Box not found") end
    else 
        Engine.Log("Door colision not found : " ..tostring(self.public.myColision))
    end
end

function Start(self)

    distance = self.public.distance
    rb =  self.gameObject:GetComponent("Rigidbody")
    local p = self.transform.worldPosition
    finalY = distance

    doorSFX = self.gameObject:GetComponent("Audio Source")
    if not doorSFX then Engine.Log("[DOOR] Could not retrieve Door Audio Source") 
    else Engine.Log("[DOOR] Door Audio Source Found!") end

    self.CloseDoor = function(self)
        if not isClose then closeDoor = true end
        return isClose
    end
    self.OpenDoor = function(self)
        if isClose then 
            openDoor = true 
        end
        return isClose
    end
    
    DisableColision(self) 
end

local function EnableColision(self) 
    local colision = GameObject.Find(self.public.myColision)
    if colision then
        Engine.Log("Door colision found")
        local Box = colision:GetComponent("Box Collider")
        if Box then 
            Box:Enable()
            colisionEnabled = true
        else
            Engine.Log("Box not found")
        end
    else 
        Engine.Log("Door colision not found : " ..tostring(self.public.myColision))
    end
end


function Update (self, deltaTime) 

    if not doorSFX then
        doorSFX = self.gameObject:GetComponent("Audio Source")
    end

    if Input.GetKeyDown("F4") then
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position
        local p = self.transform.worldPosition

        if (math.abs(p.x - playerPos.x) < 3) then
            if (math.abs(p.z - playerPos.z) < 3) then openDoor = true end
        end 
    end     

    if closeDoor then 
        local p = self.transform.worldPosition
        if not isClose then
            if p.y <= finalY then 
                rb:SetLinearVelocity(0, self.public.speed, 0)
                if not colisionEnabled then EnableColision(self) end
                if not isMoving then 
                    if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorMove") end
                    isMoving = true
                end
            else 

                Engine.Log("---------------------------------------------------------------------")
                Engine.Log("[Door] Bad Gyal, Govana - Open The Door ft. DJ Papis")
                Engine.Log("---------------------------------------------------------------------")
                rb:SetLinearVelocity(0, 0, 0)
                if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorStop") end
                closeDoor = false
                isClose =  true
            end
        end
    end

    if  openDoor then 
        Engine.Log("Try open door")
        local p = self.transform.worldPosition
        if isClose then
            if p.y >= -finalY then
                rb:SetLinearVelocity(0, -self.public.speed, 0)
                if colisionEnabled then DisableColision(self) end
                if not isMoving then 
                    if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorMove") end
                    isMoving = true
                end
            else 

                Engine.Log("---------------------------------------------------------------------")
                Engine.Log("[Door] Bad Gyal, Govana - Open The Door ft. DJ Papis")
                Engine.Log("---------------------------------------------------------------------")
                rb:SetLinearVelocity(0, 0, 0)
                if doorSFX then doorSFX:SelectPlayAudioEvent("SFX_DoorStop") end
                isClose =  false
                openDoor = false
            end
        end
    end
end