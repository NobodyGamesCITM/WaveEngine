#pragma once
#include "Component.h"
#include "Globals.h"
#include <glm/glm.hpp>

class ResourceMaterial;
class Material;
class Shader;

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

    void ApplyTilingOverride(Shader* shader) const;

private:
    UID materialUID = 0;
    ResourceMaterial* resource = nullptr;

    bool overrideTiling = false;
    glm::vec2 tilingOverride = { 1.0f, 1.0f };
    glm::vec2 offsetOverride = { 0.0f, 0.0f };
};