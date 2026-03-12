#pragma once

#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <sstream>
#include <filesystem>
#include "Globals.h"


enum class AssetType {
    UNKNOWN = 0,
    MODEL_FBX = 1,
    TEXTURE_PNG = 2,
    TEXTURE_JPG = 3,
    TEXTURE_DDS = 4,
    TEXTURE_TGA = 5,
    SHADER_GLSL = 6,
    SCRIPT_LUA = 7,
    PREFAB = 8,
    MATERIAL = 9
};

struct ImportSettings {
    // Mesh/Model settings
    float importScale = 1.0f;
    bool generateNormals = true;
    bool flipUVs = true;
    bool optimizeMeshes = true;

    // Axis configuration
    int upAxis = 0;        // 0=Y-Up, 1=Z-Up
    int frontAxis = 0;     // 0=Z-Forward, 1=Y-Forward, 2=X-Forward

    // Texture settings
    bool generateMipmaps = true;
    int filterMode = 2;    // 0=Point, 1=Bilinear, 2=Trilinear
    bool flipHorizontal = false;
    int maxTextureSize = 6;     // Index: 0=32, 1=64, 2=128, 3=256, 4=512, 5=1024, 6=2048, 7=4096, 8=8192

    // Helper para obtener el modo OpenGL de filtrado
    unsigned int GetGLFilterMode(bool mipmap = false) const {
        if (!mipmap) {
            switch (filterMode) {
            case 0: return 0x2600;  // GL_NEAREST
            case 1: return 0x2601;  // GL_LINEAR
            case 2: return 0x2601;  // GL_LINEAR
            default: return 0x2601; // GL_LINEAR
            }
        }
        else {
            switch (filterMode) {
            case 0: return 0x2700;  // GL_NEAREST_MIPMAP_NEAREST
            case 1: return 0x2701;  // GL_LINEAR_MIPMAP_NEAREST
            case 2: return 0x2703;  // GL_LINEAR_MIPMAP_LINEAR
            default: return 0x2703; // GL_LINEAR_MIPMAP_LINEAR
            }
        }
    }

    // Helper para obtener el tamaño máximo de textura
    int GetMaxTextureSizeValue() const {
        const int sizes[] = { 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192 };
        if (maxTextureSize >= 0 && maxTextureSize < 9) {
            return sizes[maxTextureSize];
        }
        return 2048; // Default
    }
};

struct MetaFile {
    UID uid = 0;
    AssetType type = AssetType::UNKNOWN;
    std::string originalPath;
    uint32_t fileHash = 0;
    ImportSettings importSettings;
    std::map<std::string, UID> meshes;
    std::map<std::string, UID> animations;

    static AssetType GetAssetType(const std::string& extension);

    bool Save(const std::string& metaFilePath) const;
    static MetaFile Load(const std::string& metaFilePath);

    bool NeedsReimport(const std::string& assetPath) const;

    static std::string MakeRelativeToProject(const std::string& absolutePath);
    static std::string MakeAbsoluteFromProject(const std::string& relativePath);
};

class MetaFileManager {
public:
    static void Initialize();
    static void ScanAssets();
    static void CleanOrphanedMetaFiles();
    static void CheckForChanges();
    static MetaFile GetOrCreateMeta(const std::string& assetPath);
    static bool NeedsReimport(const std::string& assetPath);
    static void RegenerateLibrary();
    static bool UpdateMetaIfModified(const std::string& assetPath);

    static MetaFile LoadMeta(const std::string& assetPath);
    static UID GetUIDFromAsset(const std::string& assetPath);
    static std::string GetAssetFromUID(UID uid);
    static long long GetFileTimestamp(const std::string& filePath);
    static uint32_t GetFileHash(const std::string& path);

private:
    static std::string GetMetaPath(const std::string& assetPath);
};