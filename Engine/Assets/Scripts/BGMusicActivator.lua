-- BG Music Actcivator Script
local enteredNewLevel
local fadeTimer 
local volume
local finishedTransition
local musicSource = nil
local bgMusic = nil
local aquilesDefeated = false

public = {
	fadeTime = 1.5,
	--maxVolume = 100,
    nextMusicState = "",
	currentScene = {type = "Scene", value = ""}
}

local musicStates = {
	"Level1_Intro",
	"Level1",
	"Level1_Combat",
	"Level2",
	"Level2_Combat",
	"Boss_Intro",
	"Boss",
	"AfterBoss"
}


local function Initialize(self)

	if self.public.currentScene == "Splash.scene" then 
		enteredNewLevel = true
		Game.Resume()
	else enteredNewLevel = false end

	finishedTransition = false
	fadeTimer = 0
	volume = 0
	musicSource = GameObject.Find("MusicSource")
	bgMusic = musicSource:GetComponent("Audio Source")
    

	if not bgMusic then 
		--Engine.Log("[BGMusicActivator] BG Music Audio Source component not found!") 
	end
end


local function TryChangeMusicState(self, finalMusicState)
	local found = false
	for i, state in ipairs(musicStates) do
		if state == finalMusicState then
			found = true
			break
		end
	end

	if found then 
		if aquilesDefeated then 
			--Engine.Log("[BGMusicActivator] Aquiles Defeated!")
			Audio.SetMusicState("AfterBoss")
		else 
			--Engine.Log("[BGMusicActivator] Setting music state to "..tostring(finalMusicState))
			Audio.SetMusicState(tostring(finalMusicState)) 
		end
	else 
		--Engine.Log("Trying to change music state to "..tostring(finalMusicState)..", invalid Wwise State")
		
	end
end

function FadeInMusic(self, dt)
    if not volume then 
		Initialize(self)
	end
    
	if enteredNewLevel and volume < (_G.SavedMusicVolume or 100.0) and not finishedTransition then 
        if volume <= 0 then
			
            if bgMusic and not Audio.IsEventPlaying("MUS_BGM") then bgMusic:PlayAudioEvent() end
			--Engine.Log("Playing BGM Again from BGMusicActivator, increasing volume from 0 to "..tostring(_G.SavedMusicVolume))
        end

		fadeTimer = fadeTimer + dt
		local progressPercent = math.min((fadeTimer/(self.public.fadeTime or 1.5)), 1.0)
		volume = (_G.SavedMusicVolume or 100.0) * progressPercent
		--Engine.Log("Setting music volume to" .. tostring(volume))
		if volume then 
			--if bgMusic then bgMusicSetSourceVolume(volume) end
			Audio.SetMusicVolume(volume)
		else
			--Engine.Log("Could not set music volume!")
		end
	elseif enteredNewLevel and volume >= (_G.SavedMusicVolume or 100.0) and not finishedTransition then
        volume = _G.SavedMusicVolume or 100.0
		finishedTransition = true
		--Engine.Log("FINISHED TRANSITION")
		
	elseif enteredNewLevel and volume >= (_G.SavedMusicVolume or 100.0) and finishedTransition then

	end

	if _G._PlayerController_isDead then
		enteredNewLevel = false
		finishedTransition = false
		fadeTimer = 0
		volume = 0
		--TryChangeMusicState(self, "Level2")
	end 
end


function Start(self)
	Initialize(self)
end



function Update(self, dt)

	if _G._AquilesDefeated then aquilesDefeated = true end
    FadeInMusic(self, dt)
end

function OnTriggerEnter(self, other)
	if other:CompareTag("Player") and not finishedTransition then
		enteredNewLevel = true
		--Engine.Log("Switching to New Music...")
		fadeTimer = 0
        TryChangeMusicState(self, self.public.nextMusicState)
		-- if bgMusic then bgMusic:PlayAudioEvent()
		-- else Engine.Log("bgMusic not found!") 
		-- end
	end
end


