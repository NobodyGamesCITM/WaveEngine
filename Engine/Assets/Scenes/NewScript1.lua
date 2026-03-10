-- Script Template
-- This script is attached to a GameObject
-- Access the GameObject through: self.gameObject
-- Access the Transform through: self.transform

function Start()
    -- Called once when the script is initialized
    Engine.Log("Script Started!")
    
    -- Example: Get initial position
    local pos = self.transform.position
    Engine.Log("Initial Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
end

function Update(deltaTime)
    -- Called every frame
    -- deltaTime = time since last frame in seconds
    
    -- Example: Rotate object
    -- local rot = self.transform.rotation
    -- self.transform:SetRotation(rot.x, rot.y + 90 * deltaTime, rot.z)
    
    -- Example: Move with WASD
    -- local pos = self.transform.position
    -- local speed = 5.0
    -- 
    -- if Input.GetKey("W") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z - speed * deltaTime)
    -- end
    -- if Input.GetKey("S") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z + speed * deltaTime)
    -- end
    -- if Input.GetKey("A") then
    --     self.transform:SetPosition(pos.x - speed * deltaTime, pos.y, pos.z)
    -- end
    -- if Input.GetKey("D") then
    --     self.transform:SetPosition(pos.x + speed * deltaTime, pos.y, pos.z)
    -- end
end
