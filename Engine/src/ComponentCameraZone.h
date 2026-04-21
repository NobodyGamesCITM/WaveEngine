#pragma once
#include "Component.h"
#include "AABB.h"
#include "Globals.h"
#include <glm/glm.hpp>
#include <vector>

class ComponentCameraZone : public Component {
public:
    ComponentCameraZone(GameObject* owner);
    ~ComponentCameraZone();

    enum class CameraMode {
        OFFSET_TRACKING = 0,
        FIXED_POS_LOOKAT = 1,
        FIXED_POS_FIXED_ROT = 2
    };

    CameraMode mode = CameraMode::OFFSET_TRACKING;

    void Update() override {}
    void OnEditor() override;
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    void SolveReferences() override;

    GameObject* cameraLocationObj = nullptr;
    UID cameraLocationUID = 0;

    bool IsType(ComponentType type) override { return type == ComponentType::CAMERA_ZONE; }
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::CAMERA_ZONE; }

    bool Contains(const glm::vec3& point) const;
    void DrawDebug();
    static void DrawAllDebug();

    static std::vector<ComponentCameraZone*> activeZones;

public:
    int priority = 0;
    float blendTime = 1.5f;

    glm::vec3 cameraOffset = glm::vec3(0.0f, 8.0f, 8.0f);
    glm::vec3 cameraEulerAngles = glm::vec3(-45.0f, 0.0f, 0.0f);
    float fov = 45.0f;

    glm::vec3 zoneSize = glm::vec3(10.0f, 10.0f, 10.0f);
    bool showDebug = true;
};