-- LVL2 to Boss Music Transition Script
local exitedLevel2
local enteredBossLevel
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil

public = {
	fadeTime = 2.0,
	maxVolume = 25
}


local function fadeOutLvl2Music(self, dt)

	if volume > 0 then 
		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 2.0)), 1.0)
		volume = (self.public.maxVolume or 100) * (1 - progressPercent)
		Engine.Log("Setting global audio to ".. volume)
		if volume then 
			Audio.SetMusicVolume(volume)
			--if bgMusic then bgMusic:SetSourceVolume(volume) end
		else
			Engine.Log("Could not set music volume!")
		end

	end
end

local function fadeInBossMusic(self, dt)
	if volume < self.public.maxVolume then 
		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 2.0)), 1.0)
		volume = (self.public.maxVolume or 100) * progressPercent
		Engine.Log("Setting global audio to ".. volume)
		if volume then 
			--if bgMusic then bgMusic:SetSourceVolume(volume) end
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end
	else 
		finishedTransition = true
	end
		
end

function Start(self)
	Engine.Log("Level2 to Boss Music Script Running...")
	exitedLevel2 = false
	enteredBossLevel = false
	finishedTransition = false
	fadeTimer = 0
	volume = 100
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
	


	Audio.SetMusicState("Level2")
end

function Update(self, dt)
	if exitedLevel2 and not enteredBossLevel then
		fadeOutLvl2Music(self, dt)
	elseif exitedLevel2 and enteredBossLevel then
		fadeInBossMusic(self, dt)
	end
end

function OnTriggerEnter(self, other)
    if other:CompareTag("Player") and not finishedTransition then
		exitedLevel2 = true
		fadeTimer = 0
	end
end

function OnTriggerExit(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		enteredBossLevel = true
		fadeTimer = 0
		Audio.SetMusicState("Boss")
	end
end










