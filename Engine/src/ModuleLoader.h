#pragma once

#include "Module.h"
#include <iostream>
#include <vector>
#include <string>
#include <glm/glm.hpp>
#include "ModuleResources.h"  

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
    
    bool LoadTextureToGameObject(GameObject* obj, const std::string& texturePath);
    GameObject* LoadFbx(const std::string& assetPath);

private:
    
};