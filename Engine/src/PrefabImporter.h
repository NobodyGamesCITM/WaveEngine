#pragma once

#include <nlohmann/json.hpp>
#include "ResourcePrefab.h"

class PrefabImporter
{

public:

    static Prefab ImportFromFile(const std::string& filepath);
    static bool SaveToCustomFormat(const Prefab& texture, const UID& filename);
    static Prefab LoadFromCustomFormat(const UID& filename);

};