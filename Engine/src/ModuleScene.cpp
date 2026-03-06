#include "ModuleScene.h"
#include "Renderer.h"
#include "ModuleLoader.h"
#include "GameObject.h"
#include "Application.h"
#include "Transform.h"
#include <float.h>
#include <functional>
#include "ComponentMesh.h"
#include "ComponentCamera.h"
#include <nlohmann/json.hpp>
#include <fstream>

ModuleScene::ModuleScene() : Module()
{
    name = "ModuleScene";
    root = nullptr;
    renderer = nullptr;
    filesystem = nullptr;
}

ModuleScene::~ModuleScene()
{
    if (root)
    {
        delete root;
        root = nullptr;
    }
}

bool ModuleScene::Awake()
{
    return true;
}

bool ModuleScene::Start()
{
    LOG_DEBUG("Initializing Scene");
    root = new GameObject("Root");
    LOG_CONSOLE("Scene ready");

    return true;
}

void ModuleScene::RebuildOctree()
{
    LOG_DEBUG("[ModuleScene] Starting full octree rebuild");

    AABB sceneAABB;
    sceneAABB.SetNegativeInfinity();

    bool hasObjects = false;

    // Calculate bounds of all objects
    std::function<void(GameObject*)> calculateBounds = [&](GameObject* obj) {
        if (!obj || !obj->IsActive()) return;

        ComponentMesh* mesh = static_cast<ComponentMesh*>(obj->GetComponent(ComponentType::MESH));
        if (mesh && mesh->IsActive() && mesh->HasMesh())
        {
            AABB objectAABB;
            mesh->GetGlobalAABB();

            sceneAABB.min = glm::min(sceneAABB.min, objectAABB.min);
            sceneAABB.max = glm::max(sceneAABB.max, objectAABB.max);
            hasObjects = true;
        }

        for (GameObject* child : obj->GetChildren())
        {
            calculateBounds(child);
        }
        };

    if (root)
    {
        calculateBounds(root);
    }

    // If no objects with mesh, use default bounds
    if (!hasObjects)
    {
        sceneAABB.min = glm::vec3(-10.0f, -10.0f, -10.0f);
        sceneAABB.max = glm::vec3(10.0f, 10.0f, 10.0f);
    }
    else
    {
        // Expand bounds significantly (50% margin)
        glm::vec3 size = sceneAABB.max - sceneAABB.min;
        glm::vec3 margin = size * 0.5f;
        sceneAABB.min -= margin;
        sceneAABB.max += margin;
    }

    if (!octree)
    {
        octree = std::make_unique<Octree>(sceneAABB.min, sceneAABB.max, 4, 5);
    }
    else
    {
        octree->Clear();
        octree->Create(sceneAABB.min, sceneAABB.max, 4, 5);
    }

    // Insert all game objects
    int insertedCount = 0;

    std::function<void(GameObject*)> insertRecursive = [&](GameObject* obj) {
        if (!obj || !obj->IsActive()) return;

        ComponentMesh* mesh = static_cast<ComponentMesh*>(obj->GetComponent(ComponentType::MESH));

        if (mesh && mesh->IsActive() && mesh->HasMesh())
        {
            if (octree->Insert(obj))
            {
                insertedCount++;
            }
        }

        for (GameObject* child : obj->GetChildren())
        {
            insertRecursive(child);
        }
        };

    if (root)
    {
        insertRecursive(root);
    }

    // Reset flag after rebuild
    needsOctreeRebuild = false;

    LOG_DEBUG("[ModuleScene] Octree rebuilt with %d objects", insertedCount);
    LOG_CONSOLE("Octree rebuilt: %d objects", insertedCount);
}

bool ModuleScene::Update()
{
    // Update all GameObjects
    if (root)
    {
        root->Update();
    }

    // Full rebuild only if explicitly requested
    if (needsOctreeRebuild)
    {
        LOG_DEBUG("[ModuleScene] Full octree rebuild requested");
        RebuildOctree();
    }

    return true;
}

bool ModuleScene::FixedUpdate()
{
    // Update all GameObjects
    if (root)
    {
        root->FixedUpdate();
    }

    return true;
}

bool ModuleScene::PostUpdate()
{
    // Full rebuild only if explicitly requested
    if (needsOctreeRebuild)
    {
        LOG_DEBUG("[ModuleScene] Full octree rebuild requested");
        RebuildOctree();
    }

    // Cleanup marked objects
    if (root)
    {
        CleanupMarkedObjects(root);
    }

    return true;
}

bool ModuleScene::CleanUp()
{
    LOG_DEBUG("Cleaning up Scene");

    if (root)
    {
        delete root;
        root = nullptr;
    }

    if (octree)
    {
        octree->Clear();
        octree.reset();
    }

    return true;
}

GameObject* ModuleScene::CreateGameObject(const std::string& name)
{
    GameObject* newObject = new GameObject(name);

    if (root)
    {
        root->AddChild(newObject);
    }
    needsOctreeRebuild = true;
    return newObject;
}

void ModuleScene::CleanupMarkedObjects(GameObject* parent)
{
    if (!parent) return;

    std::vector<GameObject*> children = parent->GetChildren();

    for (GameObject* child : children)
    {
        if (child->IsMarkedForDeletion())
        {
            parent->RemoveChild(child);
            delete child;

            // Mark octree for rebuild after deletion
            needsOctreeRebuild = true;
        }
        else
        {
            CleanupMarkedObjects(child);
        }
    }
}

