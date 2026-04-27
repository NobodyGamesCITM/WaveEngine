--Combat Music Script

-- public = {
-- 	currentScene = { type = "Scene", value = "" }
-- }

function Start(self)
  	--Engine.Log("CombatMusic.lua script running!")
end

function Update(self)
	
end

function OnTriggerEnter(self, other)
    --Engine.Log("[Combat Zone] trigger entered by: " .. tostring(other.name))

    if other:CompareTag("Player") then
		if Audio.GetMusicState() == "Level1" then 
			Audio.SetMusicState("Level1_Combat")
		elseif  Audio.GetMusicState() == "Level2" then
			Audio.SetMusicState("Level2_Combat")
		end
    end
end

function OnTriggerExit(self, other)
    --Engine.Log("[Combat Zone] exited entered by: " .. tostring(other.name))
    if other:CompareTag("Player") then
		if Audio.GetMusicState() == "Level1_Combat" then 
			Audio.SetMusicState("Level1")
		elseif Audio.GetMusicState() == "Level2_Combat" then
			Audio.SetMusicState("Level2")
		end
    end
end



