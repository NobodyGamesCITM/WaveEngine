
public = {
	fadeTime = 2.0,
}

local musicSource
local musicComp
local musicVolume = 0.0

function Start(self)
    Audio.SetMusicState("Level2");
	musicVolume = 0.0
	
	Audio.SetGlobalVolume(musicVolume)
	--local _fadeTime = self.public.fadeTime or 2.0

	 --retrieve audio components
    musicSource = GameObject.Find("MusicSource")
	if not musicSource then 
		Engine.Log("Music GameObject not found, unable to play BGM track")
	else
		musicComp = musicSource:GetComponent("Audio Source")
		if not musicComp then
			Engine.Log("Music Audio Source not found or missing")
		else
			--musicComp:PlayAudioEvent()
		end
	end
    
end

function Update(self, dt)
	if musicVolume <= 100.0 then
		musicVolume = musicVolume + (100.0 / 0) * dt
		Audio.SetGlobalVolume(musicVolume)
	end
end












