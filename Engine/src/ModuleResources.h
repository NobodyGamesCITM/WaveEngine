#pragma once

#include "Module.h"
#include <map>
#include <string>

// Resource UIDs
typedef unsigned long long UID;

// Base class for all resources
class Resource {
public:
    enum Type {
        UNKNOWN = 0,
        TEXTURE,
        MESH,
        MODEL,
        MATERIAL,
        ANIMATION,
        SHADER,
        PREFAB,
        SCRIPT,
        SCENE
    };

    Resource(UID uid, Type type);
    virtual ~Resource();

    virtual bool LoadInMemory() = 0;
    virtual void UnloadFromMemory() = 0;

    // Getters
    UID GetUID() const { return uid; }
    Type GetType() const { return type; }
    const std::string& GetAssetFile() const { return assetsFile; }
    const std::string& GetLibraryFile() const { return libraryFile; }
    unsigned int GetReferenceCount() const { return referenceCount; }
    bool IsLoadedToMemory() const { return referenceCount > 0; }

    void SetAssetFile(const std::string& file) { assetsFile = file; }
    void SetLibraryFile(const std::string& file) { libraryFile = file; }

protected:
    UID uid = 0;
    Type type = UNKNOWN;
    std::string assetsFile;
    std::string libraryFile;
    unsigned int referenceCount = 0;

    friend class ModuleResources;
};
// Resource management module
class ModuleResources : public Module {
public:
    ModuleResources();
    ~ModuleResources();

    bool Awake() override;
    bool Start() override;
    bool Update() override;
    bool CleanUp() override;

    // Find UID from Assets/ file
    UID Find(const char* fileInAssets, Resource::Type type = Resource::UNKNOWN) const;

    // Import new file and return its UID
    UID ImportFile(const char* newFileInAssets, bool forceReimport = false);

    // Generate unique UID
    UID GenerateNewUID();

    // Request resource (increment ref count)
    const Resource* RequestResource(UID uid) const;
    Resource* RequestResource(UID uid);

    // Release resource (decrement ref count)
    void ReleaseResource(UID uid);

    const Resource* PeekResource(UID uid);

    // Get resource without incrementing reference count
    const Resource* GetResourceDirect(UID uid) const {
        auto it = resources.find(uid);
        return (it != resources.end()) ? it->second : nullptr;
    }

    Resource* GetResourceDirect(UID uid) {
        auto it = resources.find(uid);
        return (it != resources.end()) ? it->second : nullptr;
    }

    // Load resources from meta files
    void LoadResourcesFromMetaFiles();

    // Create resource with specific UID
    Resource* CreateNewResourceWithUID(const char* assetsFile, Resource::Type type, UID uid);

    // Get resource info
    bool GetResourceInfo(UID uid, std::string& outAssetPath, std::string& outLibraryPath);

    // Get resource type from file extension
    Resource::Type GetResourceTypeFromExtension(const std::string& extension) const;

    // Remove resource from system
    void RemoveResource(UID uid);

    // Get all resources (for editor)
    const std::map<UID, Resource*>& GetAllResources() const { return resources; }

    // Get resource statistics
    void GetResourceStats(int& outTexturesLoaded, int& outMeshesLoaded, int& outTotalRefs) const {
        outTexturesLoaded = 0;
        outMeshesLoaded = 0;
        outTotalRefs = 0;

        for (const auto& pair : resources) {
            if (pair.second->IsLoadedToMemory()) {
                if (pair.second->GetType() == Resource::TEXTURE) outTexturesLoaded++;
                if (pair.second->GetType() == Resource::MESH) outMeshesLoaded++;
            }
            outTotalRefs += pair.second->GetReferenceCount();
        }
    }

    // Check if a resource is loaded in memory
    bool IsResourceLoaded(UID uid) const;

    // Get reference count for a resource
    unsigned int GetResourceReferenceCount(UID uid) const;

    // Get resource without incrementing reference count (read-only access)
    const Resource* GetResource(UID uid) const;

    void RegisterResource(UID uid, Resource* resource) {
        if (resources.find(uid) != resources.end()) {
            LOG_DEBUG("[ModuleResources] WARNING: Resource %llu already exists, replacing", uid);
            // Cleanup old resource
            Resource* old = resources[uid];
            if (old->IsLoadedToMemory()) {
                old->UnloadFromMemory();
            }
            delete old;
        }

        resources[uid] = resource;
        LOG_DEBUG("[ModuleResources] Registered resource: UID=%llu, Type=%d",
            uid, resource->GetType());
    }

    bool ImportScript(Resource* resource, const std::string& assetPath);

    bool IsShuttingDown() const { return shuttingDown; }

private:
    // Create new resource by type
    Resource* CreateNewResource(const char* assetsFile, Resource::Type type);

    // Generate Library/ path for resource
    std::string GenerateLibraryPath(Resource* resource);

    // Load resource from Library/ into memory
    Resource* LoadResourceFromLibrary(UID uid);

    // Save resource metadata
    void SaveResourceMetadata(Resource* resource);

    // Load resource metadata
    bool LoadResourceMetadata(UID uid);

    // Type-specific import methods
    bool ImportTexture(Resource* resource, const std::string& assetPath);
    bool ImportMesh(Resource* resource, const std::string& assetPath);
    bool ImportModel(Resource* resource, const std::string& assetPath);
    bool ImportPrefab(Resource* resource, const std::string& assetPath);
    bool ImportMaterial(Resource* resource, const std::string& assetPath);
    bool ImportScene(Resource* resource, const std::string& assetPath);


private:
    std::map<UID, Resource*> resources;
    UID nextUID = 1;
    bool shuttingDown = false;
};