-- SceneLoader.lua

public = {
    temp1 = { type = "Scene", value = "" },
    temp2 = { type = "Scene", value = "" }
}

local scenesPath = Engine.GetScenesPath()

function Update(self, dt)
    if Input.GetKeyDown("1") then
        Engine.LoadScene(self.public.temp1)
    end
    if Input.GetKeyDown("2") then
        Engine.LoadScene(self.public.temp2)
    end
end


