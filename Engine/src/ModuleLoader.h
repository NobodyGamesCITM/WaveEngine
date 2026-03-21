#pragma once

#include "Module.h"
#include <iostream>
#include <vector>
#include <string>
#include <glm/glm.hpp>
#include "ModuleResources.h"  
#include "PrefabInstance.h"
class GameObject;
struct aiNode;
struct aiScene;
struct aiMesh;
struct aiMaterial;
struct MetaFile;


// FBX/Model loading and management
class ModuleLoader : public Module
{
public:
    ModuleLoader();
    ~ModuleLoader();

    bool Awake() override;
    bool Start() override;
    bool CleanUp() override;
    
    //TEXTURES
    bool LoadTextureToGameObject(GameObject* obj, const std::string& texturePath);
    bool LoadTextureToGameObject(GameObject* obj, UID textureUID);

    //MATERIALS
    bool LoadMaterialToGameObject(GameObject* obj, const std::string& materialPath);
    bool LoadMaterialToGameObject(GameObject* obj, UID materialUID);

    //SCENES
    bool LoadScene(const std::string& scenePath);
    bool LoadScene(UID sceneUID);
    bool SaveScene(const std::string& savePath);

    //MODELS
    GameObject* LoadModel(const std::string& modelPath);
    GameObject* LoadModel(UID modelUID);

    //PREFABS
    GameObject* LoadPrefab(const std::string& modelPath);
    GameObject* LoadPrefab(UID modelUID);
    bool SavePrefab(GameObject* obj, const std::string& savePath);

    void UpdatePrefabInstances(UID prefabUID);
    void RevertInstance(GameObject* instance);
    void RecordOverride(GameObject* instance, const std::string& componentType, const nlohmann::json& overrideData);


private:
    void CollectAllGameObjects(GameObject* root, std::vector<GameObject*>& out);
    void ApplyOverridesToJson(nlohmann::json& base, const nlohmann::json& overrides);
    void ApplyJsonToGameObject(GameObject* go, const nlohmann::json& jsonData);
    void RegenerateUIDs(GameObject* go);
};