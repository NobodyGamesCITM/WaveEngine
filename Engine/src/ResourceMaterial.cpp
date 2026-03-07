#include "ResourceMaterial.h"
#include "ModuleResources.h"
#include "MaterialImporter.h"
#include "Log.h"
#include <fstream>

ResourceMaterial::ResourceMaterial(UID uid)
    : Resource(uid, Resource::MATERIAL) {
}

ResourceMaterial::~ResourceMaterial() 
{
    UnloadFromMemory();
}

bool ResourceMaterial::LoadInMemory()
{
    material = MaterialImporter::LoadFromCustomFormat(uid);
    return true;
}

void ResourceMaterial::UnloadFromMemory()
{
    if (material != nullptr) {
        delete material;
        material = nullptr;
    }
}
