#include "ModuleGame.h"
#include "Application.h"
#include "Window.h"
#include "ModuleEvents.h"
#include "Renderer.h"
#include "ModuleCamera.h"
#include "ComponentCamera.h"
#include "CameraLens.h"

ModuleGame::ModuleGame() : Module()
{
}

ModuleGame::~ModuleGame()
{
}


bool ModuleGame::Start()
{
    Application::GetInstance().events->Subscribe(Event::Type::WindowResize, this);
    
    auto* window = Application::GetInstance().window.get();
    int width = 0, height = 0;
    window->GetWindowSize(width, height);

    HandleViewportResize(width, height);

    return true;
}

bool ModuleGame::PostUpdate()
{
    auto* renderer = Application::GetInstance().renderer.get();
    auto* cameraModule = Application::GetInstance().camera.get();
  
    if (cameraModule)
    {
        ComponentCamera* mainCam = cameraModule->GetMainCamera();
        if (mainCam && mainCam->GetLens())
        {
            CameraLens* lens = mainCam->GetLens();

            renderer->DrawFullscreenTexture(lens->textureID);
        }
    }

    return true;
}

void ModuleGame::HandleViewportResize(int width, int height)
{
    auto* cameraModule = Application::GetInstance().camera.get();
    if (cameraModule)
    {
        ComponentCamera* mainCam = cameraModule->GetMainCamera();
        if (mainCam && mainCam->GetLens())
        {
            CameraLens* lens = mainCam->GetLens();

            lens->SetRenderTarget(width, height);
            lens->SetAspectRatio((float)width / (float)height);
        }
    }
}

void ModuleGame::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::WindowResize:
    {
        HandleViewportResize(event.data.point.x, event.data.point.y);
    }
    default:
        break;
    }
}

bool ModuleGame::CleanUp()
{
    Application::GetInstance().events->UnsubscribeAll(this);
    return true;
}