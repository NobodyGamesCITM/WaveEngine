#include "Application.h"
#include "ModelImporter.h"
#include "MeshImporter.h"
#include "AnimationImporter.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include "Log.h"
#include "GameObject.h"
#include "Component.h"
#include "Transform.h"
#include "ComponentMesh.h"
#include "ComponentSkinnedMesh.h"
#include "ComponentMaterial.h"
#include "FileUtils.h"
#include "MaterialStandard.h"

#include "ResourceModel.h"
#include "ResourceAnimation.h"

#include <assimp/scene.h>
#include <assimp/postprocess.h> 
#include <assimp/cimport.h>


bool ModelImporter::ImportFromFile(const std::string& file_path, const MetaFile& meta)
{
    Model model;

    std::string metaPath = file_path + ".meta";

    if (!std::filesystem::exists(metaPath)) {
        LOG_DEBUG("Failed importing model. Meta file doesn't exist for path: %s", file_path.c_str());
        return false;
    }

    std::map<std::string, UID> referedMeshes = meta.meshes;
    std::map<std::string, UID> referedAnimations = meta.animations;

    unsigned int importFlags = aiProcess_Triangulate |
        aiProcess_JoinIdenticalVertices |
        aiProcess_ValidateDataStructure | 
        aiProcess_CalcTangentSpace;

    if (meta.importSettings.generateNormals) {
        importFlags |= aiProcess_GenNormals;
    }

    if (meta.importSettings.flipUVs) {
        importFlags |= aiProcess_FlipUVs;
    }

    if (meta.importSettings.optimizeMeshes) {
        importFlags |= aiProcess_OptimizeMeshes;
    }

    const aiScene* scene = aiImportFile(file_path.c_str(), importFlags);

    if (scene == nullptr)
    {
        LOG_CONSOLE("ERROR: Failed to load model - %s", aiGetErrorString());
        return false;
    }

    bool hasMaterials = scene->HasMaterials();
    std::map<unsigned int, UID> materialMap;

    if (hasMaterials)
    {
        for (unsigned int i = 0; i < scene->mNumMaterials; i++)
        {
            aiMaterial* assimpMat = scene->mMaterials[i];

            aiString matName;
            assimpMat->Get(AI_MATKEY_NAME, matName);
            std::string nameStr = matName.C_Str();
            std::string directory = GetDirectoryFromPath(file_path);
            if (nameStr.empty()) nameStr = "Material_" + std::to_string(i);

            std::string materialAssetPath = directory + "/" + nameStr + ".mat";

            UID matUID = 0;
            if (std::filesystem::exists(materialAssetPath)) {
                matUID = Application::GetInstance().resources->ImportFile(materialAssetPath.c_str());
            }
            else {

                MaterialStandard* newMat = new MaterialStandard();

                FillMaterialTextures(scene ,assimpMat, newMat, directory);

                nlohmann::json matJson;
                newMat->SaveToJson(matJson);
                std::ofstream o(materialAssetPath);
                o << matJson.dump(4);
                o.close();

                matUID = Application::GetInstance().resources->ImportFile(materialAssetPath.c_str());
                delete newMat;
            }

            materialMap[i] = matUID;
        }
    }

    bool hasAnimations = scene->HasAnimations();
    bool hasMeshes = scene->HasMeshes();

    GameObject* rootObj = nullptr;
    std::string directory = file_path.substr(0, file_path.find_last_of("/\\"));
    rootObj = ProcessNode(scene->mRootNode, scene, directory, referedMeshes, materialMap);

    rootObj->name = GetFileNameNoExtension(file_path);
    rootObj->objectUID = 0;

    if (hasAnimations)
    {
        for (unsigned int i = 0; i < scene->mNumAnimations; i++)
        {
            aiAnimation* assimpAnim = scene->mAnimations[i];

            std::string animName = assimpAnim->mName.C_Str();
            if (animName.empty()) animName = "Animation_" + std::to_string(i);

            UID animUID = 0;

            if (referedAnimations.find(animName) != referedAnimations.end())
            {
                animUID = referedAnimations[animName];
            }
            else
            {
                animUID = GenerateUID();
                referedAnimations[animName] = animUID;
            }

            Animation animData = AnimationImporter::ImportFromAssimp(assimpAnim);

            if (animData.IsValid())
            {
                AnimationImporter::SaveToCustomFormat(animData, animUID);
                LOG_DEBUG("Animation '%s' imported successfully.", animName.c_str());
            }
            else
            {
                LOG_DEBUG("Failed to import animation '%s'.", animName.c_str());
            }
        }
    }

    if (hasMeshes)
    {
        LOG_CONSOLE("Found %d meshes, %d materials", scene->mNumMeshes, scene->mNumMaterials);

        glm::vec3 minBounds(std::numeric_limits<float>::max());
        glm::vec3 maxBounds(std::numeric_limits<float>::lowest());
        glm::mat4 identity(1.0f);

        CalculateBoundingBox(rootObj, minBounds, maxBounds, identity);
        NormalizeModelScale(rootObj, 5.0f);
    }
    else
    {
        LOG_CONSOLE("[ModelImporter] Info: El FBX no contiene geometría. Solo se ha importado la jerarquía (huesos) y/o animaciones.");
    }

    Transform* rootTransform = static_cast<Transform*>(rootObj->GetComponent(ComponentType::TRANSFORM));

    if (rootTransform && meta.uid != 0) {
        if (meta.importSettings.importScale != 1.0f) {
            glm::vec3 currentScale = rootTransform->GetScale();
            glm::vec3 newScale = currentScale * meta.importSettings.importScale;
            rootTransform->SetScale(newScale);
            LOG_DEBUG("[FileSystem] Applied import scale: %.3f", meta.importSettings.importScale);
        }

        glm::quat axisRotation = glm::quat(1.0f, 0.0f, 0.0f, 0.0f); // Identity quaternion

        if (meta.importSettings.upAxis == 1) {
            axisRotation = glm::angleAxis(glm::radians(-90.0f), glm::vec3(1.0f, 0.0f, 0.0f)) * axisRotation;
            LOG_DEBUG("[FileSystem] Applying Z-Up conversion");
        }
        if (meta.importSettings.frontAxis == 1) {
            axisRotation = glm::angleAxis(glm::radians(90.0f), glm::vec3(1.0f, 0.0f, 0.0f)) * axisRotation;
            LOG_DEBUG("[FileSystem] Applying Y-Forward conversion");
        }
        else if (meta.importSettings.frontAxis == 2) {
            axisRotation = glm::angleAxis(glm::radians(-90.0f), glm::vec3(0.0f, 1.0f, 0.0f)) * axisRotation;
            LOG_DEBUG("[FileSystem] Applying X-Forward conversion");
        }

        glm::quat currentRotation = rootTransform->GetRotationQuat();
        glm::quat newRotation = axisRotation * currentRotation;
        rootTransform->SetRotationQuat(newRotation);
    }

    meta.meshes = referedMeshes;
    meta.animations = referedAnimations;
    meta.Save(metaPath);

    aiReleaseImport(scene);

    LOG_CONSOLE("Model loaded successfully: %s", file_path.c_str());

    nlohmann::json gameObjectHierarchy;
    rootObj->Serialize(gameObjectHierarchy);
    model.modelJson = gameObjectHierarchy;
    delete rootObj;

    return SaveToCustomFormat(model, meta.uid);
}
GameObject* ModelImporter::ProcessNode(aiNode* node, const aiScene* scene, const std::string& directory, std::map<std::string, UID>& referedMeshes, std::map<unsigned int, UID>& materialMap)
{
    std::string nodeName = node->mName.C_Str();
    if (nodeName.empty()) nodeName = "Unnamed";

    GameObject* gameObject = new GameObject(nodeName);
    gameObject->objectUID = 0;

    Transform* transform = static_cast<Transform*>(gameObject->GetComponent(ComponentType::TRANSFORM));

    if (transform != nullptr)
    {
        aiVector3D position, scaling;
        aiQuaternion rotation;
        node->mTransformation.Decompose(scaling, rotation, position);

        transform->SetPosition(glm::vec3(position.x, position.y, position.z));
        transform->SetScale(glm::vec3(scaling.x, scaling.y, scaling.z));
        transform->SetRotationQuat(glm::quat(rotation.w, rotation.x, rotation.y, rotation.z));
    }

    // Process meshes for this node
    for (unsigned int i = 0; i < node->mNumMeshes; i++)
    {
        unsigned int meshIndex = node->mMeshes[i];
        aiMesh* aiMesh = scene->mMeshes[meshIndex];
        std::string meshName = aiMesh->mName.C_Str();
        if (meshName.empty()) {
            meshName = "UnnamedMesh_" + std::to_string(meshIndex);
        }
        UID meshUID = 0;

        if (referedMeshes.find(meshName) != referedMeshes.end()) {
            meshUID = referedMeshes[meshName];
        }
        else {
            
            meshUID = GenerateUID();
            referedMeshes[meshName] = meshUID;
        }

        ProcessMesh(aiMesh, scene, meshUID);

        if (meshUID != 0)
        {
            Component* newComp = nullptr;

            if (aiMesh->HasBones())
            {
                newComp = gameObject->CreateComponent(ComponentType::SKINNED_MESH);
            }
            else
            {
                newComp = gameObject->CreateComponent(ComponentType::MESH);
            }

            if (newComp)
            {
                ComponentMesh* meshRenderer = static_cast<ComponentMesh*>(newComp);
                meshRenderer->LoadMeshByUID(meshUID);
            }
        }

        if (aiMesh->mMaterialIndex >= 0)
        {
            // Obtenemos el UID que generamos previamente para este índice de material
            UID matUID = materialMap[aiMesh->mMaterialIndex];

            if (matUID != 0)
            {
                // Creamos el componente de material en el GameObject
                ComponentMaterial* matComp = static_cast<ComponentMaterial*>(
                    gameObject->CreateComponent(ComponentType::MATERIAL));

                if (matComp)
                {
                    // Cargamos el recurso material usando el UID
                    matComp->SetMaterial(matUID);
                    LOG_DEBUG("Assigned material UID %llu to mesh %s", matUID, meshName.c_str());
                }
            }
        }
    }

    // Process child nodes recursively
    for (unsigned int i = 0; i < node->mNumChildren; i++)
    {
        GameObject* child = ProcessNode(node->mChildren[i], scene, directory, referedMeshes, materialMap);
        if (child != nullptr)
        {
            gameObject->AddChild(child);
        }
    }

    return gameObject;
}

