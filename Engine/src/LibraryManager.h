#pragma once

#include "Globals.h"
#include <string>
#include <filesystem>
#include <unordered_map>

namespace fs = std::filesystem;

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
    static uint32_t GetLocalHash(UID uid);
    static void UpdateLocalHash(UID uid, uint32_t newHash);

private:
    static bool s_initialized;
   
    static std::unordered_map<UID, uint32_t> s_assetRegistry;
};