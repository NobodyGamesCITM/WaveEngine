public = {
    slotCount = 6,          -- cuántos slots alrededor
    slotRadius = 2.0,       -- distancia al player
    unreachableRetryTime = 2.0,
}

local slootsTaken = {}
local playerGO = nil

function Start(self)
    playerGO = GameObject.Find("Player")
    
    for i = 1, self.public.slotCount do
        slootsTaken[i] = false
    end

    -- Calcula la posición world de un slot en base al ángulo
    local function GetSlotWorldPos(slotIndex)
        local angle = (2 * math.pi / self.public.slotCount) * (slotIndex - 1)
        local plPos = playerGO.transform.worldPosition
        return {
            x = plPos.x + math.cos(angle) * self.public.slotRadius,
            y = plPos.y,
            z = plPos.z + math.sin(angle) * self.public.slotRadius
        }
    end

    self.ClaimSlot = function(self, enemy)
        for i = 1, self.public.slotCount do
            if slootsTaken[i] == false then
                slootsTaken[i] = enemy
                return { id = i, position = GetSlotWorldPos(i) }
            end
        end
        return nil
    end

    self.ReleaseSlot = function(self, slotId)
        if slotId ~= nil then
            slootsTaken[slotId] = false
        end
    end

    -- Ahora devuelve posición calculada en el momento, no guardada
    self.GetSlotPosition = function(self, slotId)
        if slotId ~= nil then
            return GetSlotWorldPos(slotId)
        end
        return nil
    end

    self.FreeSlotCount = function(self)
        local count = 0
        for i, taken in ipairs(slootsTaken) do
            if taken == false then count = count + 1 end
        end
        return count
    end
end

function Update(self, deltaTime)
end