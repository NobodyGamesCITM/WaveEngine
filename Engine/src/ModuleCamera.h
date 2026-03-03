#pragma once
#include "Module.h"
#include "EventListener.h"


class GameObject;
class ComponentCamera;

class ModuleCamera : public Module, public EventListener
{
public:
    ModuleCamera();
    ~ModuleCamera();

    bool Start() override;

    bool CleanUp() override;

    ComponentCamera* GetMainCamera() const { return mainCamera; }
    void SetMainCamera(ComponentCamera*);

    void AddCamera(ComponentCamera* camera);
    void RemoveCamera(ComponentCamera* camera);

    void OnEvent(const Event& event);

private:  
    std::vector<ComponentCamera*> cameras;
    ComponentCamera* mainCamera = nullptr;     
};

