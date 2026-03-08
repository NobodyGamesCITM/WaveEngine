#pragma once
#include "Component.h"
#include <nlohmann/json_fwd.hpp>
#include <glm/glm.hpp>

struct BloomSettings {
    bool enabled = true;
    float intensity = 1.0f;
    float threshold = 1.0f;
    float softKnee = 0.5f;
    float clamp = 65472.0f;
    float diffusion = 7.0f;
    glm::vec3 tint = glm::vec3(1.0f);
};

struct ColorGradingSettings {
    bool enabled = true;
    float exposure = 1.0f;
    float temperature = 0.0f;
    float tint = 0.0f;
    float contrast = 1.0f;
    float saturation = 1.0f;
    float gamma = 1.0f;
    int toneMapper = 0; // 0: ACES, 1: Neutral, 2: None
    glm::vec3 colorFilter = glm::vec3(1.0f);
};

struct LensSettings {
    bool chromaticAberrationEnabled = false;
    float chromaticAberrationIntensity = 0.0f;

    bool vignetteEnabled = false;
    float vignetteIntensity = 0.4f;
    float vignetteSmoothness = 0.2f;
    float vignetteRoundness = 1.0f;
    glm::vec4 vignetteColor = glm::vec4(0.0f, 0.0f, 0.0f, 1.0f);
};

class ComponentPostProcessing : public Component {
public:
    ComponentPostProcessing(GameObject* owner);
    ~ComponentPostProcessing();

    void OnEditor() override;

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    bool IsType(ComponentType type) override;
    bool IsIncompatible(ComponentType type) override;

public:
    BloomSettings bloom;
    ColorGradingSettings colorGrading;
    LensSettings lens;
    //GrainSettings grain;
};