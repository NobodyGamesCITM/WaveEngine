#include "ModuleResources.h"
#include "ResourceTexture.h"
#include "ResourceMesh.h"
#include "ResourceModel.h"
#include "ResourceShader.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include "TextureImporter.h"
#include "ModelImporter.h"
#include "MeshImporter.h"
#include "MaterialImporter.h"
#include "Log.h"
#include "ResourceScript.h"
#include "ResourcePrefab.h"
#include "ResourceAnimation.h"
#include "ResourceMaterial.h"
#include <filesystem>
#include <random>

// Resource Implementation
Resource::Resource(UID uid, Type type)
    : uid(uid), type(type), referenceCount(0) {
}

Resource::~Resource() {
}

// ModuleResources Implementation
ModuleResources::ModuleResources() : Module() {
}

ModuleResources::~ModuleResources() {
}

bool ModuleResources::Awake() {
    return true;
}

bool ModuleResources::Start() {
    LOG_CONSOLE("[ModuleResources] Initializing...");

    LibraryManager::Initialize();
    LOG_CONSOLE("[ModuleResources] Library structure created");

    MetaFileManager::Initialize();
    LOG_CONSOLE("[ModuleResources] Asset metadata synchronized");

    LoadResourcesFromMetaFiles();

#ifndef WAVE_GAME
    LOG_CONSOLE("[ModuleResources] Importing assets to Library...");
    LibraryManager::RegenerateFromAssets();
#endif

    LOG_CONSOLE("[ModuleResources] Initialized successfully");

    return true;
}

bool ModuleResources::Update() {
    return true;
}

bool ModuleResources::CleanUp() {

    shuttingDown = true;

    for (auto& pair : resources) {

        if (pair.second->IsLoadedToMemory()) {
            pair.second->UnloadFromMemory();
        }
    }

    for (auto& pair : resources) {
        delete pair.second;
    }

    resources.clear();

    LOG_CONSOLE("[ModuleResources] Cleaned up successfully");
    return true;
}