UID ModelImporter::ProcessMesh(aiMesh* aiMesh, const aiScene* scene, const UID uid)
{
    ModuleResources* resources = Application::GetInstance().resources.get();
    if (!resources) {
        LOG_CONSOLE("ERROR: ModuleResources not available");
        return 0;
    }

    // BaseUID (from .meta) + mesh index
    UID meshUID = uid;

    // Import and save mesh
    Mesh mesh = MeshImporter::ImportFromAssimp(aiMesh);

    if (mesh.vertices.empty() || mesh.indices.empty()) {
        LOG_CONSOLE("ERROR: Failed to import mesh");
        return 0;
    }

    // Save to Library using UID-based filename
    if (!MeshImporter::SaveToCustomFormat(mesh, meshUID)) {
        LOG_CONSOLE("ERROR: Failed to save mesh to Library");
        return 0;
    }

    // Register mesh in ModuleResources
    std::string libraryPath = LibraryManager::GetLibraryPathFromUID(meshUID);

    Resource* newResource = resources->CreateNewResourceWithUID(
        libraryPath.c_str(),
        Resource::MESH,
        meshUID
    );

    if (!newResource) {
        LOG_CONSOLE("ERROR: Failed to create resource");
        return 0;
    }

    newResource->SetLibraryFile(libraryPath);

    return meshUID;
}

