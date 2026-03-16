#pragma once
#include "Globals.h"

class Material;
struct MetaFile;

class MaterialImporter {
public:
    MaterialImporter();
    ~MaterialImporter();

    static bool ImportMaterial(const std::string& path, const MetaFile& uid);

    static bool SaveToCustomFormat(const Material& material, const UID& uid);

    static Material* LoadFromCustomFormat(const UID& uid);
    
    static UID CreateNewMaterial(const std::string& directory, const std::string& name);

    static Material* CloneMaterial(const Material* source);
};