#pragma once

#include <nlohmann/json.hpp>
#include "ResourceScript.h"

struct MetaFile;

class ScriptImporter
{

public:

    static bool ImportFromFile(const std::string& filepath, const MetaFile& meta);
    static bool SaveToCustomFormat(const Script& script, const UID& filename);
    static Script LoadFromCustomFormat(const UID& filename);

    static std::string GetDefaultScriptTemplate();
    static UID CreateNewScript(const std::string& directory, const std::string& name);
};