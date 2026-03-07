#include "ResourceCubemap.h"

ResourceCubemap::ResourceCubemap(UID uid)
    : Resource(uid, Resource::CUBEMAP) {
}

ResourceCubemap::~ResourceCubemap() {
    UnloadFromMemory();
}

bool ResourceCubemap::LoadInMemory()
{
    cubemap = CubemapImporter::LoadFromCustomFormat(uid);
    return true;
}

void ResourceCubemap::UnloadFromMemory()
{
    if (cubemap != nullptr) {
        delete cubemap;
        cubemap = nullptr;
    }
}