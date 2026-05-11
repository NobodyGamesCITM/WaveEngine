#include "LibraryManager.h"
#include "Application.h"
#include "ModuleResources.h"
#include "Log.h"
#include <iostream>
#include <windows.h>
#include "MetaFile.h"
#include "FileSystem.h"
#include "TextureImporter.h"
#include "ModuleLoader.h"
#include <assimp/scene.h>
#include <assimp/postprocess.h> 
#include <assimp/cimport.h>
#include "MeshImporter.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <fstream>
#include <nlohmann/json.hpp>

namespace fs = std::filesystem;

bool LibraryManager::s_initialized = false;
std::unordered_map<UID, AssetRegistryEntry> LibraryManager::s_assetRegistry;

void LibraryManager::Initialize() {
    if (s_initialized) {
        return;
    }

    FileSystem::EnsureDirectoryExists(FileSystem::GetLibraryRoot());

    for (int i = 0; i < 100; i++) {
        std::stringstream ss;
        ss << std::setfill('0') << std::setw(2) << i;

        std::string subFolder = FileSystem::GetLibraryRoot()+"/"+ ss.str();

        FileSystem::EnsureDirectoryExists(subFolder);
    }

    LoadRegistry();

    s_initialized = true;
    LOG_CONSOLE("[LibraryManager] Library initialized successfully");
}

bool LibraryManager::IsInitialized() {
    return s_initialized;
}


bool LibraryManager::FileExists(const fs::path& path) {
    return fs::exists(path);
}

void LibraryManager::ClearLibrary() {
    
    std::string libraryPath = FileSystem::GetLibraryRoot();

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


void LibraryManager::LoadRegistry() {
    
    std::string registryPath = FileSystem::GetLibraryRoot() + "/AssetRegistry.json";
    if (fs::exists(registryPath)) {
        std::ifstream file(registryPath);
        nlohmann::json j;
        file >> j;

        for (auto& element : j.items()) {
            AssetRegistryEntry entry;
            entry.hash = element.value()["hash"].get<uint32_t>();
            entry.type = element.value()["type"].get<int>();
            entry.path = element.value()["path"].get<std::string>();

            s_assetRegistry[std::stoull(element.key())] = entry;
        }
        LOG_CONSOLE("[LibraryManager] Asset Registry loaded.");
    }
}

void LibraryManager::SaveRegistry() {

    if (s_assetRegistry.empty()) {
        LOG_CONSOLE("[LibraryManager] WARNING: Attempted to save an EMPTY registry. Aborting.");
        return;
    }

    std::string registryPath = FileSystem::GetLibraryRoot() + "/AssetRegistry.json";

    try {
        nlohmann::json j;

        for (const auto& pair : s_assetRegistry) {
            j[std::to_string(pair.first)] = {
                {"hash", pair.second.hash},
                {"type", pair.second.type},
                {"path", pair.second.path}
            };
        }

        std::ofstream file(registryPath);
        if (file.is_open()) {

            file << j.dump(4, ' ', false, nlohmann::json::error_handler_t::replace);

            file.close();
        }
        else {
            LOG_CONSOLE("[LibraryManager] ERROR: Could not open file to write: %s", registryPath.c_str());
        }
    }
    catch (const std::exception& e) {

        LOG_CONSOLE("[LibraryManager] CRITICAL ERROR generating JSON: %s", e.what());
    }
}

uint32_t LibraryManager::GetLocalHash(unsigned long long uid) {
    auto it = s_assetRegistry.find(uid);
    return (it != s_assetRegistry.end()) ? it->second.hash : 0;
}

void LibraryManager::UpdateRegistry(UID uid, uint32_t newHash, int type, std::string path) {
    AssetRegistryEntry entry;
    entry.hash = newHash;
    entry.type = type;
    entry.path = path;

    s_assetRegistry[uid] = entry;
    SaveRegistry();
}

std::string LibraryManager::GetLibraryPath(const UID uid)
{
    std::string uidStr = std::to_string(uid);
    std::string folder = (uidStr.length() >= 2) ? uidStr.substr(0, 2) : "00";

    std::filesystem::path fullPath = std::filesystem::path(FileSystem::GetLibraryRoot()) / folder / (uidStr + ".waveBin");

    std::string finalPath = fullPath.generic_string();

    return finalPath;
}