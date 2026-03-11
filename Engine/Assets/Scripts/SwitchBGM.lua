public = {
    
    musicTimer = 0,
    music1 = true
}

function Start(self)
    Audio.SetMusicState("CoffeeShop");
end

function Update(self, dt)
    -- Called every frame
    -- deltaTime = time since last frame in seconds
    musicTimer = musicTimer + deltaTime
    Engine.Log("musicTimer = ".. musicTimer)
    
    if musicTimer >= 15 then
        musicTimer = 0.0 --reset timer
        music1 = not music1

        if music1 then
            Audio.SetMusicState("CoffeeShop");
        else
            Audio.SetMusicState("PizzaParlor");
        end
    end
end
