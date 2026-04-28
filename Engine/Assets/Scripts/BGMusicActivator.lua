-- BG Music Remover Script
local enteredNewLevel
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil

public = {
	fadeTime = 1.5,
	maxVolume = 100,
    nextMusicState = "",
}

local musicStates = {
	"Level1",
	"Level1_Combat",
	"Level2",
	"Level2_Combat",
	"Boss"
}

local function Initialize(self)
	enteredNewLevel = false
	finishedTransition = false
	fadeTimer = 0
	volume = 0
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")
    

	if not bgMusic then Engine.Log("BG Music Audio Source component not found!") end
end


local function TryChangeMusicState(self, finalMusicState)
	local found = false
	for i, state in ipairs(musicStates) do
		if state == finalMusicState then
			found = true
			break
		end
	end

	if found then Audio.SetMusicState(tostring(finalMusicState)) 
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
    
	if enteredNewLevel and volume <= (self.public.maxVolume or 100) and not finishedTransition then 
        if volume <= 0 then
            if bgMusic then bgMusic:PlayAudioEvent() end
        end

		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 1.5)), 1.0)
		volume = (self.public.maxVolume or 100) * progressPercent
		--Engine.Log(Setting global audio to .. volume)
		if volume then 
			--if bgMusic then bgMusicSetSourceVolume(volume) end
			Audio.SetMusicVolume(volume)
		else
			Engine.Log("Could not set music volume!")
		end
	elseif enteredNewLevel and volume >= (self.public.maxVolume or 100) and not finishedTransition then
        volume = self.public.maxVolume or 100
		finishedTransition = true
		
	elseif enteredNewLevel and volume >= (self.public.maxVolume or 100) and finishedTransition then
		--Audio.SetMusicState(tostring(self.public.nextMusicState))
		--TryChangeMusicState(self.public.nextMusicState)
        
	end

	if _G._PlayerController_isDead then
		enteredNewLevel = false
		finishedTransition = false
		fadeTimer = 0
		volume = 0
	end 
end

function OnTriggerEnter(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		enteredNewLevel = true
		Engine.Log("Switching to New Music...")
		fadeTimer = 0
        TryChangeMusicState(self, self.public.nextMusicState)
		-- if bgMusic then bgMusic:PlayAudioEvent()
		-- else Engine.Log("bgMusic not found!") 
		-- end
	end
end
