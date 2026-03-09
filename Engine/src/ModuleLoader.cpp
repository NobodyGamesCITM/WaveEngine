#include "Application.h"
#include "ModuleEvents.h"
#include "ModuleLoader.h"
#include "LibraryManager.h"
#include "ComponentMesh.h"
#include "ResourceModel.h"
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
        Application::GetInstance().scene->RebuildOctree();

        return true;
    }

    // Cargar street
    fs::path streetPath = assetsPath / "Street" / "street2.fbx";
    LoadFbx(streetPath.generic_string());

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

GameObject* ModuleLoader::LoadFbx(const std::string& fbxPath)
{
    // Cargar el modelo
    bool modelLoaded = false;
    GameObject* firstLoaded = nullptr;
    UID modelUID = MetaFileManager::GetUIDFromAsset(fbxPath);
    
    if (modelUID != 0) 
    {
        
        ResourceModel* resource = (ResourceModel*)Application::GetInstance().resources.get()->RequestResource(modelUID);
        if (resource)
        {
            nlohmann::json modelHierarchy = resource->GetModelHierarchy();
            GameObject* root = Application::GetInstance().scene->GetRoot();
            LOG_CONSOLE(modelHierarchy.dump().c_str());

            for (const auto& jsonNode : modelHierarchy) {

                GameObject* node = GameObject::Deserialize(jsonNode, root);
                if (node && !firstLoaded) firstLoaded = node;
            }
            Application::GetInstance().scene->RebuildOctree();
            LOG_CONSOLE("[FileSystem] Model instanciado desde Library con éxito: %s", fbxPath.c_str());
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
        Application::GetInstance().scene->RebuildOctree();
        return pyramidObject;
    }
        

    return firstLoaded;
}

bool ModuleLoader::LoadTextureToGameObject(GameObject* obj, const std::string& texturePath)
{
    UID uid = Application::GetInstance().resources.get()->Find(texturePath.c_str());

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
    UID uid = Application::GetInstance().resources.get()->Find(materialPath.c_str());

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

