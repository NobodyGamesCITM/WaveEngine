#pragma once
#include "Module.h"
#include "Octree.h"
#include "Globals.h"
#include <memory>
#include <vector>

class GameObject;
class FileSystem;
class Renderer;
class ComponentCamera;
class SceneWindow;

class ModuleScene : public Module
{
public:
    ModuleScene();
    virtual ~ModuleScene();

    bool Awake() override;
    bool Start() override;
    bool Update() override;
    bool FixedUpdate() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    GameObject* CreateGameObject(const std::string& name);

    GameObject* GetRoot() const { return root; }

    GameObject* FindObject(const UID uid) ; 
    GameObject* FindObject(const std::string& name);

    void CleanupMarkedObjects(GameObject* parent);

    Octree* GetOctree() { return octree.get(); }
    void RebuildOctree();
    void MarkOctreeForRebuild() { needsOctreeRebuild = true; }

    // Scene serialization
    bool SaveScene(const std::string& filepath);
    bool LoadScene(const std::string& filepath);
    void NewScene();
    void ClearScene();

    // for raycast visualization
    glm::vec3 lastRayOrigin = glm::vec3(0.0f);
    glm::vec3 lastRayDirection = glm::vec3(0.0f);
    float lastRayLength = 0.0f;
    ComponentCamera* FindCameraInHierarchy(GameObject* obj);

    // Scene serialization to/from string 
    std::string SerializeSceneToString();
    bool DeserializeSceneFromString(const std::string& jsonString);

private:
    std::unique_ptr<Octree> octree;
    bool needsOctreeRebuild = false;
    GameObject* root = nullptr;

    Renderer* renderer = nullptr;
    FileSystem* filesystem = nullptr;

};