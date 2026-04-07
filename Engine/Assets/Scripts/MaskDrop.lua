public = {
    --Distancia entre player y estatua
    near = 8.0,         
    --Que mascara da
    DropApoloMask = false,
    DropHermesMask = false,
    DropAresMask = false
}

function Start(self)
--Start
end

function Update(self, deltaTime)
    if interact == true then 
        local obj = GameObject.Find("Player")
        local playerPos = obj.transform.position
        local pos = self.transform.worldPosition
        if (math.abs(pos.x - playerPos.x) < self.public.near) then
            if (math.abs(pos.z - playerPos.z) < self.public.near) then  
                if self.public.DropApoloMask then giveApoloMask = true end
                if self.public.DropHermesMask then giveHermesMask = true end
                if self.public.DropAresMask then giveAresMask = true end
            end
        end
    end
end 