void ModelImporter::NormalizeModelScale(GameObject* rootObject, float targetSize)
{
    glm::vec3 minBounds(std::numeric_limits<float>::max());
    glm::vec3 maxBounds(std::numeric_limits<float>::lowest());

    glm::mat4 identity(1.0f);
    CalculateBoundingBox(rootObject, minBounds, maxBounds, identity);

    glm::vec3 size = maxBounds - minBounds;
    float maxDimension = std::max({ size.x, size.y, size.z });

    if (maxDimension > 0.0f)
    {
        float scale = targetSize / maxDimension;
        Transform* t = static_cast<Transform*>(rootObject->GetComponent(ComponentType::TRANSFORM));
        if (t != nullptr)
        {
            glm::vec3 currentScale = t->GetScale();
            t->SetScale(currentScale * scale);
        }

        LOG_CONSOLE("Model scaled to fit viewport (scale: %.4f)", scale);
    }
}

void ModelImporter::CalculateBoundingBox(GameObject* obj, glm::vec3& minBounds, glm::vec3& maxBounds, const glm::mat4& parentTransform)
{
    Transform* t = static_cast<Transform*>(obj->GetComponent(ComponentType::TRANSFORM));
    glm::mat4 localTransform(1.0f);

    if (t != nullptr)
    {
        glm::vec3 pos = t->GetPosition();
        glm::vec3 scale = t->GetScale();
        glm::quat rot = t->GetRotationQuat();

        glm::mat4 translation = glm::translate(glm::mat4(1.0f), pos);
        glm::mat4 rotation = glm::mat4_cast(rot);
        glm::mat4 scaleMatrix = glm::scale(glm::mat4(1.0f), scale);

        localTransform = translation * rotation * scaleMatrix;
    }

    glm::mat4 worldTransform = parentTransform * localTransform;

    ComponentMesh* meshComp = static_cast<ComponentMesh*>(obj->GetComponent(ComponentType::MESH));
    if (meshComp != nullptr)
    {
        const Mesh& mesh = meshComp->GetMesh();

        for (const auto& vertex : mesh.vertices)
        {
            glm::vec4 worldPos = worldTransform * glm::vec4(vertex.position, 1.0f);
            glm::vec3 pos3(worldPos.x, worldPos.y, worldPos.z);

            minBounds.x = std::min(minBounds.x, pos3.x);
            minBounds.y = std::min(minBounds.y, pos3.y);
            minBounds.z = std::min(minBounds.z, pos3.z);

            maxBounds.x = std::max(maxBounds.x, pos3.x);
            maxBounds.y = std::max(maxBounds.y, pos3.y);
            maxBounds.z = std::max(maxBounds.z, pos3.z);
        }
    }

    for (GameObject* child : obj->GetChildren())
    {
        CalculateBoundingBox(child, minBounds, maxBounds, worldTransform);
    }
}

