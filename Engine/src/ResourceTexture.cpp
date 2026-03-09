#include "ResourceTexture.h"
#include "TextureImporter.h"
#include "Log.h"
#include <glad/glad.h>
#include "MetaFile.h"

ResourceTexture::ResourceTexture(UID uid)
    : Resource(uid, Resource::TEXTURE) {
}

ResourceTexture::~ResourceTexture() {
    UnloadFromMemory();
}

bool ResourceTexture::LoadInMemory() {
    if (IsLoadedToMemory()) {
        LOG_DEBUG("[ResourceTexture] Already loaded in memory: %llu", uid);
        return true;
    }

    if (libraryFile.empty()) {
        LOG_DEBUG("[ResourceTexture] ERROR: No library file specified");
        return false;
    }

    // Extract filename from library path
    std::string filename = libraryFile;
    size_t lastSlash = filename.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        filename = filename.substr(lastSlash + 1);
    }

    LOG_DEBUG("[ResourceTexture] Loading from Library: %s", filename.c_str());

    // Load texture data from custom format
    TextureData textureData = TextureImporter::LoadFromCustomFormat(uid);

    if (!textureData.IsValid()) {
        LOG_DEBUG("[ResourceTexture] ERROR: Failed to load texture data");
        return false;
    }

    LOG_DEBUG("[ResourceTexture] Loaded texture data: %dx%d, %d channels",
        textureData.width, textureData.height, textureData.channels);

    // Create OpenGL texture
    glGenTextures(1, &gpu_id);
    glBindTexture(GL_TEXTURE_2D, gpu_id);

    // Load .meta to get import settings
    MetaFile meta = MetaFileManager::LoadMeta(assetsFile);

    if (meta.uid != 0) {
        LOG_DEBUG("[ResourceTexture] Applying import settings from .meta");

        // Wrap mode always REPEAT (default)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

        // Apply filter mode
        if (meta.importSettings.generateMipmaps) {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
                meta.importSettings.GetGLFilterMode(true));
        }
        else {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
                meta.importSettings.GetGLFilterMode(false));
        }

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,
            meta.importSettings.GetGLFilterMode(false));

        LOG_DEBUG("[ResourceTexture] Settings: filter=%d, mipmaps=%d",
            meta.importSettings.filterMode,
            meta.importSettings.generateMipmaps);
    }
    else {
        LOG_DEBUG("[ResourceTexture] No .meta found, using defaults");

        // Default settings
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }

    // Upload texture data to GPU
    GLenum format = (textureData.channels == 4) ? GL_RGBA : GL_RGB;
    glTexImage2D(GL_TEXTURE_2D, 0, format, textureData.width, textureData.height,0, format, GL_UNSIGNED_BYTE, textureData.pixels);

    // Check for OpenGL errors
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        LOG_DEBUG("[ResourceTexture] OpenGL ERROR after glTexImage2D: 0x%04X", error);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDeleteTextures(1, &gpu_id);
        gpu_id = 0;
        return false;
    }

    // Generate mipmaps if enabled
    if (meta.uid != 0 && meta.importSettings.generateMipmaps) {
        glGenerateMipmap(GL_TEXTURE_2D);

        error = glGetError();
        if (error != GL_NO_ERROR) {
            LOG_DEBUG("[ResourceTexture] OpenGL ERROR after glGenerateMipmap: 0x%04X", error);
        }
        else {
            LOG_DEBUG("[ResourceTexture] Mipmaps generated successfully");
        }
    }

    glBindTexture(GL_TEXTURE_2D, 0);

    // Store texture info
    width = textureData.width;
    height = textureData.height;
    depth = textureData.channels;
    bytes = textureData.width * textureData.height * textureData.channels;
    format = (textureData.channels == 4) ? RGBA : RGB;

    LOG_DEBUG("[ResourceTexture] Successfully loaded in GPU memory (ID: %u)", gpu_id);

    return true;
}

void ResourceTexture::UnloadFromMemory() {
    if (!IsLoadedToMemory()) {
        return;
    }

    LOG_DEBUG("[ResourceTexture] Unloading from memory: UID=%llu, GPU_ID=%u", uid, gpu_id);

    if (gpu_id != 0) {
        glDeleteTextures(1, &gpu_id);
        gpu_id = 0;
    }

    width = 0;
    height = 0;
    depth = 0;
    bytes = 0;
    format = UNKNOWN;
}

