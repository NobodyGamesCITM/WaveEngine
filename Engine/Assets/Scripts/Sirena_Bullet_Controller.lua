-- MortarProjectile.lua
-- Script del prefab del proyectil de mortero.
--
-- NOTA: en este motor, Start() NO se llama automáticamente en prefabs instanciados
-- en runtime. Este script actúa como fallback de seguridad: si por algún motivo
-- el proyectil queda huérfano (el MortarController que lo lanzó muere antes del
-- impacto), este script lo destruye por su cuenta tras MAX_LIFETIME segundos.
--
-- La lógica principal del arco y el daño vive en MortarController.lua.

local MAX_LIFETIME = 8.0   -- segundos máximos antes de auto-destruirse

local age = 0

public = {
    maxLifetime = MAX_LIFETIME,
}

-- Update: contador de seguridad por si el proyectil queda huérfano
function Update(self, dt)
    if not self.gameObject then return end

    age = age + dt

    if age >= self.public.maxLifetime then
        Engine.Log("[MortarProjectile] Auto-destruyendo proyectil huérfano")
        self:Destroy()
    end
end