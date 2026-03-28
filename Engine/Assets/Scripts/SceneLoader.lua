-- SceneLoader.lua

public = {
    temp1 = { type = "Scene", value = "" },
    temp2 = { type = "Scene", value = "" }
}

local scenesPath = Engine.GetScenesPath()
--local musicSource
--local isPlaying = false

function Start(self)
	--self.gameObject:SetPersistency(1)
	--musicSource = self.gameObject:GetComponent("Audio Source")
	--Audio.SetMusicState("MainMenu")

	
	
end


function Update(self, dt)

	
    
    if Input.GetKeyDown("1") then
		--Audio.SetMusicState("MainMenu")
        Engine.LoadScene(scenesPath, self.public.temp1)
    
    end
    if Input.GetKeyDown("2") then
		--Audio.SetMusicState("Level1")
        Engine.LoadScene(scenesPath, self.public.temp2)


    end
end








