local found

function Start(self)
	found = false
end

function Update(self, dt)
	if found then return end

    local persistentObj = GameObject.Find("PersistentCube")
	if persistentObj then
		persistentObj:SetPersistency(0)	
		found = true

	end

end



