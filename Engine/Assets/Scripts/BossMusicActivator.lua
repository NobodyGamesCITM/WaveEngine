-- BG Music Remover Script
local enteredBossLevel
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
	enteredBossLevel = false
	finishedTransition = false
	fadeTimer = 0
	volume = 0
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
end

function Start(self)
	Initialize(self)
end

function Update(self, dt)

	if not volume then 
		Initialize(self)
	end

	


	if enteredBossLevel and volume < (self.public.maxVolume or 100) then 

		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 1.5)), 1.0)
		volume = (self.public.maxVolume or 100) * progressPercent
		--Engine.Log("Setting global audio to ".. volume)
		if volume then 
			--if bgMusic then bgMusic:SetSourceVolume(volume) end
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end
	elseif enteredBossLevel and volume >= (self.public.maxVolume or 100) then
		finishedTransition = true
	end

	if _G._PlayerController_isDead then
		enteredBossLevel = false
		finishedTransition = false
		fadeTimer = 0
		volume = 0
	end 
end

function OnTriggerEnter(self, other)
	 if other:CompareTag("Player") and not finishedTransition then
		enteredBossLevel = true
		Engine.Log("Switching to Boss Music...")
		fadeTimer = 0
		if bgMusic then bgMusic:PlayAudioEvent()
		else Engine.Log("bgMusic not found!") 
		end
	end
end