bool ModelImporter::SaveToCustomFormat(const Model& model, const UID& uid)
{
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);
    std::ofstream file(fullPath, std::ios::out | std::ios::binary);

    if (file.is_open())
    {
        try
        {
            std::vector<uint8_t> msgpackData = nlohmann::json::to_msgpack(model.modelJson);

            file.write(reinterpret_cast<const char*>(msgpackData.data()), msgpackData.size());
            file.close();

            LOG_CONSOLE("[ModelImporter] Guardado modelo binario: %s", fullPath.c_str());
            return true;
        }
        catch (const nlohmann::json::exception& e)
        {
            LOG_CONSOLE("[ModelImporter] ERROR crítico guardando MsgPack en %s: %s", fullPath.c_str(), e.what());
            file.close();
            return false;
        }
    }

    LOG_CONSOLE("[ModelImporter] ERROR: No se pudo abrir para escribir: %s", fullPath.c_str());
    return false;
}

Model ModelImporter::LoadFromCustomFormat(const UID& uid)
{
    Model model;
    std::string fullPath = LibraryManager::GetLibraryPathFromUID(uid);

    std::ifstream file(fullPath, std::ios::in | std::ios::binary | std::ios::ate);

    if (file.is_open())
    {
        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        if (size > 0)
        {
            std::vector<uint8_t> msgpackData(size);
            file.read(reinterpret_cast<char*>(msgpackData.data()), size);

            try
            {
                model.modelJson = nlohmann::json::from_msgpack(msgpackData);
                LOG_CONSOLE("[ModelImporter] Modelo binario cargado: %s", fullPath.c_str());
            }
            catch (const nlohmann::json::parse_error& e)
            {
                LOG_CONSOLE("[ModelImporter] ERROR parseando MsgPack en %s: %s", fullPath.c_str(), e.what());
            }
        }

        file.close();
    }
    else
    {
        LOG_CONSOLE("[ModelImporter] ERROR: No se pudo abrir para leer: %s", fullPath.c_str());
    }

    return model;
}

