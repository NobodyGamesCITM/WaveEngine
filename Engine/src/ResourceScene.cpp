#include "ResourceScene.h"
#include "SceneImporter.h"
#include "Log.h"
#include "MetaFile.h"

ResourceScene::ResourceScene(UID uid)
    : Resource(uid, Resource::SCENE) {
}

ResourceScene::~ResourceScene() {
    UnloadFromMemory();
}

bool ResourceScene::LoadInMemory() {
    
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

    Scene modelData = SceneImporter::LoadFromCustomFormat(uid);;

    if (!modelData.IsValid()) {
        LOG_DEBUG("[ResourceModel] ERROR: Failed to load model data");
        return false;
    }

    scene = modelData;

    return true;
}

void ResourceScene::UnloadFromMemory() {
    
    scene.sceneJson.clear();
}

