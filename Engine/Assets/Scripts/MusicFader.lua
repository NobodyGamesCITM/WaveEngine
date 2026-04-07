
public = {
	fadeTime = 2.0,
}

local musicSource
local musicComp
local musicVolume = 0.0
local firstFrame = true

function Start(self)
    firstFrame = true
    Engine.Log("[MusicFader] Start called. Target state: Level2")
    Audio.SetMusicState("Level2");
end

function Update(self, dt)
    -- Re-try searching for music source if not found yet
    if firstFrame or not musicSource or not musicComp then
        musicSource = GameObject.Find("MusicSource")
        if musicSource then
            musicComp = musicSource:GetComponent("Audio Source")
            if musicComp then
                Engine.Log("[MusicFader] Success: Found MusicSource and Audio Source. Starting audio...")
                musicComp:PlayAudioEvent()
                
                -- BGM trick: move the source to the player to ensure it's heard (avoids 3D attenuation)
                local ply = GameObject.Find("Player")
                if ply then
                    local p = ply.transform.position
                    musicSource.transform:SetPosition(p.x, p.y + 2.0, p.z)
                    Engine.Log("[MusicFader] Repositioned MusicSource to Player's location.")
                end
                
                firstFrame = false
            end
        end
    end

    local fadeDuration = self.public.fadeTime or 2.0
    if fadeDuration > 0 and musicVolume < 100.0 then
        musicVolume = musicVolume + (100.0 / fadeDuration) * dt
        if musicVolume > 100.0 then musicVolume = 100.0 end
    elseif fadeDuration <= 0 and musicVolume < 100.0 then
        musicVolume = 100.0
    end
end












