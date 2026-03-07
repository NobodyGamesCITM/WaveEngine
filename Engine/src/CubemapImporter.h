#pragma once
#include "Globals.h"

class Cubemap;

class CubemapImporter {
public:
    CubemapImporter();
    ~CubemapImporter();

    static bool ImportCubemap(const std::string& path, const UID& uid);

    static bool SaveToCustomFormat(const Cubemap& cubemap, const UID& uid);

    static Cubemap* LoadFromCustomFormat(const UID& uid);

    static UID CreateNewCubemap(const std::string& directory, const std::string& name);

    static Cubemap* CloneCubemap(const Cubemap* source);
};