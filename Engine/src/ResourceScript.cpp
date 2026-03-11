#include "ResourceScript.h"
#include "ScriptImporter.h"
#include "Application.h"
#include "ModuleResources.h"
#include "Log.h"
#include <fstream>
#include <sstream>
#include <filesystem>

ResourceScript::ResourceScript(UID uid)
    : Resource(uid, Resource::SCRIPT), lastLoadTime(0)
{
}

ResourceScript::~ResourceScript()
{
    if (IsLoadedToMemory()) {
        UnloadFromMemory();
    }
}

bool ResourceScript::LoadInMemory()
{
    //ESTO TAMPOCO LO HA DE TENER LA LIBRERIA
    if (std::filesystem::exists(assetsFile)) {
        long long assetTime = std::filesystem::last_write_time(assetsFile).time_since_epoch().count();
        long long libTime = 0;

        if (std::filesystem::exists(libraryFile)) {
            libTime = std::filesystem::last_write_time(libraryFile).time_since_epoch().count();
        }

        if (assetTime > libTime) {
            LOG_DEBUG("[ResourceScript] Library outdated for %s. Re-importing...", assetsFile.c_str());
            Application::GetInstance().resources->ImportFile(assetsFile.c_str(), true);
        }
    }

    if (IsLoadedToMemory()) {
        LOG_DEBUG("[ResourceModel] Already loaded in memory: %llu", uid);
        return true;
    }

    if (libraryFile.empty()) {
        LOG_DEBUG("[ResourceModel] ERROR: No library file specified");
        return false;
    }

    std::string filename = libraryFile;
    size_t lastSlash = filename.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        filename = filename.substr(lastSlash + 1);
    }

    LOG_DEBUG("[ResourceModel] Loading from Library: %s", filename.c_str());

    Script scriptData = ScriptImporter::LoadFromCustomFormat(uid);;

    if (!scriptData.IsValid()) {
        LOG_DEBUG("[ResourceModel] ERROR: Failed to load model data");
        return false;
    }

    script = scriptData;

    lastLoadTime = std::filesystem::last_write_time(assetsFile).time_since_epoch().count();

    return true;
}

void ResourceScript::UnloadFromMemory()
{
    script.scriptContent.clear();
    lastLoadTime = 0;
}

bool ResourceScript::Reload()
{
    LOG_CONSOLE("[ResourceScript] Reloading script: %s", assetsFile.c_str());

    // Unload current content
    UnloadFromMemory();

    // Load fresh content
    if (LoadInMemory()) {
        LOG_CONSOLE("[ResourceScript] Script reloaded successfully");
        return true;
    }

    LOG_CONSOLE("[ResourceScript] ERROR: Failed to reload script");
    return false;
}

bool ResourceScript::NeedsReload() const
{
    if (!IsLoadedToMemory() || assetsFile.empty()) return false;
    if (!std::filesystem::exists(assetsFile)) return false;

    long long currentFileTime = std::filesystem::last_write_time(assetsFile).time_since_epoch().count();

    return currentFileTime > lastLoadTime;
}