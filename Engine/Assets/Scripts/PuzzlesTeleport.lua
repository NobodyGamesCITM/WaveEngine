-- PuzzlesTeleport.lua
public = {
    updateWhenPaused = true
}

local PUZZLES = {
    { 206, 33, -164 },  -- Puzzle 1
    { 132, 44, -292 },  -- Puzzle 2
    { -25, -6, -288 },  -- Puzzle 3
    { 69,   9,  -64 },  -- Puzzle 4
    { 146, 1, -498 }   -- Puzzle 5
}

local Y_OFFSET = 0.5

local playerObj = nil
local cameraObj = nil
local playerRb  = nil

function Start(self)
    Engine.Log("[PuzzlesTeleport] Sistema de TP a Puzzle Inicializado. Uso: SHIFT + P + [1-5]")
end

function Update(self, dt)
    if not (Input.GetKey("LeftShift") or Input.GetKey("RightShift")) then return end
    if not Input.GetKey("P") then return end
    local targetIndex = 0
    if Input.GetKeyDown("F1") then targetIndex = 1
    elseif Input.GetKeyDown("F2") then targetIndex = 2
    elseif Input.GetKeyDown("F3") then targetIndex = 3
    elseif Input.GetKeyDown("F4") then targetIndex = 4
    elseif Input.GetKeyDown("F5") then targetIndex = 5
    else return end

    -- Search of the Player Obj only on the first tp
    if not playerObj then
        playerObj = GameObject.Find("Player")
        if playerObj then
            playerRb = playerObj:GetComponent("Rigidbody")
        end
    end
    
    if not cameraObj then
        cameraObj = GameObject.Find("Camera") 
    end

    if playerObj and cameraObj then
        local pTrans = playerObj.transform
        local cTrans = cameraObj.transform

        -- Extract values
        local px, py, pz = pTrans.position.x, pTrans.position.y, pTrans.position.z
        local cx, cy, cz = cTrans.position.x, cTrans.position.y, cTrans.position.z
        
        -- Offset camera
        local offX, offY, offZ = cx - px, cy - py, cz - pz

        -- Avoid ground clipping on tp
        local destX = PUZZLES[targetIndex][1]
        local destY = PUZZLES[targetIndex][2] + Y_OFFSET
        local destZ = PUZZLES[targetIndex][3]

        -- Set tp to Player
        pTrans:SetPosition(destX, destY, destZ)

        if playerRb then
            playerRb:SetLinearVelocity(0, 0, 0)
        end

        -- Move camera to Player
        cTrans:SetPosition(destX + offX, destY + offY, destZ + offZ)

        Engine.Log("[PuzzlesTeleport] TP al Puzzle " .. targetIndex)
    end
end