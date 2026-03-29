
public = {
    music1 = { type = "", value = "" },
    music2 = { type = "", value = "" },
    fadeTimer = 1.0
}




function Start(self)
    Audio.SetMusicState("Level1");
end

function Update(self, dt)

    if Input.GetKey("0") then fadeMusic()

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

function fadeMusic()
    
end