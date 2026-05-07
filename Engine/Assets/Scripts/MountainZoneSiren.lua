
public = {
    PlayerInMountain = false
}

local playerinMountain=nil
function Start(self)
end

function OnTriggerEnter(self, other)
    Engine.Log("playe en pla moñata")
    if other:CompareTag("Player") then
        Engine.Log("playe detectado")
        self.public.PlayerInMountain = true
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        self.public.PlayerInMountain = false
    end
end