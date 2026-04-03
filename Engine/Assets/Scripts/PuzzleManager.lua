-- PuzzleManager.lua
public = {
    layout = "11111,10001,10201,11111", -- (1=Pared, 0=Suelo, 2=Placa)
    doorName = "Puerta_Sala_1",
    originX = 0.0,
    originZ = 0.0,
    cellSize = 2.0,
    totalPlates = 1,
    
    -- Prefabs on the inspector
    prefab1Way     = { type = "Prefab", value = "" },
    prefab2WayL    = { type = "Prefab", value = "" },
    prefab2WayLine = { type = "Prefab", value = "" },
    prefab3Way     = { type = "Prefab", value = "" },
    prefab4Way     = { type = "Prefab", value = "" },
    prefabPlate    = { type = "Prefab", value = "" }
}

local gridLayout = {}
local gridEntities = {}
local platesActivated = 0
local isCompleted = false
local initialized = false

local function IsPathOrPlate(r, c)
    if not gridLayout[r] then return false end
    local val = gridLayout[r][c]
    if val == nil then return false end
    return (val == 0 or val == 2)
end

local function EvaluateTileVisuals(self, r, c)
    local n = IsPathOrPlate(r - 1, c)
    local s = IsPathOrPlate(r + 1, c)
    local e = IsPathOrPlate(r, c + 1)
    local w = IsPathOrPlate(r, c - 1)

    local count = 0
    if n then count = count + 1 end
    if s then count = count + 1 end
    if e then count = count + 1 end
    if w then count = count + 1 end

    local prefabPath = ""
    local rot = 0

    -- Textures rotation
    if count == 0 or count == 1 then
        prefabPath = self.public.prefab1Way
        if e then rot = 0 end
        if n then rot = 90 end
        if w then rot = 180 end
        if s then rot = -90 end
        
    elseif count == 2 then
        if n and s then 
            prefabPath = self.public.prefab2WayLine
            rot = 90
        elseif e and w then
            prefabPath = self.public.prefab2WayLine
            rot = 0
        elseif n and e then 
            prefabPath = self.public.prefab2WayL
            rot = 0
        elseif n and w then 
            prefabPath = self.public.prefab2WayL
            rot = 90
        elseif s and w then 
            prefabPath = self.public.prefab2WayL
            rot = 180
        elseif s and e then 
            prefabPath = self.public.prefab2WayL
            rot = -90
        end
        
    elseif count == 3 then
        prefabPath = self.public.prefab3Way
        if not s then rot = 0 end -- Lower N, E, W
        if not e then rot = 90 end -- Right N, S, W
        if not n then rot = 180 end -- Upper S, E, W
        if not w then rot = -90 end -- Left N, S, E
        
    elseif count == 4 then
        prefabPath = self.public.prefab4Way
        rot = 0
    end

    if prefabPath == nil or prefabPath == "" then
        prefabPath = self.public.prefab1Way
    end

    return prefabPath, rot
end


function Start(self)
    Engine.Log("[PuzzleManager] Inicializando Puzzle Manager...")
    
    self.IsReady = function(self) return initialized end

    self.RegisterEntity = function(self, r, c)
        if not gridLayout[r] or gridLayout[r][c] == nil then return false end
        gridEntities[r][c] = 1
        return true
    end

    self.RequestMove = function(self, startR, startC, dR, dC)
        if isCompleted then return false, 0, 0 end

        local targetR = startR + dR
        local targetC = startC + dC

        if not gridLayout[targetR] or gridLayout[targetR][targetC] == nil then
            Engine.Log("[PuzzleManager] Movimiento bloqueado, fuera del mapa (nil).")
            return false, 0, 0
        end

        if gridLayout[targetR][targetC] == 1 then
            Engine.Log("[PuzzleManager] Movimiento bloqueado, hay una pared.")
            return false, 0, 0
        end
        
        if gridEntities[targetR][targetC] == 1 then
            Engine.Log("[PuzzleManager] Movimiento bloqueado, hay otro Entity.")
            return false, 0, 0
        end

        gridEntities[startR][startC] = 0
        gridEntities[targetR][targetC] = 1

        if gridLayout[startR][startC] == 2 then
            platesActivated = platesActivated - 1
            Engine.Log("[PuzzleManager] Entity ha salido de la placa. Placas: " .. platesActivated .. "/" .. self.public.totalPlates)
        end

        if gridLayout[targetR][targetC] == 2 then
            platesActivated = platesActivated + 1
            Engine.Log("[PuzzleManager] Entity ha entrado en la placa. Placas: " .. platesActivated .. "/" .. self.public.totalPlates)
            if platesActivated >= self.public.totalPlates then
                self:CompletePuzzle()
            end
        end

        local worldX = self.public.originX + ((targetC - 1) * self.public.cellSize)
        local worldZ = self.public.originZ + ((targetR - 1) * self.public.cellSize)

        return true, worldX, worldZ
    end

    self.CompletePuzzle = function(self)
        isCompleted = true
        Engine.Log("[PuzzleManager] Todas las placas presionadas.")
        local door = GameObject.Find(self.public.doorName)
        if door then
            local doorScript = door:GetComponent("Script")
            if doorScript and doorScript.OpenDoor then
                doorScript:OpenDoor()
            end
        end
    end

    -- Create the layout of the inspector
    local r = 1
    for char in string.gmatch(self.public.layout .. ",", "(.-),") do
        char = string.gsub(char, "%s+", "") 
        if char ~= "" then
            gridLayout[r] = {}
            gridEntities[r] = {}
            for c = 1, #char do
                local val = tonumber(string.sub(char, c, c))
                gridLayout[r][c] = val or 0
                gridEntities[r][c] = 0 
            end
            Engine.Log("[PuzzleManager] Fila " .. r .. " registrada: " .. char)
            r = r + 1
        end
    end
    
    -- Draw the layout with prefabs and rotations
    if _G.TileSpawnQueue == nil then _G.TileSpawnQueue = {} end

    local myY = self.transform.position.y

    for row = 1, #gridLayout do
        for col = 1, #gridLayout[row] do
            local tileVal = gridLayout[row][col]
            -- When we have png and materials of walls we can add them here with the logic
            -- Ground (0), Plate (2)
            if tileVal == 0 or tileVal == 2 then
                local worldX = self.public.originX + ((col - 1) * self.public.cellSize)
                local worldZ = self.public.originZ + ((row - 1) * self.public.cellSize)
                
                local prefabToLoad = ""
                local rotationToApply = 0

                if tileVal == 2 then
                    -- Plate
                    prefabToLoad = self.public.prefabPlate
                else
                    -- If is gorund, check rotation
                    prefabToLoad, rotationToApply = EvaluateTileVisuals(self, row, col)
                end

                -- Set start of the prefab with specific data
                if prefabToLoad and prefabToLoad ~= "" then
                    table.insert(_G.TileSpawnQueue, {
                        x = worldX,
                        y = myY,
                        z = worldZ,
                        rot = rotationToApply,
                        scale = self.public.cellSize
                    })
                    Prefab.Instantiate(prefabToLoad)
                end
            end
        end
    end
    
    initialized = true
    Engine.Log("[PuzzleManager] Ready.")
end