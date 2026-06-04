--BreakObject Script

-- local wholeObj = nil
-- local brokenObj = nil
-- local broken = false
-- local canBreak = false

public = {
    wholeObjName = "",
    brokenObjName = "",
}

-- local function RetrieveModels(self)

-- end

function Initialize(self)
    self.canBreak = false
    self.broken = false

    -- self.myCol = self.gameObject:GetComponent("Capsule Collider")
    -- if not self.myCol then 
    --     Engine.Log("Unable to retrieve this object's collider")
    -- end


    self.wholeModel = GameObject.FindInChildren(self.gameObject, tostring(self.public.wholeObjName))
    if self.wholeModel then 
        self.wholeModel:SetActive(true) 
    else 
        Engine.Log("[BreakObject] Unable to find whole model object")
    end
    
    self.brokenModel = GameObject.FindInChildren(self.gameObject, tostring(self.public.brokenObjName))
    if self.brokenModel then 

        local brokenPieces = GameObject.GetChildren(self.brokenModel)

        if brokenPieces then 
            for i,piece in ipairs(brokenPieces) do
                local pieceCol = piece:GetComponent("Convex Collider")
                if pieceCol then pieceCol:Disable() 
                else 
                    Engine.Log("[BreakObject] Unable to retrieve Convex Collider in broken piece "..i)
                end
            end
        else
            Engine.Log("[BreakObject] Unable to retrieve broken pieces")
        end
        
        self.brokenModel:SetActive(false) 
    
    else 
        Engine.Log("[BreakObject] Unable to find broken model object")
    end
end

function Start(self)
    Initialize(self)
end

function Update(self, dt)

    if not self.brokenModel or not self.wholeModel then 
        Initialize(self)
        return
    end

    if self.canBreak then 

        local rb = self.gameObject:GetComponent("Rigidbody")
        if rb then 
            rb:SetBody(2) 
        else
            Engine.Log("[BreakObject] Unable to change rigidbody to dynamic")
        end 
        
        if self.wholeModel then
            
            self.wholeModel:SetActive(false) 
        end
        if self.brokenModel then 

            self.brokenModel:SetActive(true) 

            

            local brokenPieces = GameObject.GetChildren(self.brokenModel)
            if brokenPieces then 
                for i,piece in ipairs(brokenPieces) do
                    local pieceCol = piece:GetComponent("Convex Collider")
                    if pieceCol then pieceCol:Enable() 
                    else 
                        Engine.Log("[BreakObject] Unable to retrieve Convex Collider in broken piece "..i)
                    end
                end
            else
                Engine.Log("[BreakObject] Unable to retrieve broken pieces")
            end
            
            
        
        else 
            Engine.Log("[BreakObject] Unable to find broken model object")
        end

        
        local myCol = self.gameObject:GetComponent("Capsule Collider")
        if myCol then 
            myCol:Disable()
        else
            Engine.Log("Unable to retrieve this object's collider")
        end
        

        self.canBreak = false
        self.broken = true
    end
end

function OnCollisionEnter(self, other)
    if other:CompareTag("Player") and not self.broken then 
        self.canBreak = true
        
    end
end



