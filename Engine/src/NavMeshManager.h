#pragma once

#include "Module.h" 
#include "Recast.h"
#include "DetourNavMesh.h"

#include "Transform.h"
#include "ComponentMesh.h"

#include <vector>
#include <glm/glm.hpp>

#include "DetourNavMeshQuery.h"

#include <algorithm>

class ModuleNavMesh : public Module
{
public:
    ModuleNavMesh();
    virtual ~ModuleNavMesh();

    bool Start() override;
    bool Update() override;
    bool CleanUp() override;

    // Bakes ALL Surface objects in the scene.
    // Surfaces whose AABBs touch or overlap are merged into a single NavMesh.
    void Bake(GameObject* obj);
    void DrawDebug();
    void RemoveNavMesh(GameObject* obj);
    void RemoveNavMeshRecursive(GameObject* obj);

    struct NavMeshData
    {
        rcHeightfield* heightfield = nullptr;
        rcCompactHeightfield* chf = nullptr;
        dtNavMesh* navMesh = nullptr;
        dtNavMeshQuery* navQuery = nullptr;

        // Primary owner (first surface of the group)
        GameObject* owner = nullptr;

        // Other surfaces that were merged into this NavMesh.
        // GetNavMeshData() and RemoveNavMesh() also match against these.
        std::vector<GameObject*> members;

        dtTileRef tileRef = 0;
    };

    // Returns the NavMeshData that owns 'owner', either as primary owner or as a member.
    NavMeshData* GetNavMeshData(GameObject* owner);

    bool FindPath(GameObject* surface,
        const glm::vec3& start,
        const glm::vec3& end,
        std::vector<glm::vec3>& outPath);

    bool GetRandomPoint(glm::vec3& outPoint);

    bool SaveNavMesh(const char* path, GameObject* owner);
    bool LoadNavMesh(const char* path, GameObject* owner);

    bool IsBlockedByObstacle(const glm::vec3& min, const glm::vec3& max);

private:

    // Collects geometry recursively.
    // When isTopLevel is false, stops at child objects that have their own
    // NavType::SURFACE component (those are baked as a separate entity).
    void RecollectGeometry(GameObject* obj,
        std::vector<float>& vertices,
        std::vector<int>& indices,
        bool isTopLevel = true);

    void ExtractVertices(ComponentMesh* mesh,
        std::vector<float>& vertices,
        std::vector<int>& indices);

    void CalculateAABB(const std::vector<float>& verts,
        float* minBounds, float* maxBounds);

    rcConfig CreateDefaultConfig(const float* minBounds, const float* maxBounds);

    void RecollectObstacles(GameObject* obj);

    // Core bake logic for a single group of (possibly merged) surfaces.
    // 'primary'      - the GameObject that owns the resulting NavMeshData.
    // 'groupMembers' - additional surfaces merged into this bake (can be empty).
    // 'allVertices / allIndices' - already-merged world-space geometry.
    // 'slopeAngle'   - walkable slope taken from primary's ComponentNavigation.
    void BakeSurfaceGroup(GameObject* primary,
        const std::vector<GameObject*>& groupMembers,
        const std::vector<float>& allVertices,
        const std::vector<int>& allIndices,
        float                            slopeAngle);

    std::vector<NavMeshData> navMeshes;
    std::vector<GameObject*> navObstacles;

    float sampleDist = 6.0f;
    float sampleMaxError = 1.0f;

    bool baked = false;
};