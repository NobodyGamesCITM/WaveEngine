#pragma once

#include <nlohmann/json.hpp>
#include "ResourcePrefab.h"

struct MetaFile;

class PrefabImporter
{

public:

    static bool ImportFromFile(const std::string& filepath, const MetaFile& meta);
    static bool SaveToCustomFormat(const Prefab& texture, const UID& filename);
    static Prefab LoadFromCustomFormat(const UID& filename);

};