#include "ComponentMaterial.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceMaterial.h"
#include "Material.h"
#include "MaterialStandard.h"
#include "Shader.h"

#include "AssetsWindow.h"
#include "FileSystem.h"

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

void ComponentMaterial::ApplyTilingOverride(Shader* shader) const
{
    if (!shader) return;
    if (overrideTiling) {
        shader->SetVec2("uTiling", tilingOverride);
        shader->SetVec2("uOffset", offsetOverride);
    } else {
        Material* mat = GetMaterial();
        if (mat && mat->GetType() == MaterialType::STANDARD) {
            MaterialStandard* stdMat = static_cast<MaterialStandard*>(mat);
            shader->SetVec2("uTiling", stdMat->GetTiling());
            shader->SetVec2("uOffset", stdMat->GetOffset());
        } else {
            shader->SetVec2("uTiling", glm::vec2(1.0f, 1.0f));
            shader->SetVec2("uOffset", glm::vec2(0.0f, 0.0f));
        }
    }
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
        buttonText = (res) ? FileSystem::GetFileNameNoExtension(res->GetAssetFile()) : "Unknown Material";
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

    ImGui::Spacing();
    if (ImGui::Checkbox("Override Tiling", &overrideTiling) && !overrideTiling) {
        tilingOverride = { 1.0f, 1.0f };
        offsetOverride = { 0.0f, 0.0f };
    }
    if (overrideTiling)
    {
        float t[2] = { tilingOverride.x, tilingOverride.y };
        if (ImGui::DragFloat2("Tiling", t, 0.01f, 0.01f, 100.0f))
            tilingOverride = { t[0], t[1] };
        float o[2] = { offsetOverride.x, offsetOverride.y };
        if (ImGui::DragFloat2("Offset", o, 0.01f))
            offsetOverride = { o[0], o[1] };
    }
}

void ComponentMaterial::Serialize(nlohmann::json& componentObj) const
{
    componentObj["materialUID"] = materialUID;
    componentObj["overrideTiling"] = overrideTiling;
    if (overrideTiling) {
        componentObj["tilingOverride"] = { tilingOverride.x, tilingOverride.y };
        componentObj["offsetOverride"] = { offsetOverride.x, offsetOverride.y };
    }
}

void ComponentMaterial::Deserialize(const nlohmann::json& componentObj)
{
    UID matUID = componentObj.value("materialUID", (UID)0);
    SetMaterial(matUID);

    overrideTiling = componentObj.value("overrideTiling", false);
    if (overrideTiling) {
        if (componentObj.contains("tilingOverride")) {
            auto& t = componentObj["tilingOverride"];
            tilingOverride = { t[0].get<float>(), t[1].get<float>() };
        }
        if (componentObj.contains("offsetOverride")) {
            auto& o = componentObj["offsetOverride"];
            offsetOverride = { o[0].get<float>(), o[1].get<float>() };
        }
    }
}