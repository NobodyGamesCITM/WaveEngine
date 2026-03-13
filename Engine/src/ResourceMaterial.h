#pragma once
#include "ModuleResources.h"

class Material;

class ResourceMaterial : public Resource {
public:
    ResourceMaterial(UID uid);
    virtual ~ResourceMaterial();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;
    
    Material* GetMaterial() { return material; }

private:
    
    Material* material = nullptr;
};