bool ModuleScene::SaveScene(const std::string& filepath)
{
    LOG_CONSOLE("Saving scene to: %s", filepath.c_str());

    nlohmann::json document;

    document["version"] = 1;

    // Serialize gameobjects
    nlohmann::json gameObjectsArray = nlohmann::json::array();

    if (root) {
        for (GameObject* child : root->GetChildren()) {
            child->Serialize(gameObjectsArray);
        }
    }

    document["gameObjects"] = gameObjectsArray;

    // Write to file
    std::ofstream file(filepath);
    if (!file.is_open()) {
        LOG_CONSOLE("ERROR: Failed to open file for writing: %s", filepath.c_str());
        return false;
    }

    file << document.dump(4);
    file.close();

    //LOG_CONSOLE("Scene saved successfully");
    return true;
}

bool ModuleScene::LoadScene(const std::string& filepath)
{
    LOG_CONSOLE("Loading scene from: %s", filepath.c_str());

    // Read file
    std::ifstream file(filepath);
    if (!file.is_open()) {
        LOG_CONSOLE("ERROR: Failed to open file for reading: %s", filepath.c_str());
        return false;
    }

    nlohmann::json document;

    try {
        file >> document;
    }
    catch (const nlohmann::json::parse_error& e) {
        LOG_CONSOLE("ERROR: Failed to parse JSON file: %s", e.what());
        file.close();
        return false;
    }

    file.close();

    // Clear selection to avoid bugs
    Application::GetInstance().selectionManager->ClearSelection();

    // Clear current scene
    ClearScene();

    // Deserialize GameObjects
    if (document.contains("gameObjects") && document["gameObjects"].is_array()) {
        const nlohmann::json& gameObjectsArray = document["gameObjects"];

        for (size_t i = 0; i < gameObjectsArray.size(); ++i) {
            GameObject* obj = GameObject::Deserialize(gameObjectsArray[i], root);
            if (!obj) {
                LOG_CONSOLE("WARNING: Failed to deserialize GameObject at index %zu", i);
            }
        }
    }

    if (root) 
        root->SolveReferences();

    // Force full rebuild after loading scene
    needsOctreeRebuild = true;

    LOG_CONSOLE("Scene loaded successfully");
    return true;
}

void ModuleScene::NewScene()
{
    ClearScene();

    if (root)
    {
        Transform* transform = static_cast<Transform*>(root->GetComponent(ComponentType::TRANSFORM));
        if (transform)
        {
            transform->SetPosition(glm::vec3(0.0f));
            transform->SetRotation(glm::vec3(0.0f));
            transform->SetScale(glm::vec3(1.0f));
        }
    }

    LOG_CONSOLE("New Scene created");
}

void ModuleScene::ClearScene()
{
    LOG_CONSOLE("Clearing scene...");

    if (!root) return;

    // Selection
    Application::GetInstance().selectionManager->ClearSelection();

    // Childrens
    std::vector<GameObject*> children = root->GetChildren();
    for (GameObject* child : children) {
        root->RemoveChild(child);
        delete child;
    }

    // Octree
    if (octree) {
        octree->Clear();
    }

    LOG_CONSOLE("Scene cleared");
}

GameObject* ModuleScene::FindObject(const UID uid) 
{ 
    return root->FindChild(uid); 
}

GameObject* ModuleScene::FindObject(const std::string& name)
{ 
    return root->FindChild(name); 
}

ComponentCamera* ModuleScene::FindCameraInHierarchy(GameObject* obj)
{
    if (!obj) return nullptr;

    ComponentCamera* cam = static_cast<ComponentCamera*>(obj->GetComponent(ComponentType::CAMERA));
    if (cam) return cam;

    for (GameObject* child : obj->GetChildren()) {
        ComponentCamera* foundCam = FindCameraInHierarchy(child);
        if (foundCam) return foundCam;
    }

    return nullptr;
}

std::string ModuleScene::SerializeSceneToString()
{
    nlohmann::json document;
    document["version"] = 1;

    // Serialize gameobjects
    nlohmann::json gameObjectsArray = nlohmann::json::array();

    if (root) {
        for (GameObject* child : root->GetChildren()) {
            child->Serialize(gameObjectsArray);
        }
    }

    document["gameObjects"] = gameObjectsArray;

    // Return as JSON string 
    return document.dump(4);
}

bool ModuleScene::DeserializeSceneFromString(const std::string& jsonString)
{
    nlohmann::json document;

    try {
        document = nlohmann::json::parse(jsonString);
    }
    catch (const nlohmann::json::parse_error& e) {
        LOG_CONSOLE("[ModuleScene] ERROR: Failed to parse scene JSON: %s", e.what());
        return false;
    }

    Application::GetInstance().selectionManager->ClearSelection();

    ClearScene();

    // Deserialize GameObjects
    if (document.contains("gameObjects") && document["gameObjects"].is_array()) {
        const nlohmann::json& gameObjectsArray = document["gameObjects"];

        for (size_t i = 0; i < gameObjectsArray.size(); ++i) {
            GameObject* obj = GameObject::Deserialize(gameObjectsArray[i], root);
            if (!obj) {
                LOG_CONSOLE("[ModuleScene] WARNING: Failed to deserialize GameObject at index %zu", i);
            }
        }
    }

    if (root) 
        root->SolveReferences();

    // Force full rebuild after loading scene
    needsOctreeRebuild = true;

    LOG_CONSOLE("Scene restored from memory");
    return true;
}