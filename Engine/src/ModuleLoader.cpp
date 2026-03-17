#include "Application.h"
#include "ModuleEvents.h"
#include "ModuleLoader.h"
#include "LibraryManager.h"
#include "ComponentMesh.h"
#include "ResourceModel.h"
#include "ResourcePrefab.h"
#include "ResourceScene.h"
#include "MetaFile.h"
#include "FileUtils.h"
#include "ComponentMaterial.h"
#include "MaterialStandard.h"
#include "ComponentCamera.h"

ModuleLoader::ModuleLoader() : Module() {}
ModuleLoader::~ModuleLoader() {}

bool ModuleLoader::Awake()
{
    return true;
}

bool ModuleLoader::Start()
{
    namespace fs = std::filesystem;

    if (!LibraryManager::IsInitialized()) {
        LOG_CONSOLE("[FileSystem] ERROR: LibraryManager not initialized");
        return false;
    }

    std::string defaultScenePath = "../Scene/testMarc.json";
    if (fs::exists(defaultScenePath)) {
        LOG_CONSOLE("[FileSystem] Loading default scene: %s", defaultScenePath.c_str());
        if (Application::GetInstance().scene->LoadScene(defaultScenePath)) {
            LOG_CONSOLE("[FileSystem] Default scene loaded successfully");
            return true;
        }
        else {
            LOG_CONSOLE("[FileSystem] WARNING: Failed to load default scene, using fallback geometry");
        }
    }

    fs::path assetsPath = LibraryManager::GetAssetsRoot();

    if (!fs::exists(assetsPath) || !fs::is_directory(assetsPath)) {
        LOG_CONSOLE("[FileSystem] WARNING: Assets folder not accessible");

        GameObject* pyramidObject = new GameObject("Pyramid");
        ComponentMesh* meshComp = static_cast<ComponentMesh*>(pyramidObject->CreateComponent(ComponentType::MESH));
        Mesh pyramidMesh = Primitives::CreatePyramid();
        meshComp->SetMesh(pyramidMesh);

        GameObject* root = Application::GetInstance().scene->GetRoot();
        root->AddChild(pyramidObject);
        

        return true;
    }

    // Cargar street
    fs::path streetPath = assetsPath / "Street" / "street2.fbx";
    LoadModel(streetPath.generic_string());

    // Crear cámara de escena
    Application& app = Application::GetInstance();
    GameObject* cameraGO = app.scene->CreateGameObject("Camera");

    Transform* transform = static_cast<Transform*>(
        cameraGO->GetComponent(ComponentType::TRANSFORM)
        );
    if (transform)
    {
        transform->SetPosition(glm::vec3(0.0f, 1.5f, 10.0f));
    }

    ComponentCamera* sceneCamera = static_cast<ComponentCamera*>(
        cameraGO->CreateComponent(ComponentType::CAMERA)
        );

    if (sceneCamera)
    {
        app.camera->SetMainCamera(sceneCamera);
    }

    return true;
}


bool ModuleLoader::CleanUp()
{
    LOG_CONSOLE("FileSystem cleaned up");
    return true;
}

GameObject* ModuleLoader::LoadModel(const std::string& modelPath)
{
    UID uid = Application::GetInstance().resources.get()->Find(modelPath.c_str(), Resource::MODEL);

    if (uid != 0) return LoadModel(uid);
    else return nullptr;
}

GameObject* ModuleLoader::LoadModel(UID modelUID)
{
    bool modelLoaded = false;
    GameObject* firstLoaded = nullptr;

    if (modelUID != 0) 
    {
        ResourceModel* resource = (ResourceModel*)Application::GetInstance().resources.get()->RequestResource(modelUID);
        if (resource)
        {
            nlohmann::json modelHierarchy = resource->GetModelHierarchy();
            GameObject* root = Application::GetInstance().scene->GetRoot();

            for (const auto& jsonNode : modelHierarchy) {

                GameObject* node = GameObject::Deserialize(jsonNode, root);
                if (node && !firstLoaded) firstLoaded = node;
            }

            modelLoaded = true;
        }

        Application::GetInstance().resources.get()->ReleaseResource(modelUID);
    }

    if (!modelLoaded)
    {
        LOG_CONSOLE("[FileSystem] Failed to load model, using fallback geometry.");

        GameObject* pyramidObject = new GameObject("Pyramid");
        ComponentMesh* meshComp = static_cast<ComponentMesh*>(pyramidObject->CreateComponent(ComponentType::MESH));
        Mesh pyramidMesh = Primitives::CreatePyramid();
        meshComp->SetMesh(pyramidMesh);

        GameObject* root = Application::GetInstance().scene->GetRoot();
        root->AddChild(pyramidObject);
        
        return pyramidObject;
    }
        

    return firstLoaded;
}

GameObject* ModuleLoader::LoadPrefab(const std::string& modelPath)
{
    UID uid = Application::GetInstance().resources.get()->Find(modelPath.c_str(), Resource::PREFAB);

    if (uid != 0) return LoadPrefab(uid);
    else return nullptr;
}

GameObject* ModuleLoader::LoadPrefab(UID prefabUID)
{
    bool prefabLoaded = false;
    GameObject* firstLoaded = nullptr;

    if (prefabUID != 0)
    {
        ResourcePrefab* resource = (ResourcePrefab*)Application::GetInstance().resources.get()->RequestResource(prefabUID);
        if (resource)
        {
            nlohmann::json prefabHierarchy = resource->GetPrefabHierarchy();
            GameObject* root = Application::GetInstance().scene->GetRoot();

            for (const auto& jsonNode : prefabHierarchy) {

                GameObject* node = GameObject::Deserialize(jsonNode, root);
                if (node && !firstLoaded) firstLoaded = node;
            }

            prefabLoaded = true;
        }

        Application::GetInstance().resources.get()->ReleaseResource(prefabUID);
    }

    if (!prefabLoaded)
    {
        LOG_CONSOLE("[FileSystem] Failed to load prefab.");
    }

    return firstLoaded;
}

