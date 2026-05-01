#pragma once
#include "Component.h"
#include <glm/glm.hpp>
#include <glm/gtc/quaternion.hpp>
#include <vector>
#include "Globals.h"

class CameraLens;
class ComponentCameraZone;

struct CameraTarget {
    UID uid;
    float weight;
};

struct CameraKeyframe {
    float time;
    glm::vec3 position;
    glm::quat rotation;
};

class ComponentCinematicCamera : public Component {
public:
    ComponentCinematicCamera(GameObject* owner);
    ~ComponentCinematicCamera();

    void Update() override;
    void OnEditor() override;
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    bool IsType(ComponentType type) override { return type == ComponentType::CINEMATIC_CAMERA; }
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::CAMERA; }

    // Lua
    void AddTarget(UID uid, float weight);
    void RemoveTarget(UID uid);
    void ClearTargets();
    void TriggerShake(float duration, float magnitude, float frequency);
    void PlayCinematic(const std::vector<CameraKeyframe>& track, float blendBackTime);
    bool IsPlayingCinematic() const { return camState != CameraState::NORMAL; }

private:
    bool CalculateWeightedTarget(glm::vec3& outPos);
    void EvaluateZones(const glm::vec3& targetPos);
    void ApplySmoothing(float dt);
    void ApplyShake(float dt, glm::vec3& outPos);

public:
    // Default
    glm::vec3 defaultOffset = glm::vec3(0.0f, 10.0f, 8.0f);
    glm::vec3 defaultEuler = glm::vec3(-50.0f, 0.0f, 0.0f);
    float defaultFov = 45.0f;
    float smoothSpeed = 5.0f; // Lerp

private:
    CameraLens* lens = nullptr;
    std::vector<CameraTarget> targets;

    glm::vec3 currentPos;
    glm::quat currentRot;
    float currentFov;

    glm::vec3 targetPos;
    glm::quat targetRot;
    float targetFov;

    ComponentCameraZone* currentZone = nullptr;

    float shakeTimer = 0.0f;
    float shakeMagnitude = 0.0f;
    float shakeFreq = 25.0f;

    enum class CameraState {
        NORMAL,
        PLAYING_CINEMATIC,
        BLENDING_BACK
    };

    CameraState camState = CameraState::NORMAL;
    std::vector<CameraKeyframe> cinematicTrack;
    float cinematicTimer = 0.0f;
    float blendBackTimer = 0.0f;
    float blendBackDuration = 0.0f;

    glm::vec3 cinematicEndPos;
    glm::quat cinematicEndRot;

    glm::vec3 EvaluateCatmullRom(const glm::vec3& p0, const glm::vec3& p1, const glm::vec3& p2, const glm::vec3& p3, float t);
};