-- BG Music Remover Script
local exitedLevel
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil

public = {
	fadeTime = 1.5,
	maxVolume = 100,
	--currentMusicState = "",
	--nextMusicState = "",
}

local musicStates ={
	"Level1",
	"Level1_Combat",
	"Level2",
	"Level2_Combat",
	"Boss",
	"AfterBoss"
}

local function Initialize(self)
	exitedLevel = false
	finishedTransition = false
	fadeTimer = 0
	volume = 100
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
	
end


function FadeOutMusic(self, dt)
	if not volume then
		Initialize(self)
	end

	if exitedLevel and volume > 0 and not finishedTransition then 
		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 1.5)), 1.0)
		volume = (self.public.maxVolume or 100) * (1 - progressPercent)
		--Engine.Log("Setting global audio to ".. volume)
		if volume then 
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end

	elseif exitedLevel and volume <= 0 and not finishedTransition then
		finishedTransition = true
		if bgMusic then bgMusic:StopAudioEvent() end
	end


	if _G._PlayerController_isDead then
		exitedLevel = false
		finishedTransition = false
		fadeTimer = 0
		volume = self.public.maxVolume or 100.0
	end 
end

function Start(self)
	Initialize(self)
end


function Update(self, dt)
	FadeOutMusic(self, dt)
end

function OnTriggerEnter(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		exitedLevel = true
		fadeTimer = 0
	end
end













