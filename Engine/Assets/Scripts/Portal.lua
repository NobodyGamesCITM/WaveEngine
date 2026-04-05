local NumEstatuas = 0
local PortalActivado = false

function Start(self)
    EstatuasPortal = GameObject.FindByTag("EstatuaPortal")
    estatuasCogidas = {}

    for i, _ in ipairs(EstatuasPortal) do
        estatuasCogidas[i] = false
        NumEstatuas = i
    end
end

function Update(self, deltaTime)
    local obj = GameObject.Find("Player")
    local playerPos = obj.transform.position

    if interact == true then 
        for i, EstatuaPortal in ipairs(EstatuasPortal) do
            if not estatuasCogidas[i] then
                local pos = EstatuaPortal.transform.worldPosition
                if (math.abs(pos.x - playerPos.x) < 3) then
                    if (math.abs(pos.z - playerPos.z) < 3) then
                        Engine.Log("Estatua Portal taken")
                        NumEstatuas = NumEstatuas - 1
                        estatuasCogidas[i] = true
                    end
                end
            end
        end
    end

    if NumEstatuas == 0 and not PortalActivado then
        Engine.Log("Activar Portal")
        PortalActivado = true
    end
end 

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        if interact and PortalActivado then
            Engine.Log("Portal Enter - Transitioning to Blockout2")
            if _G.TransitionToScene then
                _G.TransitionToScene("Blockout2")
            else
                Engine.LoadScene(Engine.GetScenesPath(), "Blockout2")
            end
        end
    end
end

