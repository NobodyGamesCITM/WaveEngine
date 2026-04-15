local luz = nil
local encendida = true
local timer = 0

function Start()
    luz = GameObject.Find("GameObject"):GetComponent("Light") -- Donde gameobject hay q poner el nombre del gameobj en el q tengas metido la luz
end

-- ejemplo donde cada 1sec se apaga u enciende la luz
function Update()
    timer = timer + Time.GetDeltaTime() 
    if timer >= 1.0 then
        timer = 0
        encendida = not encendida
        luz:SetEnabled(encendida)
    end
end
