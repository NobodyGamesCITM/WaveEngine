#pragma once

#include "Globals.h"
#include <string>
#include <filesystem>
#include <unordered_map>

namespace fs = std::filesystem;

struct AssetRegistryEntry {
    uint32_t hash;
    int type;
    std::string path;
};

class LibraryManager {
public:
    static void Initialize();
    static bool IsInitialized();

    // UID-Number paths
    static std::string GetLibraryPath(const UID uid);
    static bool FileExists(const fs::path& path);

    // Library management
    static void ClearLibrary();


    //Asset Registry
    static void LoadRegistry();
    static void SaveRegistry();
    static void UpdateRegistry(UID uid, uint32_t newHash, int type, std::string path);
    static uint32_t GetLocalHash(UID uid);
    static const std::unordered_map<UID, AssetRegistryEntry>& GetRegistry() {
        return s_assetRegistry;
    }

private:
    static bool s_initialized;
    static std::unordered_map<UID, AssetRegistryEntry> s_assetRegistry;
};