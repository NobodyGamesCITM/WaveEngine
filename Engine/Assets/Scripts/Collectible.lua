--- Collectible.lua
--- Añade este script a un objeto con Trigger. 
--- Se recoge pulsando la tecla 'X' cuando estás cerca.

public = {
    varName      = "keysCollected",
    amount       = 1.0,
    collectKey   = "X",
}

-- Variables de instancia
local playerInside = false

local function MyOnTriggerEnter(self, other)
    if other and (other.tag == "Player" or other:CompareTag("Player")) then
        playerInside = true
        print("[Collectible] Jugador cerca. Pulsa '" .. (self.public.collectKey or "X") .. "' para recoger.")
    end
end

local function MyOnTriggerExit(self, other)
    if other and (other.tag == "Player" or other:CompareTag("Player")) then
        playerInside = false
    end
end

function Start(self)
    playerInside = false
    -- Inyectamos funciones en la instancia para evitar colisiones globales
    self.OnTriggerEnter = MyOnTriggerEnter
    self.OnTriggerExit = MyOnTriggerExit
end

function Update(self, dt)
    if playerInside then
        local key = self.public.collectKey or "X"
        
        if Input.GetKeyDown(key) then
            -- Acceso seguro a variables publicas
            local pub = self.public or {}
            local vName = pub.varName or "keysCollected"
            local vAmt  = pub.amount or 1.0

            -- Sumar a la variable GLOBAL del juego
            local current = _G[vName] or 0
            _G[vName] = current + vAmt
            
            print("[Collectible] ¡Recogido! Variable '" .. vName .. "' ahora es: " .. tostring(_G[vName]))
            
            -- Borrar el objeto usando el motor
            if GameObject and GameObject.Destroy then
                GameObject.Destroy(self.gameObject)
            else
                self:Destroy() -- Fallback
            end
        end
    end
end
