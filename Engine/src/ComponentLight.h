#pragma once
#include "Component.h"
#include "LightData.h"

enum class LightType { DIRECTIONAL, POINT, SPOT };

class ComponentLight : public Component
{
public:
    explicit ComponentLight(GameObject* owner);
    ~ComponentLight() override;

    bool IsType(ComponentType type) override { return type == ComponentType::LIGHT; }
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::LIGHT; }

    // Sync position/direction from the owning Transform. Call once per frame.
    void UpdateTransformData();

    LightType GetLightType() const { return lightType; }
    void      SetLightType(LightType t) { lightType = t; }

    // Const accessors used by LightManager
    const DirectionalLightData& GetDirectionalData() const { return directionalData; }
    const PointLightData& GetPointData()       const { return pointData; }
    const SpotLightData& GetSpotData()        const { return spotData; }

    // Mutable accessors for editor / runtime configuration
    DirectionalLightData& GetDirectionalData() { return directionalData; }
    PointLightData& GetPointData() { return pointData; }
    SpotLightData& GetSpotData() { return spotData; }

    void OnEditor() override;
    void Serialize(nlohmann::json& obj) const override;
    void Deserialize(const nlohmann::json& obj) override;

    void Update() override;

private:
    LightType            lightType = LightType::DIRECTIONAL;
    DirectionalLightData directionalData;
    PointLightData       pointData;
    SpotLightData        spotData;
};