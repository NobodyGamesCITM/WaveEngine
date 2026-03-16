#pragma once

#include <nlohmann/json.hpp>
#include "ResourceScene.h"

struct MetaFile;

class SceneImporter
{

public:

    static bool ImportFromFile(const std::string& filepath, const MetaFile& meta);
    static bool SaveToCustomFormat(const Scene& texture, const UID& filename);
    static Scene LoadFromCustomFormat(const UID& filename);

};