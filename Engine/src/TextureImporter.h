#pragma once

#include "Globals.h"
#include <string>
#include <glm/glm.hpp>

struct TextureData;
struct ImportSettings; 
struct MetaFile; 

// Header for custom texture format
struct TextureHeader {
    unsigned int width = 0;
    unsigned int height = 0;
    unsigned int channels = 0;
    unsigned int format = 0;
    unsigned int dataSize = 0;
    bool hasAlpha = false;
    bool compressed = false;
};

// Runtime texture data
struct TextureData {
    unsigned int width = 0;
    unsigned int height = 0;
    unsigned int channels = 0;
    unsigned char* pixels = nullptr;

    TextureData() = default;
    TextureData(const TextureData&) = delete;
    TextureData& operator=(const TextureData&) = delete;

    TextureData(TextureData&& other) noexcept
        : width(other.width)
        , height(other.height)
        , channels(other.channels)
        , pixels(other.pixels)
    {
        other.pixels = nullptr;
        other.width = 0;
        other.height = 0;
        other.channels = 0;
    }

    TextureData& operator=(TextureData&& other) noexcept {
        if (this != &other) {
            if (pixels != nullptr) {
                delete[] pixels;
            }
            width = other.width;
            height = other.height;
            channels = other.channels;
            pixels = other.pixels;
            other.pixels = nullptr;
            other.width = 0;
            other.height = 0;
            other.channels = 0;
        }
        return *this;
    }

    ~TextureData() {
        if (pixels != nullptr) {
            delete[] pixels;
            pixels = nullptr;
        }
    }

    bool IsValid() const {
        return pixels != nullptr && width > 0 && height > 0;
    }
};

class TextureImporter {
public:
    TextureImporter();
    ~TextureImporter();

    static bool ImportFromFile(const std::string& filepath,
        const MetaFile& meta);

    static bool SaveToCustomFormat(const TextureData& texture, const UID& uid);
    static TextureData LoadFromCustomFormat(const UID& uid);
    static std::string GenerateTextureFilename(const std::string& originalPath);
    static unsigned int GetOpenGLFormat(unsigned int channels);

private:
    static void InitDevIL();
    static bool s_devilInitialized;
};