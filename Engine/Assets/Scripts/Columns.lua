public = {
    matFase1 = "ID_FASE1",
    matFase2 = "ID_FASE2",
    matFase3 = "ID_FASE3",
}

local material = nil
local lastFase = -1

function Start(self)
    material = self.gameObject:GetComponent("Material")
end

function Update(self, dt)

    if _G._Aquiles_ResetColumns then
        lastFase = -1
        _G._Aquiles_ResetColumns = false
    end

    local fase
    if _G._AquilesDefeated or _G._Aquiles_Fase3Active then
        fase = 3
    elseif _G._Aquiles_Fase2Active then
        fase = 2
    else
        fase = 1
    end

    if fase == lastFase then return end
    lastFase = fase

    if not material then return end

    if fase == 1 then
        material.SetTexture(self.public.matFase1)
        Engine.Log("1")
    elseif fase == 2 then
        material.SetTexture(self.public.matFase2)
        Engine.Log("2")
    elseif fase == 3 then
        material.SetTexture(self.public.matFase3)
        Engine.Log("3")

    end
end