void ModuleResources::LoadResourcesFromMetaFiles() {
    
    LOG_CONSOLE("[ModuleResources] Registering resources from meta files...");

    std::string assetsPath = LibraryManager::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        LOG_CONSOLE("ERROR: Assets folder not found");
        return;
    }

    int registered = 0;
    int skipped = 0;


    int prefabsFound = 0;
    int prefabsRegistered = 0;

    for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
       
        if (!entry.is_regular_file()) continue;

        std::string assetPath = entry.path().string();
        std::string extension = entry.path().extension().string();

        if (extension == ".meta") continue;

        AssetType assetType = MetaFile::GetAssetType(extension);

        if (extension == ".prefab") {
            LOG_CONSOLE("[ModuleResources] Found .prefab file: %s", assetPath.c_str());
            LOG_CONSOLE("[ModuleResources] AssetType: %d (7=PREFAB expected)", (int)assetType);
        }

        if (assetType == AssetType::UNKNOWN) continue;

        std::string metaPath = assetPath + ".meta";
        if (!std::filesystem::exists(metaPath)) {

            if (extension == ".prefab") {
                LOG_CONSOLE("[ModuleResources] No .meta file for prefab: %s", assetPath.c_str());
            }
            skipped++;
            continue;
        }

        MetaFile meta = MetaFile::Load(metaPath);

        if (meta.uid == 0) {

            if (extension == ".prefab") {
                LOG_CONSOLE("[ModuleResources] Invalid UID in .meta for prefab: %s", assetPath.c_str());
            }
            skipped++;
            continue;
        }

        Resource* resource = nullptr;
        Resource::Type resourceType = Resource::UNKNOWN;

        switch (assetType) {
        case AssetType::TEXTURE_PNG:
        case AssetType::TEXTURE_JPG:
        case AssetType::TEXTURE_DDS:
        case AssetType::TEXTURE_TGA:
            resourceType = Resource::TEXTURE;
            resource = new ResourceTexture(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPathFromUID(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::MODEL_FBX:
            
            resourceType = Resource::MODEL;
            resource = new ResourceModel(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPathFromUID(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            
            for (const auto& [meshName, meshUID] : meta.meshes) {

                std::string meshPath = LibraryManager::GetLibraryPathFromUID(meshUID);

                if (std::filesystem::exists(meshPath)) {
                    ResourceMesh* meshResource = new ResourceMesh(meshUID);
                    meshResource->SetAssetFile(assetPath);
                    meshResource->SetLibraryFile(meshPath);
                    resources[meshUID] = meshResource;
                    registered++;
                }
                else {
                    LOG_CONSOLE("[ModuleResources] WARNING: Archivo binario no encontrado para la malla %s (UID: %llu)", meshName.c_str(), meshUID);
                }
            }
            for (const auto& [animationName, animationUID] : meta.animations) {

                std::string animationPath = LibraryManager::GetLibraryPathFromUID(animationUID);

                if (std::filesystem::exists(animationPath)) {
                    ResourceAnimation* animationResource = new ResourceAnimation(animationUID);
                    animationResource->SetAssetFile(assetPath);
                    animationResource->SetLibraryFile(animationPath);
                    resources[animationUID] = animationResource;
                    registered++;
                }
                else {
                    LOG_CONSOLE("[ModuleResources] WARNING: Archivo binario no encontrado para la animacion %s (UID: %llu)", animationName.c_str(), animationUID);
                }
            }
            break;

        case AssetType::SHADER_GLSL:
            resourceType = Resource::SHADER;
            resource = new ResourceShader(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile("");
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::SCRIPT_LUA:
            resourceType = Resource::SCRIPT;
            resource = new ResourceScript(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(assetPath);
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::PREFAB:
            prefabsFound++;
            LOG_CONSOLE("[ModuleResources] Processing prefab: %s", assetPath.c_str());
            LOG_CONSOLE("[ModuleResources] Prefab UID: %llu", meta.uid);

            resourceType = Resource::PREFAB;
            resource = new ResourcePrefab(meta.uid);  

            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(assetPath);
                resources[meta.uid] = resource;
                prefabsRegistered++;
                registered++;
            }
            break;
        case AssetType::MATERIAL:

            resourceType = Resource::MATERIAL;
            resource = new ResourceMaterial(meta.uid);  

            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(assetPath);
                resources[meta.uid] = resource;
                registered++;
            }
            break;
        default:
            continue;
        }
    }

    LOG_CONSOLE("[ModuleResources] Resources registered: %d, skipped: %d",
        registered, skipped);


    LOG_CONSOLE("[ModuleResources] Prefabs found: %d, registered: %d", prefabsFound, prefabsRegistered);


    LOG_CONSOLE("[ModuleResources] LISTING ALL PREFABS");
    for (const auto& [uid, res] : resources) {
        if (res->GetType() == Resource::PREFAB) {
            LOG_CONSOLE("[ModuleResources]   - Prefab: %s (UID: %llu)",
                res->GetAssetFile().c_str(), uid);
        }
    }
    LOG_CONSOLE("[ModuleResources] === END OF PREFAB LIST ===");
}

UID ModuleResources::Find(const char* fileInAssets) const {
    for (const auto& pair : resources) {
        if (pair.second->GetAssetFile() == fileInAssets) {
            return pair.second->GetUID();
        }
    }

    UID uid = MetaFileManager::GetUIDFromAsset(fileInAssets);
    return uid;
}

UID ModuleResources::ImportFile(const char* newFileInAssets, bool forceReimport) {

    MetaFile meta = MetaFileManager::GetOrCreateMeta(newFileInAssets);

    if (meta.uid == 0) {
        LOG_CONSOLE("ERROR: Failed to create UID for: %s", newFileInAssets);
        return 0;
    }

    std::filesystem::path path(newFileInAssets);
    std::string extension = path.extension().string();
    Resource::Type type = GetResourceTypeFromExtension(extension);

    if (type == Resource::UNKNOWN) {
        LOG_CONSOLE("ERROR: Unknown file type: %s", extension.c_str());
        return 0;
    }

    Resource* resource = nullptr;
    auto it = resources.find(meta.uid);

    if (it != resources.end()) {
        if (!forceReimport && std::filesystem::exists(LibraryManager::GetLibraryPathFromUID(meta.uid))) {
            return meta.uid;
        }
        resource = it->second;
    }
    else {
        resource = CreateNewResourceWithUID(newFileInAssets, type, meta.uid);
        if (!resource) {
            LOG_CONSOLE("ERROR: Failed to create resource");
            return 0;
        }
    }

    bool importSuccess = false;

    switch (type) {
    case Resource::TEXTURE: {
        importSuccess = ImportTexture(resource, newFileInAssets);
        break;
    }
    case Resource::MESH: {
        importSuccess = ImportMesh(resource, newFileInAssets);
        break;
    }
    case Resource::MODEL: {
        importSuccess = ImportModel(resource, newFileInAssets);
        break;
    }
    case Resource::SHADER: {
        importSuccess = true;
        break;
    }
    case Resource::SCRIPT: {
        importSuccess = ImportScript(resource, newFileInAssets);
        break;
    }
    case Resource::PREFAB: {
        importSuccess = ImportPrefab(resource, newFileInAssets);
        break;
    }
    case Resource::MATERIAL: {
        importSuccess = ImportMaterial(resource, newFileInAssets);
        break;
    }
    default:
        LOG_CONSOLE("ERROR: Import not implemented for this type");
        break;
    }

    if (!importSuccess) {
        LOG_CONSOLE("ERROR: Import failed for: %s", newFileInAssets);

        if (it == resources.end()) {
            delete resource;
            resources.erase(meta.uid);
        }
        return 0;
    }

    if (resource->IsLoadedToMemory())
    {
        resource->UnloadFromMemory();
        resource->LoadInMemory();
    }

    uint32_t fileHash = MetaFileManager::GetFileHash(newFileInAssets);
    if (meta.fileHash != fileHash) {
        meta.fileHash = fileHash;
        std::string metaPath = std::string(newFileInAssets) + ".meta";
        meta.Save(metaPath);
    }

    return meta.uid;
}

Resource* ModuleResources::CreateNewResourceWithUID(const char* assetsFile, Resource::Type type, UID uid) {
    Resource* resource = nullptr;

    switch (type) {
    case Resource::TEXTURE:
        resource = new ResourceTexture(uid);
        break;
    case Resource::MESH:
        resource = new ResourceMesh(uid);
        break;
    case Resource::MODEL:
        resource = new ResourceModel(uid);
        break;
    case Resource::SHADER:
        resource = new ResourceShader(uid);
        break;
    case Resource::SCRIPT:  
        resource = new ResourceScript(uid);
        break;
    case Resource::PREFAB:
        resource = new ResourcePrefab(uid);
        break;
    case Resource::MATERIAL:
        resource = new ResourceMaterial(uid);
        break;
    default:
        LOG_CONSOLE("ERROR: Unsupported resource type");
        return nullptr;
    }

    if (resource) {
        resource->SetAssetFile(assetsFile);

        // Scripts NO van a Library
        if (type == Resource::SCRIPT || type == Resource::PREFAB) {
            resource->SetLibraryFile(assetsFile);
        }
        else if (type == Resource::TEXTURE) {
            resource->SetLibraryFile(LibraryManager::GetLibraryPathFromUID(uid));
        }
        else if (type == Resource::MESH) {
            resource->SetLibraryFile(LibraryManager::GetLibraryPathFromUID(uid));
        }

        resources[uid] = resource;
    }

    return resource;
}

UID ModuleResources::GenerateNewUID() {
    random_device rd;
    mt19937_64 gen(rd());
    uniform_int_distribution<UID> dis;

    UID uid = 0;

    do {
        uid = dis(gen);
    } while (resources.find(uid) != resources.end() || uid == 0);

    return uid;
}

const Resource* ModuleResources::RequestResource(UID uid) const {
    return const_cast<ModuleResources*>(this)->RequestResource(uid);
}

Resource* ModuleResources::RequestResource(UID uid) {
    
    auto it = resources.find(uid);

    if (it != resources.end()) {
        Resource* resource = it->second;

        if (!resource->IsLoadedToMemory()) {
            if (!resource->LoadInMemory()) {
                LOG_CONSOLE("ERROR: Failed to load resource %llu into memory", uid);
                return nullptr;
            }
        }

        resource->referenceCount++;
        return resource;
    }

    Resource* resource = LoadResourceFromLibrary(uid);

    if (resource) {
        resource->referenceCount++;
        return resource;
    }

    LOG_CONSOLE("ERROR: Resource %llu not found", uid);
    return nullptr;
}

const Resource* ModuleResources::PeekResource(UID uid)
{
    auto it = resources.find(uid);
    if (it != resources.end())
    {
        return it->second;
    }
    return nullptr;
}

void ModuleResources::ReleaseResource(UID uid) {
    auto it = resources.find(uid);

    if (it == resources.end()) {
        return;
    }

    Resource* resource = it->second;

    if (resource->referenceCount > 0) {
        resource->referenceCount--;

        if (resource->referenceCount == 0 && resource->IsLoadedToMemory()) {
            resource->UnloadFromMemory();
        }
    }
}

Resource::Type ModuleResources::GetResourceTypeFromExtension(const std::string& extension) const {
    std::string ext = extension;
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

    if (ext == ".png" || ext == ".jpg" || ext == ".jpeg" ||
        ext == ".dds" || ext == ".tga") {
        return Resource::TEXTURE;
    }

    if (ext == ".fbx" || ext == ".obj") {
        return Resource::MODEL;
    }

    if (ext == ".mesh") {
        return Resource::MESH;
    }

    if (ext == ".glsl") {
        return Resource::SHADER;
    }
    if (ext == ".lua") {  
        return Resource::SCRIPT;
    }
    if (ext == ".prefab") { 
        return Resource::PREFAB;
    }
    if (ext == ".mat") { 
        return Resource::MATERIAL;
    }

    return Resource::UNKNOWN;
}
Resource* ModuleResources::CreateNewResource(const char* assetsFile, Resource::Type type) {
    UID uid = GenerateNewUID();
    return CreateNewResourceWithUID(assetsFile, type, uid);
}

std::string ModuleResources::GenerateLibraryPath(Resource* resource) {
    
    if (!resource) return "";
    return LibraryManager::GetLibraryPathFromUID(resource->GetUID());
}

Resource* ModuleResources::LoadResourceFromLibrary(UID uid) {
    return nullptr;
}

void ModuleResources::SaveResourceMetadata(Resource* resource) {
}

bool ModuleResources::LoadResourceMetadata(UID uid) {
    return false;
}

bool ModuleResources::ImportTexture(Resource* resource, const std::string& assetPath) {
    
    std::string libraryPath = LibraryManager::GetLibraryPathFromUID(resource->GetUID());

    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        // If .meta doesn't exist, create one with appropriate defaults
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        std::filesystem::path path(assetPath);
        std::string extension = path.extension().string();
        std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);

        if (extension == ".tga") {
            meta.importSettings.flipUVs = false;  // TGA already comes flipped
        }
        else {
            meta.importSettings.flipUVs = true;   // PNG/JPG need flip
        }

        meta.Save(metaPath);
    }

    TextureData textureData = TextureImporter::ImportFromFile(assetPath, meta.importSettings);

    if (!textureData.IsValid()) {
        LOG_CONSOLE("ERROR: Failed to import texture: %s", assetPath.c_str());
        return false;
    }

    if (!TextureImporter::SaveToCustomFormat(textureData, meta.uid)) {
        LOG_CONSOLE("ERROR: Failed to save texture to Library");
        return false;
    }

    resource->SetLibraryFile(libraryPath);
    return true;
}

