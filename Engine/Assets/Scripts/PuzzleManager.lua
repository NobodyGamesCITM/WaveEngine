-- PuzzleManager.lua
public = {
    layout = "11111,10001,10201,11111", -- (1=Pared, 0=Suelo, 2=Placa)
    doorName = "Puerta_Sala_1",
    originX = 0.0,
    originZ = 0.0,
    cellSize = 2.0,
    totalPlates = 1
}

local gridLayout = {}
local gridEntities = {}
local platesActivated = 0
local isCompleted = false
local initialized = false

function Start(self)
    Engine.Log("[PuzzleManager] Inicializando Puzzle Manager...")
    
    self.IsReady = function(self) return initialized end

    self.RegisterEntity = function(self, r, c)
        if r < 1 or r > #gridLayout or c < 1 or c > #gridLayout[1] then
            Engine.Log("[PuzzleManager] ERROR: Entity está fuera de los limites ("..r..", "..c..")")
            return false
        end
        if gridLayout[r][c] == 1 then
            Engine.Log("[PuzzleManager] ERROR: Entity registrada dentro de una pared en ("..r..", "..c..")")
        end
        
        gridEntities[r][c] = 1
        return true
    end

    self.RequestMove = function(self, startR, startC, dR, dC)
        if isCompleted then return false, 0, 0 end

        local targetR = startR + dR
        local targetC = startC + dC

        if targetR < 1 or targetR > #gridLayout or targetC < 1 or targetC > #gridLayout[1] then
            Engine.Log("[PuzzleManager] Movimiento bloqueado, fuera del mapa.")
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
    
    initialized = true
    Engine.Log("[PuzzleManager] Ready.")
end