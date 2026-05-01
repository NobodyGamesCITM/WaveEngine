--Combat Music Script

--_G.InCombat = false
local resetCombatTimer = false
local startedCombat = false
afterCombatTimer = 0.0

public = {
	--currentScene = { type = "Scene", value = "" }
	afterCombatTime =  5.0
}

function _G.TriggerCombatMusic()

	if Audio.GetMusicState()  == "Level1" then 
		Audio.SetMusicState("Level1_Combat")
		startedCombat = true
		
	elseif Audio.GetMusicState() == "Level2" then 
		Audio.SetMusicState("Level2_Combat")
		startedCombat = true
		
	end
	
	resetCombatTimer = true 
end

function _G.TriggerExplorationMusic()

	if Audio.GetMusicState()  == "Level1_Combat" then 
		--Engine.Log("Switching to Level1 Music")
		Audio.SetMusicState("Level1")
		startedCombat = false
		
	elseif Audio.GetMusicState() == "Level2_Combat" then 
		Audio.SetMusicState("Level2")
		--Engine.Log("Switching to Level2 Music")
		startedCombat = false
		
	end

	resetCombatTimer = true 
end


function Start(self)
  	--Engine.Log("CombatMusic.lua script running!")
end

function Update(self, dt)

	if resetCombatTimer then 
		afterCombatTimer = 0
		resetCombatTimer = false
	end

	if _PlayerController_isDead then
		Engine.Log("Player is Dead, going back to Exploration Music")
		_G.TriggerExplorationMusic()
		afterCombatTimer = 0
		resetCombatTimer = false
		startedCombat = false
	end
	

	if startedCombat then
		
		afterCombatTimer = afterCombatTimer + dt

		Engine.Log("Combat Music Started " ..tostring(afterCombatTimer).. " seconds ago")
		if afterCombatTimer >= self.public.afterCombatTime then
			TriggerExplorationMusic()
			afterCombatTimer = 0	
		end
	end

	
end






