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

    bool distortionEnabled = false;
    float distortionIntensity = 0.0f;

    bool vignetteEnabled = false;
    float vignetteIntensity = 0.4f;
    float vignetteSmoothness = 0.2f;
    float vignetteRoundness = 1.0f;
    glm::vec4 vignetteColor = glm::vec4(0.0f, 0.0f, 0.0f, 1.0f);
};

struct DepthOfFieldSettings {
    bool enabled = false;
    float focusDistance = 10.0f;
    float focusRange = 3.0f;
    float blurStrength = 1.0f;
    bool tiltShift = false;
    glm::vec3 farTint = glm::vec3(0.0f);
    float tintIntensity = 1.0f;
};

struct MotionBlurSettings {
    bool enabled = false;
    float intensity = 0.5f;
};

struct AutoExposureSettings {
    bool enabled = false;
    float minBrightness = 0.1f;
    float maxBrightness = 2.0f;
    float speed = 1.0f;
};

struct GrainSettings {
    bool enabled = false;
    float intensity = 0.1f;
    float size = 1.6f;
};

struct RadialBlurSettings {
    bool enabled = false;
    float intensity = 0.1f;
    glm::vec2 center = glm::vec2(0.5f, 0.5f);
};

struct SharpenSettings {
    bool enabled = false;
    float intensity = 0.5f;
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
    DepthOfFieldSettings depthOfField;
    MotionBlurSettings motionBlur;
    AutoExposureSettings autoExposure;
    GrainSettings grain;
    RadialBlurSettings radialBlur;
    SharpenSettings sharpen;
};