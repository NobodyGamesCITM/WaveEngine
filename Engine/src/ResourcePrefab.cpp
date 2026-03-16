#include "ResourcePrefab.h"
#include "PrefabImporter.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleScene.h"
#include "Log.h"
#include <fstream>

ResourcePrefab::ResourcePrefab(UID uid)
    : Resource(uid, Resource::PREFAB)
{
}

ResourcePrefab::~ResourcePrefab()
{
    if (IsLoadedToMemory()) {
        UnloadFromMemory();
    }
}

bool ResourcePrefab::LoadInMemory()
{
    if (IsLoadedToMemory()) {
        LOG_DEBUG("[ResourceModel] Already loaded in memory: %llu", uid);
        return true;
    }

    if (libraryFile.empty()) {
        LOG_DEBUG("[ResourceModel] ERROR: No library file specified");
        return false;
    }

    // Extract filename from library path
    std::string filename = libraryFile;
    size_t lastSlash = filename.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        filename = filename.substr(lastSlash + 1);
    }

    LOG_DEBUG("[ResourceModel] Loading from Library: %s", filename.c_str());

    Prefab modelData = PrefabImporter::LoadFromCustomFormat(uid);;

    if (!modelData.IsValid()) {
        LOG_DEBUG("[ResourceModel] ERROR: Failed to load model data");
        return false;
    }

    prefab = modelData;

    return true;
}

void ResourcePrefab::UnloadFromMemory()
{
    prefab.prefabJson.clear();
}