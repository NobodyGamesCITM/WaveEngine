#include "MetaFile.h"
#include "LibraryManager.h"
#include <random>
#include <iomanip>
#include <iostream>
#include <algorithm>
#include <windows.h>
#include "Log.h"
#include "FileSystem.h"
#include "ResourceScript.h"
#include <nlohmann/json.hpp>

AssetType MetaFile::GetAssetType(const std::string& extension) {
    std::string ext = extension;
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

    if (ext == ".fbx") return AssetType::MODEL_FBX;
    if (ext == ".png") return AssetType::TEXTURE_PNG;
    if (ext == ".jpg" || ext == ".jpeg") return AssetType::TEXTURE_JPG;
    if (ext == ".dds") return AssetType::TEXTURE_DDS;
    if (ext == ".tga") return AssetType::TEXTURE_TGA;
    if (ext == ".glsl") return AssetType::SHADER_GLSL;
    if (ext == ".lua") return AssetType::SCRIPT_LUA;
    if (ext == ".prefab") return AssetType::PREFAB; 
    if (ext == ".mat") return AssetType::MATERIAL; 
    if (ext == ".scene") return AssetType::SCENE;

    return AssetType::UNKNOWN;
}

bool MetaFile::Save(const std::string& metaFilePath) const {
    
    nlohmann::json meta;

    meta["uid"] = uid;
    meta["type"] = static_cast<int>(type);

    if (type == AssetType::MODEL_FBX) {
        meta["importSettings"] = {
            {"importScale", importSettings.importScale},
            {"generateNormals", importSettings.generateNormals},
            {"flipUVs", importSettings.flipUVs},
            {"optimizeMeshes", importSettings.optimizeMeshes},
            {"upAxis", importSettings.upAxis},
            {"frontAxis", importSettings.frontAxis}
        };
        if (!meshes.empty()) {
            meta["meshes"] = meshes;
        }
        if (!animations.empty()) {
            meta["animations"] = animations;
        }
    }
    else if (type == AssetType::TEXTURE_PNG ||
        type == AssetType::TEXTURE_JPG ||
        type == AssetType::TEXTURE_DDS ||
        type == AssetType::TEXTURE_TGA) {
        meta["importSettings"] = {
            {"generateMipmaps", importSettings.generateMipmaps},
            {"filterMode", importSettings.filterMode},
            {"flipHorizontal", importSettings.flipHorizontal},
            {"maxTextureSize", importSettings.maxTextureSize}
        };
    }

    std::ofstream file(metaFilePath);
    if (!file.is_open()) {
        std::cerr << "[MetaFile] ERROR: Cannot create .meta file: " << metaFilePath << std::endl;
        return false;
    }

    file << meta.dump(4);
    file.close();

    return true;
}

MetaFile MetaFile::Load(const std::string& metaFilePath) {
    
    MetaFile meta;

    std::ifstream file(metaFilePath);
    if (!file.is_open()) {
        return meta;
    }

    try {
        
        nlohmann::json metaFile;
        file >> metaFile;

        if (metaFile.contains("uid")) meta.uid = metaFile["uid"].get<UID>();
        if (metaFile.contains("type")) meta.type = static_cast<AssetType>(metaFile["type"].get<int>());

        if (metaFile.contains("originalPath")) {
            meta.originalPath = metaFile["originalPath"].get<std::string>();
        }
        
        if (meta.type == AssetType::MODEL_FBX) {
            
            if (metaFile.contains("meshes")) {
                meta.meshes = metaFile["meshes"].get<std::map<std::string, UID>>();
            }
            if (metaFile.contains("animations")) {
                meta.animations = metaFile["animations"].get<std::map<std::string, UID>>();
            }
            if (metaFile.contains("importSettings")) {
                const auto& settings = metaFile["importSettings"];
                if (settings.contains("importScale")) meta.importSettings.importScale = settings["importScale"].get<float>();
                if (settings.contains("generateNormals")) meta.importSettings.generateNormals = settings["generateNormals"].get<bool>();
                if (settings.contains("flipUVs")) meta.importSettings.flipUVs = settings["flipUVs"].get<bool>();
                if (settings.contains("optimizeMeshes")) meta.importSettings.optimizeMeshes = settings["optimizeMeshes"].get<bool>();
                if (settings.contains("upAxis")) meta.importSettings.upAxis = settings["upAxis"].get<int>();
                if (settings.contains("frontAxis")) meta.importSettings.frontAxis = settings["frontAxis"].get<int>();
            }
        }
        else if (meta.type == AssetType::TEXTURE_PNG ||
            meta.type == AssetType::TEXTURE_JPG ||
            meta.type == AssetType::TEXTURE_DDS ||
            meta.type == AssetType::TEXTURE_TGA) {

            if (metaFile.contains("importSettings")) {
                const auto& settings = metaFile["importSettings"];
                if (settings.contains("generateMipmaps")) meta.importSettings.generateMipmaps = settings["generateMipmaps"].get<bool>();
                if (settings.contains("filterMode")) meta.importSettings.filterMode = settings["filterMode"].get<int>();
                if (settings.contains("flipHorizontal")) meta.importSettings.flipHorizontal = settings["flipHorizontal"].get<bool>();
                if (settings.contains("maxTextureSize")) meta.importSettings.maxTextureSize = settings["maxTextureSize"].get<int>();
            }
        }
    }
    catch (const nlohmann::json::exception& e) {
        LOG_CONSOLE("[MetaFile] ERROR parsing JSON en %s: %s", metaFilePath.c_str(), e.what());
    }

    file.close();
    return meta;
}

