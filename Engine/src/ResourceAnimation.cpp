#include "ResourceAnimation.h"
#include "ModuleResources.h"
#include "AnimationImporter.h"
#include "Log.h"
#include <fstream>

ResourceAnimation::ResourceAnimation(UID uid)
    : Resource(uid, Resource::ANIMATION) {
}

ResourceAnimation::~ResourceAnimation() {
    UnloadFromMemory();
}

bool ResourceAnimation::LoadInMemory() {
    
    Animation animation;
    if (IsLoadedToMemory())
        return true;

    if (libraryFile.empty()) {
        LOG_DEBUG("[ResourceAnimation] ERROR: No library file specified");
        return false;
    }

    //Extract file name from path
    std::string filename = libraryFile;
    size_t lastSlash = filename.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        filename = filename.substr(lastSlash + 1);
    }

    //Extract data from Library
    animation = AnimationImporter::LoadFromCustomFormat(uid);

    if (animation.IsValid())
    {
        this->animation = animation;
        return true;
    }
    else
    {
        LOG_DEBUG("[ResourceAnimation] Failed to load resourece %s", libraryFile);
        return false;
    }
}

void ResourceAnimation::UnloadFromMemory() {
    
    animation.duration = 0.0;
    animation.ticksPerSecond = 0.0;
    animation.channels.clear();
}