
function Start(self)
    _G.PlayerInMountain = false
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        _G.PlayerInMountain = true
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
        _G.PlayerInMountain = false
    end
end