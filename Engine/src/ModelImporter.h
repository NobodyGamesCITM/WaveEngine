#pragma once

#include <string>
#include <vector>
#include <list>
#include <map>
#include <glm/glm.hpp>
#include <nlohmann/json.hpp>
#include "ResourceModel.h"

class GameObject;
class MaterialStandard;
struct MetaFile;
struct aiNode;
struct aiScene;
struct aiMesh;
struct aiMaterial;
struct ImportSettings;

class ModelImporter
{
    struct ReferedObject
    {
        std::string name;
        UID uid;
    };

public:

    static bool ImportFromFile(const std::string& filepath, const MetaFile& meta);
    static bool SaveToCustomFormat(const Model& texture, const UID& filename);
    static Model LoadFromCustomFormat(const UID& filename);

private:
    
    static GameObject* ProcessNode(aiNode* node, const aiScene* scene, const std::string& directory, std::map<std::string, UID>& referedObject, std::map<unsigned int, UID>& materialMap);
    static void CalculateBoundingBox(GameObject* obj, glm::vec3& minBounds, glm::vec3& maxBounds, const glm::mat4& parentTransform);
    static UID ProcessMesh(aiMesh* aiMesh, const aiScene* scene, const UID uid);
    static void NormalizeModelScale(GameObject* rootObject, float targetSize);
    static void FillMaterialTextures(const aiScene* scene ,aiMaterial* aiMat, MaterialStandard* outMat, const std::string& modelDirectory);
};