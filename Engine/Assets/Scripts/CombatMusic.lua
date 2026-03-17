

function Start(self)
	Audio.SetMusicState("Level1")
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") then
		Audio.SetMusicState("Level1_Combat")
    end
end

function OnTriggerExit(self, other)
    if other:CompareTag("Player") then
		Audio.SetMusicState("Level1")
    end
end


