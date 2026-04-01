-- Door.lua
public = {
    isOpen = false
}

function Start(self)
    self.public.isOpen = false
    
    self.OpenDoor = function(self)
        if not self.public.isOpen then
            self.public.isOpen = true
            Engine.Log("---------------------------------------------------------------------")
            Engine.Log("[Door] Bad Gyal, Govana - Open The Door ft. DJ Papis")
            Engine.Log("---------------------------------------------------------------------")
            self.gameObject:SetActive(false)
        end
    end
end