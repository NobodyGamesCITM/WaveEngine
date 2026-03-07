#include "ComponentMaterial.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceMaterial.h"
#include "Material.h"

ComponentMaterial::ComponentMaterial(GameObject* owner) : Component(owner, ComponentType::MATERIAL) {}

ComponentMaterial::~ComponentMaterial() 
{
    if (materialUID != 0) {
        Application::GetInstance().resources->ReleaseResource(materialUID);
    }
}

void ComponentMaterial::SetMaterial(UID uid) 
{
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
    
}

void ComponentMaterial::Serialize(nlohmann::json& componentObj) const
{

}

void ComponentMaterial::Deserialize(const nlohmann::json& componentObj)
{

}