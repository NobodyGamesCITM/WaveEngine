-- SceneTransition.lua

local State = {
    FADE_OUT = 0,
    IDLE     = 1,
    FADE_IN  = 2,
    DONE     = 3
}

local currentState = State.FADE_OUT
local currentAlpha = 1.0
local canvasComponent = nil 

public = {
    targetScene = "Level_02",  
    fadeSpeed   = 1.0          
}

function Start(self)

    currentState = State.FADE_OUT
    currentAlpha = 1.0
    
    canvasComponent = self.gameObject:GetComponent("Canvas") 
    
    if not canvasComponent then
        Engine.Log("[SceneTransition] ERROR: No se encontró el componente Image en este objeto.")
    end
end

function Update(self, dt)
    if not canvasComponent then return end

    if currentState == State.FADE_OUT then
        currentAlpha = currentAlpha - (self.public.fadeSpeed * dt)
        
        if currentAlpha <= 0.0 then
            currentAlpha = 0.0
            currentState = State.IDLE
        end
        
        SetCanvasAlpha(currentAlpha)

    elseif currentState == State.FADE_IN then
        currentAlpha = currentAlpha + (self.public.fadeSpeed * dt)
        
        if currentAlpha >= 1.0 then
            currentAlpha = 1.0
            currentState = State.DONE
            SetCanvasAlpha(currentAlpha)

            if Engine.LoadScene then
                Engine.LoadScene(self.public.targetScene)
            end
        end
        
        SetCanvasAlpha(currentAlpha)
    end
end

function OnTriggerEnter(self, other)
    if currentState == State.IDLE and other:CompareTag("Player") then

        currentState = State.FADE_IN
        
        if _G.PlayerInstance then
            _G.PlayerInstance.public.canMove = false
        end
    end
end

function SetCanvasAlpha(alpha)
    if canvasComponent then

        if canvasComponent.SetOpacity then
            canvasComponent:SetOpacity(alpha)
        end
    end
end