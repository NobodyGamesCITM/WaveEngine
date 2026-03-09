#include "ResourceScript.h"
#include "ResourceScript.h"
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
    if (IsLoadedToMemory()) {
        LOG_DEBUG("[ResourceScript] Script already loaded: %llu", uid);
        return true;
    }

    if (assetsFile.empty()) {
        LOG_CONSOLE("[ResourceScript] ERROR: No asset file path set for script UID %llu", uid);
        return false;
    }

    if (!std::filesystem::exists(assetsFile)) {
        LOG_CONSOLE("[ResourceScript] ERROR: Script file not found: %s", assetsFile.c_str());
        return false;
    }

    // Read script content
    std::ifstream file(assetsFile);
    if (!file.is_open()) {
        LOG_CONSOLE("[ResourceScript] ERROR: Cannot open script file: %s", assetsFile.c_str());
        return false;
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    scriptContent = buffer.str();
    file.close();

    // Store load time for hot reloading
    lastLoadTime = std::filesystem::last_write_time(assetsFile).time_since_epoch().count();

    

    return true;
}

void ResourceScript::UnloadFromMemory()
{
    if (!IsLoadedToMemory()) {
        return;
    }

    scriptContent.clear();
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
    if (!IsLoadedToMemory() || assetsFile.empty()) {
        return false;
    }

    if (!std::filesystem::exists(assetsFile)) {
        return false;
    }

    // Check if file has been modified
    long long currentFileTime = std::filesystem::last_write_time(assetsFile).time_since_epoch().count();

    // Allow 2 second tolerance
    const long long tolerance = 20000000000LL;

    return std::abs(currentFileTime - lastLoadTime) > tolerance;
}