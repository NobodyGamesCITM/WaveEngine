#pragma once
#include "Component.h"
#include <glm/glm.hpp>
#include <vector>
#include "DetourNavMesh.h"

class NavMeshManager;

enum class NavType
{
    SURFACE,
    AGENT,
    OBSTACLE
};

class ComponentNavigation : public Component {
public:
    ComponentNavigation(GameObject* owner);

    void OnEditor() override;
    bool IsType(ComponentType type) override { return type == ComponentType::NAVIGATION; }
    bool IsIncompatible(ComponentType type) override { return false; }

    bool isStatic = true;
    NavType type = NavType::SURFACE;

    float maxSlopeAngle = 35.0f;
    GameObject* linkedSurface = nullptr;

    // Par�metros
    float moveSpeed = 5.0f;
    float arrivalThreshold = 0.25f;

    // API p�blica
    bool SetDestination(const glm::vec3& worldTarget);
    void StopMovement();
    void Update(float dt);   // ll�malo desde tu sistema de update
    bool IsMoving() const { return moving; }



    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;
    void SolveReferences() override;

    // Estado interno (privado si prefieres)
    std::vector<glm::vec3> path;
    int   pathIndex = 0;
    bool  moving = false;



    void GetMoveDirection(float threshold, float& dx, float& dz);
private:
    bool SnapPositionToNavMesh(glm::vec3& position);
    uint64_t tempSurfaceUID = 0; // Variable temporal para guardar el ID durante la carga
    dtPolyRef currentPolyRef = 0;
};