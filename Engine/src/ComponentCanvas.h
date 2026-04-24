#pragma once
#include "GameObject.h"
#include "Component.h"
#include "NsCore/Ptr.h"
#include "NsGui/IView.h"
#include "NsRender/RenderDevice.h"
#include <string>

class ComponentCanvas : public Component
{
public:
    ComponentCanvas(GameObject* owner);
    ~ComponentCanvas();

    void Update() override;
    void ShutdownView();
    void CleanUp();
    void RenderToTexture();

    bool LoadXAML(const char* filename);
    void UnloadXAML();
    void Resize(int width, int height);
    void PlayStoryboard(const char* name);

    void SetOpacity(float alpha);
    float GetOpacity() const;

    void OnMouseMove(int x, int y);
    void OnMouseButtonDown(int x, int y, Noesis::MouseButton button);
    void OnMouseButtonUp(int x, int y, Noesis::MouseButton button);
    void OnMouseWheel(int x, int y, int delta);

    void OnKeyDown(Noesis::Key key) { OnGamepadButtonDown(key); }
    void OnKeyUp(Noesis::Key key) { OnGamepadButtonUp(key); }

    void OnGamepadButtonDown(Noesis::Key key);
    void OnGamepadButtonUp(Noesis::Key key);
    void OnGamepadLeftStick(float x, float y);
    void OnGamepadRightStick(float x, float y);
    void OnGamepadTrigger(float left, float right);

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    bool IsType(ComponentType type) override { return type == ComponentType::CANVAS; }
    bool IsIncompatible(ComponentType) override { return false; }

    unsigned int GetTextureID() const { return textureID; }
    GameObject* GetOwner() const { return owner; }
    const std::string& GetCurrentXAML() const { return currentXAML; }

    void SetUILayer(int layer) { uiLayer = layer; }
    int GetUILayer() const { return uiLayer; }

    float opacity = 1.0f;
    
    Noesis::IView* GetView() const { return view.GetPtr(); }
private:
    void GenerateFramebuffer(int w, int h);
    void TryNavigateStick(float x, float y);

    Noesis::Ptr<Noesis::IView> view;
    Noesis::Ptr<Noesis::RenderDevice> device;

    std::string currentXAML;

    unsigned int fbo = 0;
    unsigned int textureID = 0;
    unsigned int rbo = 0;
    int width = 1280;
    int height = 720;

    float stickX = 0.0f;
    float stickY = 0.0f;
    double stickRepeatTimer = 0.0;
    bool stickInitialFired = false;

    static constexpr float  STICK_THRESHOLD = 0.5f;
    static constexpr double STICK_INITIAL_DELAY = 0.4;
    static constexpr double STICK_REPEAT_RATE = 0.15;
    bool needsHookEvents = false;
    int uiLayer = 0;
};