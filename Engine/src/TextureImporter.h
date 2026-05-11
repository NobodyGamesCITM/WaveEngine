#pragma once
#include "Globals.h"
#include <string>
#include <glm/glm.hpp>

struct TextureData;
struct ImportSettings;
struct MetaFile;

#pragma pack(push, 1)
struct TextureHeader {
    unsigned int width = 0;
    unsigned int height = 0;
    unsigned int channels = 0;
    unsigned int format = 0;
    unsigned int dataSize = 0;
    bool         hasAlpha = false;
    bool         compressed = false;
    char         padding[2] = {};
};
#pragma pack(pop)

struct TextureData {
    unsigned int   width = 0;
    unsigned int   height = 0;
    unsigned int   channels = 0;
    unsigned char* pixels = nullptr;
    unsigned int   format = 0;
    unsigned int   dataSize = 0;
    bool           compressed = false;

    TextureData() = default;

    TextureData(const TextureData&) = delete;
    TextureData& operator=(const TextureData&) = delete;

    TextureData(TextureData&& other) noexcept
        : width(other.width)
        , height(other.height)
        , channels(other.channels)
        , pixels(other.pixels)
        , format(other.format)
        , dataSize(other.dataSize)
        , compressed(other.compressed)
    {
        other.pixels = nullptr;
        other.width = 0;
        other.height = 0;
        other.channels = 0;
        other.format = 0;
        other.dataSize = 0;
        other.compressed = false;
    }

    TextureData& operator=(TextureData&& other) noexcept {
        if (this != &other) {
            delete[] pixels;
            width = other.width;
            height = other.height;
            channels = other.channels;
            pixels = other.pixels;
            format = other.format;
            dataSize = other.dataSize;
            compressed = other.compressed;

            other.pixels = nullptr;
            other.width = 0;
            other.height = 0;
            other.channels = 0;
            other.format = 0;
            other.dataSize = 0;
            other.compressed = false;
        }
        return *this;
    }

    ~TextureData() {
        delete[] pixels;
        pixels = nullptr;
    }

    bool IsValid() const {
        return pixels != nullptr && width > 0 && height > 0 && dataSize > 0;
    }
};

class TextureImporter {
public:
    TextureImporter();
    ~TextureImporter();

    static bool        ImportFromFile(const std::string& filepath, const MetaFile& meta);
    static bool        SaveToCustomFormat(const TextureData& texture, const UID& uid);
    static TextureData LoadFromCustomFormat(const UID& uid);
    static std::string GenerateTextureFilename(const std::string& originalPath);
    static unsigned int GetOpenGLFormat(unsigned int channels);

private:
    static void InitDevIL();
    static bool s_devilInitialized;
};