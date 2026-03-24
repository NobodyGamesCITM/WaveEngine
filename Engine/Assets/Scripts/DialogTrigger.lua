
public = {
    sequenceId = "intro" 
}

local triggered = false
function Start(self)
    Engine.Log("[DialogTrigger] Script cargado, sequenceId: " .. tostring(self.public.sequenceId))
end 

function OnTriggerEnter(self, other)
    if triggered then return end
    if other:CompareTag("Player") then
        triggered = true
        _DialogSystem_pendingSequence = self.public.sequenceId
        Engine.Log("[DialogTrigger] Trigger activado: " .. self.public.sequenceId)
    end
end