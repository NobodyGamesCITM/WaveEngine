function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
        _PlayerController_pendingDamage = 9999
    end
end
