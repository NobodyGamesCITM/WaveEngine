#include "ComponentMaterial.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceMaterial.h"
#include "Material.h"

#include "AssetsWindow.h"
#include "FileUtils.h"

ComponentMaterial::ComponentMaterial(GameObject* owner) : Component(owner, ComponentType::MATERIAL) {}

ComponentMaterial::~ComponentMaterial() 
{
    if (materialUID != 0) {
        Application::GetInstance().resources->ReleaseResource(materialUID);
    }
}

void ComponentMaterial::SetMaterial(UID uid) 
{
    LOG_CONSOLE("%llu", uid);
    if (materialUID != 0) {
        Application::GetInstance().resources->ReleaseResource(materialUID);
    }

    materialUID = uid;

    if (materialUID != 0) {
        resource = (ResourceMaterial*)Application::GetInstance().resources->RequestResource(materialUID);
    }
    else {
        resource = nullptr;
    }
}

Material* ComponentMaterial::GetMaterial() const {
    return (resource != nullptr) ? resource->GetMaterial() : nullptr;
}

float ComponentMaterial::GetOpacity() const {

    Material* mat = GetMaterial();
    if (mat) return mat->GetOpacity();
    else return 1.0f;
}

void ComponentMaterial::OnEditor()
{
    float availableWidth = ImGui::GetContentRegionAvail().x;
    std::string buttonText = "";
    if (materialUID == 0) {
        buttonText = "Drop material here";
    }
    else {
        const Resource* res = Application::GetInstance().resources->PeekResource(materialUID);
        buttonText = (res) ? GetFileNameNoExtension(res->GetAssetFile()) : "Unknown Material";
    }
        
    ImGui::Button(buttonText.c_str(), ImVec2(availableWidth, 20));

    if (ImGui::BeginDragDropTarget())
    {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("ASSET_ITEM"))
        {
            DragDropPayload* dropData = (DragDropPayload*)payload->Data;
            UID droppedUID = dropData->assetUID;

            const Resource* res = Application::GetInstance().resources->PeekResource(droppedUID);
            if (res && res->GetType() == Resource::Type::MATERIAL)
            {
                LOG_CONSOLE("%llu", droppedUID);
                SetMaterial(droppedUID);
            }
        }
        ImGui::EndDragDropTarget();
    }
}

void ComponentMaterial::Serialize(nlohmann::json& componentObj) const
{
    componentObj["materialUID"] = materialUID;
}

void ComponentMaterial::Deserialize(const nlohmann::json& componentObj)
{
    UID matUID = componentObj.value("materialUID", (UID)0);
    SetMaterial(matUID);
}