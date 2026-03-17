#include "ModuleResources.h"
#include "ResourceTexture.h"
#include "ResourceMesh.h"
#include "ResourceModel.h"
#include "ResourceShader.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include "FileSystem.h"
#include "TextureImporter.h"
#include "ModelImporter.h"
#include "MeshImporter.h"
#include "PrefabImporter.h"
#include "SceneImporter.h"
#include "ScriptImporter.h"
#include "MaterialImporter.h"
#include "Log.h"
#include "ResourceScript.h"
#include "ResourcePrefab.h"
#include "ResourceAnimation.h"
#include "ResourceMaterial.h"
#include "ResourceScene.h"
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
    CheckForAssetsModifications();
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

    std::string assetsPath = FileSystem::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        LOG_CONSOLE("ERROR: Assets folder not found");
        return;
    }

    int registered = 0;
    int skipped = 0;


    for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
       
        if (!entry.is_regular_file()) continue;

        std::string assetPath = entry.path().string();
        std::string extension = entry.path().extension().string();

        if (extension == ".meta") continue;

        AssetType assetType = MetaFile::GetAssetType(extension);

        if (assetType == AssetType::UNKNOWN) continue;

        std::string metaPath = assetPath + ".meta";
        if (!std::filesystem::exists(metaPath)) {

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
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::MODEL_FBX:
            
            resourceType = Resource::MODEL;
            resource = new ResourceModel(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            
            for (const auto& [meshName, meshUID] : meta.meshes) {

                std::string meshPath = LibraryManager::GetLibraryPath(meshUID);

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

                std::string animationPath = LibraryManager::GetLibraryPath(animationUID);

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
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::SCRIPT_LUA:
            resourceType = Resource::SCRIPT;
            resource = new ResourceScript(meta.uid);
            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;

        case AssetType::PREFAB:

            resourceType = Resource::PREFAB;
            resource = new ResourcePrefab(meta.uid);  

            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;
        case AssetType::MATERIAL:

            resourceType = Resource::MATERIAL;
            resource = new ResourceMaterial(meta.uid);  

            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
                resources[meta.uid] = resource;
                registered++;
            }
            break;
        case AssetType::SCENE:

            resourceType = Resource::SCENE;
            resource = new ResourceScene(meta.uid);  

            if (resource) {
                resource->SetAssetFile(assetPath);
                resource->SetLibraryFile(LibraryManager::GetLibraryPath(meta.uid));
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
}

UID ModuleResources::Find(const char* assetPath, Resource::Type type) const {
    for (auto const& [uid, res] : resources) {
        if (res->GetAssetFile() == assetPath) {

            if (type == Resource::UNKNOWN || res->GetType() == type) {
                return uid;
            }
        }
    }
    return 0;
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
        if (!forceReimport && std::filesystem::exists(LibraryManager::GetLibraryPath(meta.uid))) {
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
    case Resource::SCENE: {
        importSuccess = ImportScene(resource, newFileInAssets);
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

    uint32_t finalFileHash = MetaFileManager::GetCombinedHash(newFileInAssets);
    LibraryManager::UpdateLocalHash(meta.uid, finalFileHash);

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
    case Resource::SCENE:
        resource = new ResourceScene(uid);
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
            resource->SetLibraryFile(LibraryManager::GetLibraryPath(uid));
        }
        else if (type == Resource::MESH) {
            resource->SetLibraryFile(LibraryManager::GetLibraryPath(uid));
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
    if (ext == ".scene") { 
        return Resource::SCENE;
    }

    return Resource::UNKNOWN;
}
Resource* ModuleResources::CreateNewResource(const char* assetsFile, Resource::Type type) {
    UID uid = GenerateNewUID();
    return CreateNewResourceWithUID(assetsFile, type, uid);
}

std::string ModuleResources::GenerateLibraryPath(Resource* resource) {
    
    if (!resource) return "";
    return LibraryManager::GetLibraryPath(resource->GetUID());
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

    return TextureImporter::ImportFromFile(assetPath, meta);
}

bool ModuleResources::ImportMesh(Resource* resource, const std::string& assetPath) {
    LOG_CONSOLE("ERROR: Direct mesh import not supported");
    return false;
}

bool ModuleResources::ImportMaterial(Resource* resource, const std::string& assetPath) 
{
    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    if (MaterialImporter::ImportMaterial(assetPath, meta))
    
    return true;
}

bool ModuleResources::ImportModel(Resource* resource, const std::string& assetPath) {

    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    return ModelImporter::ImportFromFile(assetPath, meta);
}

bool ModuleResources::ImportScene(Resource* resource, const std::string& assetPath) {
    
    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    return SceneImporter::ImportFromFile(assetPath, meta);
}

bool ModuleResources::ImportScript(Resource* resource, const std::string& assetPath) 
{    
    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    return ScriptImporter::ImportFromFile(assetPath, meta);
}

bool ModuleResources::ImportPrefab(Resource* resource, const std::string& assetPath) {

    std::string libraryPath = LibraryManager::GetLibraryPath(resource->GetUID());

    std::string metaPath = assetPath + ".meta";
    MetaFile meta;

    if (std::filesystem::exists(metaPath)) {
        meta = MetaFile::Load(metaPath);
    }
    else {
        meta = MetaFileManager::GetOrCreateMeta(assetPath);
        meta.Save(metaPath);
    }

    return PrefabImporter::ImportFromFile(assetPath, meta);
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

void ModuleResources::CheckForAssetsModifications()
{
    LOG_CONSOLE("[ResourceManager] Scanning Assets and checking for changes...");

    fs::path assetsPath = fs::path(FileSystem::GetAssetsRoot());
    int processed = 0;
    int skipped = 0;
    int errors = 0;

    try {
        for (const auto& entry : fs::recursive_directory_iterator(assetsPath)) {
            if (!entry.is_regular_file()) continue;

            fs::path assetPath = entry.path();
            std::string extension = assetPath.extension().string();

            if (extension == ".meta") continue;

            AssetType type = MetaFile::GetAssetType(extension);
            if (type == AssetType::UNKNOWN) continue;

            std::string assetPathStr = assetPath.string();
            std::string metaPathStr = assetPathStr + ".meta";

            if (!fs::exists(metaPathStr)) continue;

            MetaFile meta = MetaFileManager::LoadMeta(assetPathStr);

            if (meta.uid == 0) {
                LOG_CONSOLE("[LibraryManager] ERROR: No UID in meta for: %s",
                    assetPath.filename().string().c_str());
                errors++;
                continue;
            }

            bool needsImport = false;
            std::string libraryPath = LibraryManager::GetLibraryPath(meta.uid);

            if (libraryPath == "") continue;

            if (!FileSystem::DoesFileExist(libraryPath)) {
                needsImport = true;
            }
            else
            {
                uint32_t currentCombinedHash = MetaFileManager::GetCombinedHash(assetPathStr);
                uint32_t localLibraryHash = LibraryManager::GetLocalHash(meta.uid);

                if (localLibraryHash != currentCombinedHash)
                {
                    needsImport = true;
                }
            }

            if (!needsImport) {
                skipped++;
                continue;
            }

            processed++;
            ImportFile(assetPath.generic_string().c_str(), true);
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[LibraryManager] ERROR during scan: %s", e.what());
    }

    LOG_CONSOLE("[LibraryManager] Scan complete: %d re-imported/new, %d synchronized, %d errors",
        processed, skipped, errors);
}
