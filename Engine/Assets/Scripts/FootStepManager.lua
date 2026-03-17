local sfxSource = nil
local nav = nil

public = { timeInterval = 0.5 }
local stepTimer = 0


function Start(self)

    sfxSource = self.gameObject:GetComponent("Audio Source")
    nav = self.gameObject:GetComponent("Navigation")

	if not sfxSource then
        Engine.Log("[StepSFX] Audio Source not found")
    end

    if not nav then
        Engine.Log("[StepSFX] Navigation not found")
    end
	
end

function Update(self, dt)
	
	stepTimer = stepTimer + dt

	if sfxSource then
		if  stepTimer >= self.public.timeInterval and nav:IsMoving() then
			stepTimer = 0
			sfxSource:PlayAudioEvent()
		end
	end

end






