local musicTimer = 0.0
local music1 = true

function Start(self)
    Audio.SetMusicState("CoffeeShop");
end

function Update(self, dt)

    musicTimer = musicTimer + dt
    --Engine.Log("musicTimer = ".. tostring(musicTimer))
    
    if musicTimer >= 15.0 then
        musicTimer = 0.0 --reset timer
        music1 = not music1

        if music1 then
            Audio.SetMusicState("CoffeeShop");
        else
            Audio.SetMusicState("PizzaParlor");
        end
    end
end