void MetaFileManager::Initialize() {
    CleanOrphanedMetaFiles();
    ScanAssets();
}

void MetaFileManager::ScanAssets() {
    
    std::string assetsPath = FileSystem::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        LOG_DEBUG("[MetaFileManager] Assets folder not found: %s", assetsPath.c_str());
        return;
    }

    int metasCreated = 0;
    int metasExisting = 0;

    for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
        
        if (!entry.is_regular_file()) continue;

        std::string assetPath = entry.path().string();
        std::string extension = entry.path().extension().string();

        // Skip .meta files
        if (extension == ".meta") continue;

        AssetType type = MetaFile::GetAssetType(extension);
        if (type == AssetType::UNKNOWN) continue; // Unsupported type

        std::string metaPath = GetMetaPath(assetPath);

        // Only create .meta if it doesn't exist
        if (!std::filesystem::exists(metaPath)) {
            // Create new .meta
            MetaFile meta;
            meta.uid = GenerateUID();
            meta.type = type;
            meta.originalPath = assetPath;

            if (meta.Save(metaPath)) {
                metasCreated++;
            }
        }
        else 
        {
            metasExisting++;
        }
    }

    LOG_CONSOLE("[MetaFileManager] Scan complete: %d created, %d existing",
        metasCreated, metasExisting);
}

void MetaFileManager::CleanOrphanedMetaFiles() {
    std::string assetsPath = FileSystem::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        LOG_DEBUG("[MetaFileManager] Assets folder not found: %s", assetsPath.c_str());
        return;
    }

    int metasDeleted = 0;

    // Find all .meta files
    for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
        if (!entry.is_regular_file()) continue;

        std::string filePath = entry.path().string();
        std::string extension = entry.path().extension().string();

		// Meta files only
        if (extension != ".meta") continue;

        // Remove .meta extension
        std::string assetPath = filePath.substr(0, filePath.length() - 5);

        if (!std::filesystem::exists(assetPath)) {
			// Deleteing orphaned .meta file
            try {
                std::filesystem::remove(filePath);
                LOG_CONSOLE("[MetaFileManager] Deleted orphaned .meta: %s", filePath.c_str());
                metasDeleted++;
            }
            catch (const std::exception& e) {
                LOG_CONSOLE("[MetaFileManager] ERROR deleting .meta: %s - %s", filePath.c_str(), e.what());
            }
        }
    }

    if (metasDeleted > 0) {
        LOG_CONSOLE("[MetaFileManager] Cleanup complete: %d orphaned .meta files deleted", metasDeleted);
    }
}

std::string MetaFileManager::GetMetaPath(const std::string& directoryPath)
{
    return directoryPath + ".meta";
}
bool MetaFileManager::DoesFileHasMeta(const std::string& directoryPath)
{
    return std::filesystem::exists(directoryPath + ".meta");
}

uint32_t MetaFileManager::GetCombinedHash(const std::string& assetPath)
{
    uint32_t assetHash = FileSystem::GetFileHash(assetPath);
    uint32_t metaHash = FileSystem::GetFileHash(GetMetaPath(assetPath));

    if (metaHash == 0) return assetHash;

    // Y el Manager aplica la matemática de tu motor
    return assetHash ^ (metaHash + 0x9e3779b9 + (assetHash << 6) + (assetHash >> 2));
}

