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

    void Bake(GameObject* obj);
    void DrawDebug();
    void RemoveNavMesh(GameObject* obj);
    void RemoveNavMeshRecursive(GameObject* obj);

    struct NavMeshData
    {
        rcHeightfield* heightfield = nullptr;
        rcCompactHeightfield* chf = nullptr;  // nuevo
        dtNavMesh* navMesh = nullptr;
        dtNavMeshQuery* navQuery = nullptr;
        GameObject* owner = nullptr;
        dtTileRef tileRef = 0;
    };

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

    void RecollectGeometry(GameObject* obj, std::vector<float>& vertices, std::vector<int>& indices);
    void ExtractVertices(ComponentMesh* mesh, std::vector<float>& vertices, std::vector<int>& indices);
    
    void CalculateAABB(const std::vector<float>& verts, float* minBounds, float* maxBounds);
    rcConfig CreateDefaultConfig(const float* minBounds, const float* maxBounds);

    void RecollectObstacles(GameObject* obj);
 

    std::vector<NavMeshData> navMeshes;
    std::vector<GameObject*> navObstacles;

    float sampleDist = 6.0f; 
    float sampleMaxError = 1.0f;

    bool baked = false;
};