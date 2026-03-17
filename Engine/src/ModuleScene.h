#pragma once
#include "Module.h"
#include "Octree.h"
#include "Globals.h"
#include <memory>
#include <vector>
#include <nlohmann/json.hpp>

class GameObject;
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

    // Scene serialization
    bool SaveScene(nlohmann::json& sceneHierarchy);
    bool LoadScene(const nlohmann::json& sceneHierarchy);
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

    GameObject* root = nullptr;

    Renderer* renderer = nullptr;

};