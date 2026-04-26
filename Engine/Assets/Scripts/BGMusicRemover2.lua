-- BG Music Remover Script
local exitedLevel
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil

public = {
	fadeTime = 1.5,
	maxVolume = 100
	currentMusicState = ""
	nextMusicState = ""
}

local musicStates ={
	"Level1",
	"Level1_Combat",
	"Level2",
	"Level2_Combat",
	"Boss"
}

local function Initialize(self)
	exitedLevel = false
	finishedTransition = false
	fadeTimer = 0
	volume = 100
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
	
	TryChangeMusicState(self, self.public.currentMusicState)
end

local function TryChangeMusicState(self, finalMusicState)
	local found = false
	for i, state in musicStates do
		if state == musicState then
			found = true
			break
		end
	end

	if found then Audio.SetMusicState(finalMusicState) 
	else Engine.Log("Trying to change music state to "..tostring(finalMusicState)..", invalid Wwise State")
	end
end

function Start(self)
	Initialize(self)
end


function Update(self, dt)
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
	elseif exitedLevel and volume <= 0 and finishedTransition then
		--Audio.SetMusicState(tostring(self.public.nextMusicState))
		TryChangeMusicState(self.public.nextMusicState)
	end

	

	if _G._PlayerController_isDead then
		exitedLevel = false
		finishedTransition = false
		fadeTimer = 0
		volume = self.public.maxVolume or 100.0
	end 
end

function OnTriggerEnter(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		exitedLevel = true
		fadeTimer = 0
	end
end