bool ModuleResources::ImportMesh(Resource* resource, const std::string& assetPath) {
    LOG_CONSOLE("ERROR: Direct mesh import not supported");
    return false;
}

bool ModuleResources::ImportMaterial(Resource* resource, const std::string& assetPath) {
    
    std::string libraryPath = LibraryManager::GetLibraryPathFromUID(resource->GetUID());

    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    if (MaterialImporter::ImportMaterial(assetPath, meta.uid))
        resource->SetLibraryFile(libraryPath);
    
    return true;
}

bool ModuleResources::ImportModel(Resource* resource, const std::string& assetPath) {
    
    std::string libraryPath = LibraryManager::GetLibraryPathFromUID(resource->GetUID());

    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    Model modelData = ModelImporter::ImportFromFile(assetPath);

    if (!modelData.IsValid()) {
        LOG_CONSOLE("ERROR: Failed to import model: %s", assetPath.c_str());
        return false;
    }

    if (!ModelImporter::SaveToCustomFormat(modelData, meta.uid)) {
        LOG_CONSOLE("ERROR: Failed to save model to Library");
        return false;
    }

    resource->SetLibraryFile(libraryPath);
    return true;
}

bool ModuleResources::GetResourceInfo(UID uid, std::string& outAssetPath, std::string& outLibraryPath) {
    auto it = resources.find(uid);
    if (it != resources.end()) {
        outAssetPath = it->second->GetAssetFile();
        outLibraryPath = it->second->GetLibraryFile();
        return true;
    }

    outAssetPath = MetaFileManager::GetAssetFromUID(uid);
    if (!outAssetPath.empty()) {

        MetaFile meta = MetaFileManager::LoadMeta(outAssetPath);

        switch (meta.type) {
        case AssetType::TEXTURE_PNG:
        case AssetType::TEXTURE_JPG:
        case AssetType::TEXTURE_DDS:
        case AssetType::TEXTURE_TGA:
            outLibraryPath = LibraryManager::GetLibraryPathFromUID(uid);
            break;
        case AssetType::MODEL_FBX:
            outLibraryPath = LibraryManager::GetLibraryPathFromUID(uid);
            break;
        default:
            outLibraryPath = "";
            break;
        }
        return true;
    }

    return false;
}

