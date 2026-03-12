#include "MetaFile.h"
#include "LibraryManager.h"
#include <random>
#include <iomanip>
#include <iostream>
#include <algorithm>
#include <windows.h>
#include "Log.h"
#include "ResourceScript.h"
#include <nlohmann/json.hpp>

// META FILE IMPLEMENTATION
///////////////////////////////


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

    return AssetType::UNKNOWN;
}

bool MetaFile::Save(const std::string& metaFilePath) const {
    
    nlohmann::json meta;

    meta["uid"] = uid;
    meta["type"] = static_cast<int>(type);
    meta["fileHash"] = fileHash;

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
        if (metaFile.contains("fileHash")) meta.fileHash = metaFile["fileHash"].get<uint32_t>();

        if (metaFile.contains("originalPath")) {
            meta.originalPath = MakeAbsoluteFromProject(metaFile["originalPath"].get<std::string>());
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

bool MetaFile::NeedsReimport(const std::string& assetPath) const {
    
    if (!std::filesystem::exists(assetPath)) {
        return false;
    }

    if (fileHash != MetaFileManager::GetFileHash(assetPath))
        return true;
}

std::string MetaFile::MakeRelativeToProject(const std::string& absolutePath) {
    if (absolutePath.empty()) {
        return "";
    }

    try {
        std::filesystem::path absPath(absolutePath);
        std::filesystem::path projectRoot = LibraryManager::GetAssetsRoot();
        projectRoot = projectRoot.parent_path(); // Assets/ -> Project root

        // If already relative or can't make relative, return as is
        if (absPath.is_relative()) {
            return absolutePath;
        }

        // Make relative to project root
        std::filesystem::path relativePath = std::filesystem::relative(absPath, projectRoot);

        std::string result = relativePath.string();
        std::replace(result.begin(), result.end(), '\\', '/');

        return result;
    }
    catch (...) {
        return absolutePath;
    }
}

std::string MetaFile::MakeAbsoluteFromProject(const std::string& relativePath) {
    if (relativePath.empty()) {
        return "";
    }

    try {
        std::filesystem::path relPath(relativePath);

        // If already absolute, return as is
        if (relPath.is_absolute()) {
            return relativePath;
        }

        // Get project root
        std::filesystem::path projectRoot = LibraryManager::GetAssetsRoot();
        projectRoot = projectRoot.parent_path();

        // Combine project root + relative path
        std::filesystem::path absolutePath = projectRoot / relPath;

        return absolutePath.string();
    }
    catch (...) {
        return relativePath;
    }
}

void MetaFileManager::Initialize() {
    CleanOrphanedMetaFiles();
    ScanAssets();
}

void MetaFileManager::ScanAssets() {
    
    std::string assetsPath = LibraryManager::GetAssetsRoot();

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
            meta.fileHash = GetFileHash(assetPath);

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
    std::string assetsPath = LibraryManager::GetAssetsRoot();

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

void MetaFileManager::CheckForChanges() {
    std::string assetsPath = LibraryManager::GetAssetsRoot();

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
                meta.fileHash = GetFileHash(assetPath);

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

bool MetaFileManager::UpdateMetaIfModified(const std::string& assetPath) {
    std::string metaPath = GetMetaPath(assetPath);

    // If no .meta exists, create new one
    if (!std::filesystem::exists(metaPath)) {
        LOG_CONSOLE("[MetaFileManager] No .meta found, creating for: %s", assetPath.c_str());
        GetOrCreateMeta(assetPath);
        return true;
    }

    // Load existing .meta
    MetaFile meta = MetaFile::Load(metaPath);

    uint32_t currentFileHash = GetFileHash(assetPath);

    if (meta.fileHash != currentFileHash) {
        LOG_CONSOLE("[MetaFileManager] File modified, updating .meta: %s", assetPath.c_str());

        // Update timestamp
        meta.fileHash = currentFileHash;

        // Save changes
        if (meta.Save(metaPath)) {
            LOG_CONSOLE("[MetaFileManager] .meta updated successfully");
            return true;
        }
        else {
            LOG_CONSOLE("[MetaFileManager] ERROR: Failed to save .meta");
            return false;
        }
    }

    // No update needed
    return false;
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
    meta.fileHash = GetFileHash(assetPath);

    meta.Save(metaPath);

    return meta;
}

bool MetaFileManager::NeedsReimport(const std::string& assetPath) {
    std::string metaPath = GetMetaPath(assetPath);

    if (!std::filesystem::exists(metaPath)) {
        return true; // No .meta, needs import
    }

    MetaFile meta = MetaFile::Load(metaPath);
    return meta.NeedsReimport(assetPath);
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

    std::string assetsPath = LibraryManager::GetAssetsRoot();

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

long long MetaFileManager::GetFileTimestamp(const std::string& filePath) {
    if (!std::filesystem::exists(filePath)) {
        return 0;
    }

    return std::filesystem::last_write_time(filePath).time_since_epoch().count();
}

uint32_t MetaFileManager::GetFileHash(const std::string& path)
{
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) return 0;

    std::vector<char> buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    uint32_t crc = 0xFFFFFFFF;
    for (char c : buffer) {
        crc = crc ^ (unsigned char)c;
        for (int i = 0; i < 8; i++) {
            if (crc & 1) crc = (crc >> 1) ^ 0xEDB88320;
            else         crc = crc >> 1;
        }
    }
    return ~crc;
}

// Private Helpers

std::string MetaFileManager::GetMetaPath(const std::string& assetPath) {
    return assetPath + ".meta";
}