void MetaFileManager::CheckForChanges() {
    
    std::string assetsPath = FileSystem::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        return;
    }

    int metasCreated = 0;
    int metasDeleted = 0;

    try {
        for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
            if (!entry.is_regular_file()) continue;

            std::string filePath = entry.path().string();
            std::string extension = entry.path().extension().string();

            if (extension != ".meta") continue;

            std::string assetPath = filePath.substr(0, filePath.length() - 5);

            if (!std::filesystem::exists(assetPath)) {
                try {
                    std::filesystem::remove(filePath);
                    LOG_CONSOLE("[MetaFileManager] Deleted orphaned .meta: %s", filePath.c_str());
                    metasDeleted++;
                }
                catch (const std::exception& e) {
                    LOG_CONSOLE("[MetaFileManager] ERROR deleting .meta: %s - %s", filePath.c_str(), e.what());
                }
            }
        }

        // Create missing .meta files for new assets
        for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
            if (!entry.is_regular_file()) continue;

            std::string assetPath = entry.path().string();
            std::string extension = entry.path().extension().string();

            // Skip .meta files
            if (extension == ".meta") continue;

            AssetType type = MetaFile::GetAssetType(extension);
            if (type == AssetType::UNKNOWN) continue; 

            std::string metaPath = GetMetaPath(assetPath);

            // Create .meta if it doesnt exist
            if (!std::filesystem::exists(metaPath)) {
                MetaFile meta;
                meta.uid = GenerateUID();
                meta.type = type;
                meta.originalPath = assetPath;

                if (meta.Save(metaPath)) {
                    LOG_CONSOLE("[MetaFileManager] Created .meta for new asset: %s", assetPath.c_str());
                    metasCreated++;
                }
            }
        }

        if (metasCreated > 0 || metasDeleted > 0) {
            LOG_CONSOLE("[MetaFileManager] Changes detected: %d created, %d deleted", metasCreated, metasDeleted);
        }
    }
    catch (const std::exception& e) {
        LOG_CONSOLE("[MetaFileManager] ERROR during change detection: %s", e.what());
    }
}



MetaFile MetaFileManager::GetOrCreateMeta(const std::string& assetPath) {
    std::string metaPath = GetMetaPath(assetPath);

    // Try loading existing .meta
    if (std::filesystem::exists(metaPath)) {
        MetaFile meta = MetaFile::Load(metaPath);

        // If no UID, assign one now
        if (meta.uid == 0) {
            meta.uid = GenerateUID();
            meta.Save(metaPath);
        }

        return meta;
    }

    // Create new .meta
    MetaFile meta;
    meta.uid = GenerateUID();
    meta.type = MetaFile::GetAssetType(std::filesystem::path(assetPath).extension().string());
    meta.originalPath = assetPath;

    meta.Save(metaPath);

    return meta;
}

void MetaFileManager::RegenerateLibrary() {
    ScanAssets();
}

MetaFile MetaFileManager::LoadMeta(const std::string& assetPath) {
    
    std::string metaPath = GetMetaPath(assetPath);

    if (std::filesystem::exists(metaPath)) {
        return MetaFile::Load(metaPath);
    }

    return MetaFile();
}

UID MetaFileManager::GetUIDFromAsset(const std::string& assetPath) {
   
    MetaFile meta = LoadMeta(assetPath);

    if (meta.uid == 0 && std::filesystem::exists(assetPath)) {
        meta.uid = GenerateUID();
        std::string metaPath = GetMetaPath(assetPath);
        meta.Save(metaPath);
    }

    return meta.uid;
}

std::string MetaFileManager::GetAssetFromUID(UID uid) {
    if (uid == 0) return "";

    std::string assetsPath = FileSystem::GetAssetsRoot();

    if (!std::filesystem::exists(assetsPath)) {
        return "";
    }

    // Search all .meta files
    for (const auto& entry : std::filesystem::recursive_directory_iterator(assetsPath)) {
        if (!entry.is_regular_file()) continue;

        std::string path = entry.path().string();
        std::string extension = entry.path().extension().string();

        // Only .meta files
        if (extension != ".meta") continue;

        MetaFile meta = MetaFile::Load(path);
        if (meta.uid == uid) {
            return meta.originalPath;
        }
    }

    return "";  // Not found
}