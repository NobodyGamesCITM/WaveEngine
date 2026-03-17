#include "Application.h"
#include "ModuleCamera.h"
#include "ComponentCamera.h"
#include "GameObject.h"
#include "Transform.h"
#include "CameraLens.h"
#include "Log.h"

ComponentCamera::ComponentCamera(GameObject* owner)
    : Component(owner, ComponentType::CAMERA)
{
    name = "Camera";
    lens = new CameraLens();
    Application::GetInstance().camera.get()->AddCamera(this);
}

ComponentCamera::~ComponentCamera()
{
    Application::GetInstance().camera.get()->RemoveCamera(this);
    if (lens)
    {
        lens->CleanUp();
        delete lens;
        lens = nullptr;
    }
}

void ComponentCamera::Update()
{
    SyncTransformToLens();
}

void ComponentCamera::SyncTransformToLens()
{
    Transform* transform = (Transform*)owner->transform;
    if (transform && lens)
    {
        glm::mat4 modelMatrix = transform->GetGlobalMatrix();
        glm::mat4 viewMatrix = glm::inverse(modelMatrix);

        lens->SetViewMatrix(viewMatrix);
        lens->position = glm::vec3(modelMatrix[3]);
    }
}

const glm::mat4& ComponentCamera::GetViewMatrix() const
{
    return lens->GetViewMatrix();
}

const glm::mat4& ComponentCamera::GetProjectionMatrix() const
{
    return lens->GetProjectionMatrix();
}

glm::vec3 ComponentCamera::ScreenToWorldRay(int mouseX, int mouseY, int screenWidth, int screenHeight) const
{
    return lens->ScreenToWorldRay(mouseX, mouseY, screenWidth, screenHeight);
}

void ComponentCamera::Serialize(nlohmann::json& componentObj) const
{
    componentObj["active"] = IsMainCamera();
    if (!lens) return;
    componentObj["fov"] = lens->GetFov();
    componentObj["aspectRatio"] = lens->GetAspectRatio();
    componentObj["nearPlane"] = lens->GetNearPlane();
    componentObj["farPlane"] = lens->GetFarPlane();
    componentObj["usesPostProcessing"] = lens->IsUsingPostProcessing();
    componentObj["uiCullingMask"] = lens->GetUiCullingMask();
}

void ComponentCamera::Deserialize(const nlohmann::json& componentObj)
{
    SetMainCamera(componentObj.value("active", false));
    if (!lens) return;
    float fov = componentObj.value("fov", 60.0f);
    float aspect = componentObj.value("aspectRatio", 1.77f);
    float nPlane = componentObj.value("nearPlane", 0.1f);
    float fPlane = componentObj.value("farPlane", 1000.0f);
    bool usesPP = componentObj.value("usesPostProcessing", false);
    int uiCullingMask = componentObj.value("uiCullingMask", 0);

    lens->SetPerspective(fov, aspect, nPlane, fPlane);
    lens->SetUsesPostProcessing(usesPP);
    lens->SetUICullingMask(uiCullingMask);
}

bool ComponentCamera::IsMainCamera() const
{
    return Application::GetInstance().camera->GetMainCamera() == this;
}

void ComponentCamera::SetMainCamera(bool setMain)
{
    if (setMain)
    { 
        if (Application::GetInstance().camera->GetMainCamera() != this)
            Application::GetInstance().camera->SetMainCamera(this);
    }
    else
    {
        if (Application::GetInstance().camera->GetMainCamera() == this)
            Application::GetInstance().camera->SetMainCamera(nullptr);
    }
}