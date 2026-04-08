-- GridTile.lua

function Start(self)
    -- Checks the next tile on the queue
    if _G.TileSpawnQueue and #_G.TileSpawnQueue > 0 then
        local data = table.remove(_G.TileSpawnQueue, 1)
        
        if data then
            -- SetPos and use the Y of the manager but - 0.02 so its on the floor and dont make visual collision with the Puzzle Entities
            self.transform:SetPosition(data.x, data.y - 0.02, data.z)
            -- Rotate as manager
            self.transform:SetRotation(0, data.rot, 0)
            -- Scale as cellSize
            self.transform:SetScale(data.scale, 1.0, data.scale)
        end
    end
end