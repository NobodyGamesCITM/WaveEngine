--- SceneLoader.lua

public = {
    temp1 = { type = "Scene", value = "" },
    temp2 = { type = "Scene", value = "" }
}

local scenesPath = Engine.GetScenesPath()
local musicSource
local isPlaying = false
local playerInside = false

function Start(self)
	self.gameObject:SetPersistency(1)
	musicSource = self.gameObject:GetComponent("Audio Source")
	Audio.SetMusicState("MainMenu")

	if not isPlaying then
		musicSource:PlayAudioEvent()
		isPlaying = true
	end
end


function Update(self, dt)

	-- Teclas de debug para cambio de escena manual
    if Input.GetKeyDown("1") then
		Audio.SetMusicState("MainMenu")
        Engine.LoadScene(scenesPath, self.public.temp1)
    end

    if Input.GetKeyDown("2") then
		Audio.SetMusicState("Level1")
        Engine.LoadScene(scenesPath, self.public.temp2)
    end

	-- Cambio de escena por trigger + espacio
	if playerInside and Input.GetKeyDown("Space") then
		Audio.SetMusicState("Level1")
		Engine.LoadScene(scenesPath, self.public.temp1)
	end

end


function OnTriggerEnter(self, other)
	if other:CompareTag("Player") then
		playerInside = true
	end
end


function OnTriggerExit(self, other)
	if other:CompareTag("Player") then
		playerInside = false
	end
end





