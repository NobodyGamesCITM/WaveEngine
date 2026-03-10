#include "ResourceModel.h"
#include "ModelImporter.h"
#include "Log.h"
#include <glad/glad.h>
#include "MetaFile.h"

ResourceModel::ResourceModel(UID uid)
    : Resource(uid, Resource::MODEL) {
}

ResourceModel::~ResourceModel() {
    UnloadFromMemory();
}

bool ResourceModel::LoadInMemory() {
    
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

    Model modelData = ModelImporter::LoadFromCustomFormat(uid);;

    if (!modelData.IsValid()) {
        LOG_DEBUG("[ResourceModel] ERROR: Failed to load model data");
        return false;
    }

    model = modelData;

    return true;
}

void ResourceModel::UnloadFromMemory() {
    
    model.modelJson.clear();
}

