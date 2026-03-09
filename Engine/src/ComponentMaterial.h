#pragma once
#include "Component.h"
#include "Globals.h"

class ResourceMaterial;
class Material;

class ComponentMaterial : public Component {
public:
    ComponentMaterial(GameObject* owner);
    ~ComponentMaterial();

    bool IsType(ComponentType type) override { return type == ComponentType::MATERIAL; };
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::MATERIAL; };

    void SetMaterial(UID uid);

    Material* GetMaterial() const;
    float GetOpacity() const;

    UID GetMaterialUID() const { return materialUID; }

    void OnEditor() override;
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

private:
    UID materialUID = 0;
    ResourceMaterial* resource = nullptr;
};