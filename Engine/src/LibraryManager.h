#pragma once

#include <string>
#include <filesystem>

namespace fs = std::filesystem;

class LibraryManager {
public:
    static void Initialize();
    static void EnsureDirectoryExists(const fs::path& path);
    static bool IsInitialized();

    // UID-Number paths
    static std::string GetLibraryPathFromUID(unsigned long long uid);

    static bool FileExists(const fs::path& path);

    // Base paths
    static std::string GetLibraryRoot();
    static std::string GetAssetsRoot();
    static std::string GetProjectRoot();

    // Library management
    static void ClearLibrary();
    static void RegenerateFromAssets();

private:
    static bool s_initialized;
    static fs::path s_projectRoot;
};