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
#include "ComponentNavigation.h"
#include "ModuleEvents.h"
#include "Event.h"

#include <fstream>

ModuleScene::ModuleScene() : Module()
{
    name = "ModuleScene";
    root = nullptr;
    renderer = nullptr;
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



bool ModuleScene::Update()
{
    // Update all GameObjects
    if (root)
    {
        root->Update();
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

    return true;
}

GameObject* ModuleScene::CreateGameObject(const std::string& name)
{
    GameObject* newObject = new GameObject(name);

    if (root)
    {
        root->AddChild(newObject);
    }

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
        }
        else
        {
            CleanupMarkedObjects(child);
        }
    }
}

bool ModuleScene::SaveScene(nlohmann::json& sceneHierarchy)
{
    // Serialize gameobjects
    nlohmann::json gameObjectsArray = nlohmann::json::array();

    if (root) {
        for (GameObject* child : root->GetChildren()) {
            child->Serialize(gameObjectsArray);
        }
    }

    sceneHierarchy["gameObjects"] = gameObjectsArray;

    return true;
}

bool ModuleScene::LoadScene(const nlohmann::json& sceneHierarchy)
{
    Application::GetInstance().selectionManager->ClearSelection();

    ClearScene();

    if (sceneHierarchy.contains("gameObjects") && sceneHierarchy["gameObjects"].is_array())
    {
        const nlohmann::json& gameObjectsArray = sceneHierarchy["gameObjects"];

        for (const auto& jsonNode : gameObjectsArray)
        {
            GameObject* obj = GameObject::Deserialize(jsonNode, root);
            if (!obj) {
                LOG_CONSOLE("WARNING: Failed to deserialize a GameObject in the scene");
            }
        }
    }

    if (root)
        root->SolveReferences();

    LOG_CONSOLE("Iniciando Auto-Bake de NavMeshes...");

    std::function<void(GameObject*)> autoBakeNav = [&](GameObject* obj) {
        if (!obj) return;

        ComponentNavigation* nav = static_cast<ComponentNavigation*>(obj->GetComponent(ComponentType::NAVIGATION));

        if (nav && nav->type == NavType::SURFACE) {
            LOG_CONSOLE("Auto-Baking superficie: %s", obj->GetName().c_str());
            Application::GetInstance().navMesh->Bake(obj);
        }

        for (GameObject* child : obj->GetChildren()) {
            autoBakeNav(child);
        }
        };

    if (root) {
        autoBakeNav(root);
    }


    LOG_CONSOLE("Scene loaded successfully from JSON");

    Application::GetInstance().events->PublishImmediate(Event(Event::Type::SceneLoaded));

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

    if (Application::GetInstance().navMesh) {
        Application::GetInstance().navMesh->CleanUp();
    }


    // Selection
    if (Application::GetInstance().navMesh) {
        Application::GetInstance().navMesh->CleanUp();
    }

    Application::GetInstance().selectionManager->ClearSelection();

    // Childrens
    std::vector<GameObject*> children = root->GetChildren();
    for (GameObject* child : children) {
        if (child->IsPersistent())
        {
            continue;
        }
        root->RemoveChild(child);
        delete child;
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

    LOG_CONSOLE("Scene restored from memory");
    return true;
}