void ModuleResources::RemoveResource(UID uid) {
    auto it = resources.find(uid);

    if (it == resources.end()) {
        return;
    }

    Resource* resource = it->second;

    if (resource->GetReferenceCount() > 0) {
        LOG_CONSOLE("[ModuleResources] WARNING: Removing resource %llu that still has %u references",
            uid, resource->GetReferenceCount());
    }

    if (resource->IsLoadedToMemory()) {
        resource->UnloadFromMemory();
    }

    delete resource;
    resources.erase(it);

    LOG_CONSOLE("[ModuleResources] Resource %llu removed from system", uid);
}

bool ModuleResources::IsResourceLoaded(UID uid) const {
    auto it = resources.find(uid);
    if (it == resources.end()) {
        return false;
    }

    return it->second->IsLoadedToMemory();
}

unsigned int ModuleResources::GetResourceReferenceCount(UID uid) const {
    auto it = resources.find(uid);
    if (it == resources.end()) {
        return 0;
    }

    return it->second->GetReferenceCount();
}

const Resource* ModuleResources::GetResource(UID uid) const {
    auto it = resources.find(uid);
    if (it == resources.end()) {
        return nullptr;
    }

    return it->second;
}

bool ModuleResources::ImportScript(Resource* resource, const std::string& assetPath) {
    // Scripts don't need importing - they stay in Assets/
    // Just verify the file exists
    if (!std::filesystem::exists(assetPath)) {
        LOG_CONSOLE("ERROR: Script file not found: %s", assetPath.c_str());
        return false;
    }

    resource->SetAssetFile(assetPath);
    resource->SetLibraryFile(assetPath);  // Scripts reference themselves

    LOG_CONSOLE("[ModuleResources] Script registered: %s (UID: %llu)",
        assetPath.c_str(), resource->GetUID());

    return true;
}

bool ModuleResources::ImportPrefab(Resource* resource, const std::string& assetPath) {
    if (!std::filesystem::exists(assetPath)) {
        LOG_CONSOLE("ERROR: Prefab file not found: %s", assetPath.c_str());
        return false;
    }

    // Try to parse JSON to verify it's valid
    std::ifstream file(assetPath);
    if (!file.is_open()) {
        LOG_CONSOLE("ERROR: Cannot open prefab file: %s", assetPath.c_str());
        return false;
    }

    try {
        nlohmann::json testParse;
        file >> testParse;
        file.close();
    }
    catch (const std::exception& e) {
        LOG_CONSOLE("ERROR: Invalid prefab JSON: %s - %s", assetPath.c_str(), e.what());
        file.close();
        return false;
    }

    resource->SetAssetFile(assetPath);
    resource->SetLibraryFile(assetPath);

    LOG_CONSOLE("[ModuleResources] Prefab registered: %s (UID: %llu)",
        assetPath.c_str(), resource->GetUID());

    return true;
}