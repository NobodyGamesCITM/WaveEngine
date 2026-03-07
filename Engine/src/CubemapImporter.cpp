#include "CubemapImporter.h"
#include "ModuleResources.h"
#include "Globals.h"

#include <fstream>
#include "nlohmann/json.hpp"

CubemapImporter::CubemapImporter() {}
CubemapImporter::~CubemapImporter() {}

bool CubemapImporter::ImportCubemap(const std::string& path, const UID& uid)
{


    return false;
}

bool CubemapImporter::SaveToCustomFormat(const Cubemap& mat, const UID& uid)
{

    return true;
}

Cubemap* CubemapImporter::LoadFromCustomFormat(const UID& uid)
{

    return ;
}

UID CubemapImporter::CreateNewCubemap(const std::string& directory, const std::string& name) {

    
    return success ? newUID : 0;
}

Cubemap* CubemapImporter::CloneCubemap(const Cubemap* source) {
    if (!source) return nullptr;

    nlohmann::json tmp;
    tmp["Type"] = (int)source->GetType();
    tmp["Opacity"] = source->GetOpacity();
    source->SaveToJson(tmp);

    Material* copy = nullptr;
    switch (source->GetType()) {
    case MaterialType::STANDARD: copy = new MaterialStandard(MaterialType::STANDARD); break;
    }

    if (copy) {
        copy->LoadFromJson(tmp);
    }

    return copy;
}