void ModelImporter::FillMaterialTextures(const aiScene* scene, aiMaterial* aiMat, MaterialStandard* outMat, const std::string& modelDirectory)
{
    std::map<aiTextureType, std::string> typesToImport = {
    { aiTextureType_DIFFUSE, "Albedo" },
    { aiTextureType_BASE_COLOR, "Albedo" },
    { aiTextureType_NORMALS, "Normal" },
    { aiTextureType_HEIGHT, "Height" },
    { aiTextureType_METALNESS, "Metallic" },
    { aiTextureType_AMBIENT_OCCLUSION, "Occlusion" },
    { aiTextureType_LIGHTMAP, "Occlusion" }
    };

    for (auto const& [aiType, slotName] : typesToImport)
    {
        if (aiMat->GetTextureCount(aiType) > 0)
        {
            aiString texPath;
            if (aiMat->GetTexture(aiType, 0, &texPath) == AI_SUCCESS)
            {
                std::string finalPath = "";
                std::string fileName = GetFileName(texPath.C_Str());

                const aiTexture* embeddedTex = scene->GetEmbeddedTexture(texPath.C_Str());
                if (embeddedTex != nullptr)
                {
                    std::string extension = (embeddedTex->achFormatHint[0] != '\0') ? embeddedTex->achFormatHint : "png";
                    std::string embeddedName = fileName.empty() ? (slotName + "_Embedded." + extension) : fileName;
                    finalPath = modelDirectory + "/" + embeddedName;

                    std::ofstream out(finalPath, std::ios::binary);
                    if (embeddedTex->mHeight == 0) {
                        out.write((char*)embeddedTex->pcData, embeddedTex->mWidth);
                    }
                    else {
                        out.write((char*)embeddedTex->pcData, embeddedTex->mWidth * embeddedTex->mHeight * 4);
                    }
                    out.close();
                    LOG_DEBUG("Extracted embedded texture to: %s", finalPath.c_str());
                }
                else
                {
                    finalPath = FindFileInDirectory(modelDirectory, fileName);
                    if (finalPath.empty()) {
                        finalPath = FindFileInDirectory("Assets", fileName);
                    }
                }

                if (!finalPath.empty() && DoesFileExist(finalPath))
                {
                    UID texUID = Application::GetInstance().resources->ImportFile(finalPath.c_str());
                    if (texUID != 0)
                    {
                        if (slotName == "Albedo") outMat->SetAlbedoMap(texUID);
                        else if (slotName == "Normal") outMat->SetNormalMap(texUID);
                        else if (slotName == "Height") outMat->SetHeightMap(texUID);
                        else if (slotName == "Metallic") outMat->SetMetallicMap(texUID);
                        else if (slotName == "Occlusion") outMat->SetOcclusionMap(texUID);
                    }
                }
                else {
                    LOG_DEBUG("[ModelImporter] Could not find texture file: %s", fileName.c_str());
                }
            }
        }
    }
}