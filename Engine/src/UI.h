#pragma once
#include "Module.h"
#include "NsCore/Ptr.h"
#include "NsRender/RenderDevice.h"
#include <cstdint>
#include <vector>

class ComponentCanvas;

class UI : public Module
{
public:
    UI();
    ~UI();

    bool Start() override;
    bool CleanUp() override;

    // Canvas registry
    void RegisterCanvas(ComponentCanvas* c) { canvas.push_back(c); }
    void UnregisterCanvas(ComponentCanvas* c) { canvas.erase(std::remove(canvas.begin(), canvas.end(), c), canvas.end()); }
    std::vector<ComponentCanvas*> GetCanvas() { return canvas; }

    Noesis::Ptr<Noesis::RenderDevice> GetRenderDevice() { return renderDevice; }

    // Window
    void OnResize(uint32_t width, uint32_t height);

    // Mouse input
    void SetMousePosition(int x, int y);
    void OnMouseButtonDown(int x, int y, int sdlButton);
    void OnMouseButtonUp(int x, int y, int sdlButton);
    void OnMouseWheel(int x, int y, int delta);
  

    // Gamepad input
    void OnGamepadButtonDown(int sdlButton);
    void OnGamepadButtonUp(int sdlButton);
    void OnGamepadLeftStick(float x, float y);
    void OnGamepadRightStick(float x, float y);
    void OnGamepadTrigger(float left, float right);

private:
    Noesis::Ptr<Noesis::RenderDevice> renderDevice;
    std::vector<ComponentCanvas*> canvas;
    int mouseX = 0;
    int mouseY = 0;
};