bool ModuleLoader::SavePrefab(GameObject* obj, const std::string& savePath)
{
    if (obj == nullptr)
    {
        LOG_CONSOLE("ERROR: No se puede guardar un Prefab de un GameObject nulo");
        return false;
    }

    LOG_CONSOLE("Guardando Prefab: %s en %s", obj->name.c_str(), savePath.c_str());

    nlohmann::json prefabArray = nlohmann::json::array();

    obj->Serialize(prefabArray);

    std::ofstream file(savePath);
    if (!file.is_open())
    {
        LOG_CONSOLE("ERROR: No se pudo abrir el archivo para guardar el prefab: %s", savePath.c_str());
        return false;
    }

    file << prefabArray.dump(4);
    file.close();

    LOG_CONSOLE("Prefab guardado exitosamente!");
    return true;
}

bool ModuleLoader::LoadTextureToGameObject(GameObject* obj, const std::string& texturePath)
{
    UID uid = Application::GetInstance().resources.get()->Find(texturePath.c_str(), Resource::TEXTURE);

    if (uid != 0) return LoadTextureToGameObject(obj, uid);
    else return false;
}

bool ModuleLoader::LoadTextureToGameObject(GameObject* obj, UID textureUID)
{
    if (!obj)
        return false;

    bool applied = false;

    ComponentMesh* meshComp = static_cast<ComponentMesh*>(obj->GetComponent(ComponentType::MESH));

    if (meshComp && meshComp->HasMesh())
    {
        ComponentMaterial* matComp = static_cast<ComponentMaterial*>(obj->GetComponent(ComponentType::MATERIAL));
        if (matComp == nullptr)
        {
            matComp = static_cast<ComponentMaterial*>(obj->CreateComponent(ComponentType::MATERIAL));
        }

        UID texUID = textureUID;

        if (texUID != 0)
        {
            const Resource* resource = Application::GetInstance().resources.get()->PeekResource(textureUID);
            if (resource)
            {
                std::string folder = GetDirectoryFromPath(resource->GetAssetFile());
                std::string matName = GetFileNameNoExtension(resource->GetAssetFile()) + "_mat.mat";
                std::string matPath = folder + "/" + matName;

                UID matUID = 0;

                if (std::filesystem::exists(matPath)) {
                    matUID = Application::GetInstance().resources->ImportFile(matPath.c_str());
                }
                else {
                    MaterialStandard* newMat = new MaterialStandard();
                    newMat->SetAlbedoMap(texUID);

                    nlohmann::json matJson;
                    newMat->SaveToJson(matJson);
                    std::ofstream o(matPath);
                    o << matJson.dump(4);
                    o.close();

                    matUID = Application::GetInstance().resources->ImportFile(matPath.c_str());
                    delete newMat;
                }

                if (matUID != 0) {
                    matComp->SetMaterial(matUID);
                    applied = true;
                }
            }
        }
    }

    return applied;
}

bool ModuleLoader::LoadMaterialToGameObject(GameObject* obj, const std::string& materialPath)
{
    UID uid = Application::GetInstance().resources.get()->Find(materialPath.c_str(), Resource::MATERIAL);

    if (uid != 0) return LoadMaterialToGameObject(obj, uid);
    else return false;
}

bool ModuleLoader::LoadMaterialToGameObject(GameObject* obj, UID materialUID)
{
    if (!obj)
        return false;

    bool applied = false;
    ComponentMesh* meshComp = static_cast<ComponentMesh*>(obj->GetComponent(ComponentType::MESH));

    if (meshComp && meshComp->HasMesh())
    {
        ComponentMaterial* material = static_cast<ComponentMaterial*>(
            obj->GetComponent(ComponentType::MATERIAL)
            );

        if (!material)
        {
            material = static_cast<ComponentMaterial*>(
                obj->CreateComponent(ComponentType::MATERIAL)
                );
        }

        if (material) 
        {
            material->SetMaterial(materialUID);
            applied = true;
        }
    }
    return applied;
}

bool ModuleLoader::LoadScene(const std::string& scenePath)
{
    UID uid = Application::GetInstance().resources.get()->Find(scenePath.c_str(), Resource::SCENE);

    if (uid != 0) 
        return LoadScene(uid);
    else return false;
}

bool ModuleLoader::LoadScene(UID sceneUID)
{
    if (sceneUID == 0) return false;

    bool success = false;
    ResourceScene* resource = (ResourceScene*)Application::GetInstance().resources->RequestResource(sceneUID);

    if (resource)
    {
        success = Application::GetInstance().scene->LoadScene(resource->GetSceneHierarchy());

        Application::GetInstance().resources->ReleaseResource(sceneUID);
    }
    else {
        LOG_CONSOLE("ERROR: Scene resource %llu could not be loaded", sceneUID);
    }

    return success;
}

bool ModuleLoader::SaveScene(const std::string& scenePath)
{
    LOG_CONSOLE("Saving scene to: %s", scenePath.c_str());

    nlohmann::json document;

    document["version"] = 1;
    
    Application::GetInstance().scene.get()->SaveScene(document);
    
    std::ofstream file(scenePath);
    if (!file.is_open()) {
        LOG_CONSOLE("ERROR: Failed to open file for writing: %s", scenePath.c_str());
        return false;
    }

    file << document.dump(4);
    file.close();

    return true;
}