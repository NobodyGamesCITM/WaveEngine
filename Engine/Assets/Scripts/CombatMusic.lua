function Start(self)
	Audio.SetMusicState("Level1")
end

function OnTriggerEnter(self, other)
    Engine.Log("[Combat Zone] trigger entered by: " .. tostring(other.name))
    if other:CompareTag("Player") then
		Audio.SetMusicState("Level1_Combat")

    end
end

function OnTriggerExit(self, other)

    Engine.Log("[Combat Zone] exited entered by: " .. tostring(other.name))
    if other:CompareTag("Player") then
		Audio.SetMusicState("Level1")

    end
end
