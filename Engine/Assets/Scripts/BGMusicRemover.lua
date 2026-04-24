-- BG Music Remover Script
local exitedLevel2
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil

public = {
	fadeTime = 1.5,
	maxVolume = 100
}

local function Initialize(self)
	exitedLevel2 = false
	finishedTransition = false
	fadeTimer = 0
	volume = 100
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
	
	Audio.SetMusicState("Level2")
end

function Start(self)
	Initialize(self)
end


function Update(self, dt)
	if not volume then
		Initialize(self)
	end

	if exitedLevel2 and volume > 0 and not finishedTransition then 
		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 1.5)), 1.0)
		volume = (self.public.maxVolume or 100) * (1 - progressPercent)
		--Engine.Log("Setting global audio to ".. volume)
		if volume then 
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end

	elseif exitedLevel2 and volume <= 0 and not finishedTransition then
		finishedTransition = true
		if bgMusic then bgMusic:StopAudioEvent() end
	elseif exitedLevel2 and volume <= 0 and finishedTransition then
		Audio.SetMusicState("Boss")
	end

	

	if _G._PlayerController_isDead then
		exitedLevel2 = false
		finishedTransition = false
		fadeTimer = 0
		volume = self.public.maxVolume or 100.0
	end 
end

function OnTriggerEnter(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		exitedLevel2 = true
		fadeTimer = 0
	end
end












