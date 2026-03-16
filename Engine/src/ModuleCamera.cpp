#include "ModuleCamera.h"
#include "ModuleEvents.h"
#include "ComponentCamera.h"
#include "GameObject.h"
#include "Transform.h"
#include "Application.h"
#include "Input.h"
#include "Window.h"

ModuleCamera::ModuleCamera() :
    Module()
{
    name = "Camera";
    mainCamera = nullptr;
}

ModuleCamera::~ModuleCamera()
{
   
}

bool ModuleCamera::Start() 
{
    Application::GetInstance().events.get()->Subscribe(Event::Type::GameObjectDestroyed, this);
    return true;
}

bool ModuleCamera::CleanUp()
{
    LOG_DEBUG("Cleaning up Camera Module");

    Application::GetInstance().events.get()->UnsubscribeAll(this);
    cameras.clear();
    mainCamera = nullptr;

    return true;
}

void ModuleCamera::AddCamera(ComponentCamera* cam) {
    
    cameras.push_back(cam);
}

void ModuleCamera::RemoveCamera(ComponentCamera* cam)
{
    if (mainCamera == cam) mainCamera = nullptr;
    
    auto it = std::find(cameras.begin(), cameras.end(), cam);
    if (it != cameras.end())
    {
        cameras.erase(it);
        LOG_DEBUG("Camera removed from ModuleCamera");
    }
}



void ModuleCamera::SetMainCamera(ComponentCamera* camera)
{
    mainCamera = camera;
}

void ModuleCamera::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::GameObjectDestroyed:
    {
        GameObject* deletedObject = event.data.gameObject.gameObject;
        if (mainCamera && mainCamera->owner == deletedObject) SetMainCamera(nullptr);
        break;
    }


    default:
        break;
    }
}