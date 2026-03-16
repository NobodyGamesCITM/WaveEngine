#include "LibraryManager.h"
#include "Application.h"
#include "ModuleResources.h"
#include "Log.h"
#include <iostream>
#include <windows.h>
#include "MetaFile.h"
#include "TextureImporter.h"
#include "ModuleLoader.h"
#include <assimp/scene.h>
#include <assimp/postprocess.h> 
#include <assimp/cimport.h>
#include "MeshImporter.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

namespace fs = std::filesystem;

bool LibraryManager::s_initialized = false;
fs::path LibraryManager::s_projectRoot;

void LibraryManager::Initialize() {
    if (s_initialized) {
        return;
    }

    LOG_CONSOLE("[LibraryManager] Initializing library structure...");

    namespace fs = std::filesystem;

    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    fs::path execPath(buffer);

    fs::path currentSearchPath = execPath.parent_path();

    bool assetsFound = false;
    int maxLevels = 5;

    for (int i = 0; i < maxLevels; ++i) {
        fs::path candidatePath = currentSearchPath / "Assets";

        if (fs::exists(candidatePath) && fs::is_directory(candidatePath)) {
            s_projectRoot = currentSearchPath;
            assetsFound = true;
            LOG_CONSOLE("[LibraryManager] Assets folder found at: %s", candidatePath.string().c_str());
            break;
        }

        // Subir un nivel
        currentSearchPath = currentSearchPath.parent_path();

        // Verificar si llegamos a la raíz
        if (currentSearchPath == currentSearchPath.parent_path()) {
            break;
        }
    }

    if (!assetsFound) {
        LOG_CONSOLE("[LibraryManager] ERROR: Could not find Assets folder");
        return;
    }

    fs::path libraryRoot = s_projectRoot / "Library";
    EnsureDirectoryExists(libraryRoot);

    for (int i = 0; i < 100; i++) {
        std::stringstream ss;
        ss << std::setfill('0') << std::setw(2) << i;

        fs::path subFolder = libraryRoot / ss.str();

        EnsureDirectoryExists(subFolder);
    }

    s_initialized = true;
    LOG_CONSOLE("[LibraryManager] Library initialized successfully");
}

void LibraryManager::EnsureDirectoryExists(const fs::path& path) {
    try {
        if (!fs::exists(path)) {
            fs::create_directories(path);
            LOG_DEBUG("Created directory: %s", path.string().c_str());
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[LibraryManager] ERROR creating directory %s: %s", path.string().c_str(), e.what());
    }
}

bool LibraryManager::IsInitialized() {
    return s_initialized;
}

std::string LibraryManager::GetLibraryRoot() {
    return (s_projectRoot / "Library").string();
}

std::string LibraryManager::GetAssetsRoot() {
    return (s_projectRoot / "Assets").string();
}


bool LibraryManager::FileExists(const fs::path& path) {
    return fs::exists(path);
}

void LibraryManager::ClearLibrary() {
    fs::path libraryPath = s_projectRoot / "Library";

    LOG_CONSOLE("[LibraryManager] Clearing Library folder...");

    try {
        if (fs::exists(libraryPath)) {
            int filesDeleted = 0;

            for (const auto& entry : fs::recursive_directory_iterator(libraryPath)) {
                if (entry.is_regular_file()) {
                    fs::remove(entry.path());
                    filesDeleted++;
                }
            }

            LOG_CONSOLE("[LibraryManager] Deleted %d files from Library", filesDeleted);
            Initialize();
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[LibraryManager] ERROR clearing library: %s", e.what());
    }
}

void LibraryManager::RegenerateFromAssets() {
    
    LOG_CONSOLE("[LibraryManager] Scanning Assets and checking for changes...");

    fs::path assetsPath = GetAssetsRoot();
    int processed = 0;
    int skipped = 0;
    int errors = 0;

    try {
        for (const auto& entry : fs::recursive_directory_iterator(assetsPath)) {
            if (!entry.is_regular_file()) continue;

            fs::path assetPath = entry.path();
            std::string extension = assetPath.extension().string();

            if (extension == ".meta") continue;

            AssetType type = MetaFile::GetAssetType(extension);
            if (type == AssetType::UNKNOWN) continue;

            std::string assetPathStr = assetPath.string();
            std::string metaPathStr = assetPathStr + ".meta";

            if (!fs::exists(metaPathStr)) continue;

            MetaFile meta = MetaFileManager::LoadMeta(assetPathStr);

            if (meta.uid == 0) {
                LOG_CONSOLE("[LibraryManager] ERROR: No UID in meta for: %s",
                    assetPath.filename().string().c_str());
                errors++;
                continue;
            }

            bool needsImport = false;
            std::string libraryPath = GetLibraryPathFromUID(meta.uid);

            if (libraryPath == "") continue;
            
            if (!FileExists(libraryPath)) {
                needsImport = true;
            }
            else
            {
                if (meta.fileHash != MetaFileManager::GetFileHash(assetPath.generic_string()))
                {
                    needsImport = true;
                }
            }

            if (!needsImport) {
                skipped++;
                continue;
            }

            processed++;
            Application::GetInstance().resources.get()->ImportFile(assetPath.generic_string().c_str(), true);
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[LibraryManager] ERROR during scan: %s", e.what());
    }

    LOG_CONSOLE("[LibraryManager] Scan complete: %d re-imported/new, %d synchronized, %d errors",
        processed, skipped, errors);
}

std::string LibraryManager::GetLibraryPathFromUID(unsigned long long uid)
{
    std::string uidStr = std::to_string(uid);
    std::string folderName;

    if (uidStr.length() >= 2) {
        folderName = uidStr.substr(0, 2);
    }
    else {
        folderName = "0" + uidStr;
    }

    return (s_projectRoot / "Library" / folderName / (uidStr + ".waveBin")).string();
}