#pragma once

#include <nlohmann/json.hpp>
#include "ResourceScene.h"

class SceneImporter
{

public:

    static Scene ImportFromFile(const std::string& filepath);
    static bool SaveToCustomFormat(const Scene& texture, const UID& filename);
    static Scene LoadFromCustomFormat(const UID& filename);

};