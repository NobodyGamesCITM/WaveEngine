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
    if (IsLoadedToMemory()) return true;

    if (libraryFile.empty()) {
        LOG_DEBUG("[ResourceTexture] ERROR: No library file specified");
        return false;
    }

    TextureData textureData = TextureImporter::LoadFromCustomFormat(uid);
    if (!textureData.IsValid()) {
        LOG_DEBUG("[ResourceTexture] ERROR: Failed to load texture data");
        return false;
    }

    glGenTextures(1, &gpu_id);
    glBindTexture(GL_TEXTURE_2D, gpu_id);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

    MetaFile meta = MetaFileManager::LoadMeta(assetsFile);
    bool useMipmaps = (meta.uid != 0 && meta.importSettings.generateMipmaps);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
        useMipmaps ? meta.importSettings.GetGLFilterMode(true) : GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    if (textureData.compressed) {
        glCompressedTexImage2D(
            GL_TEXTURE_2D, 0,
            textureData.format,
            textureData.width, textureData.height,
            0,
            textureData.dataSize,
            textureData.pixels);
    }
    else {
        GLenum fmt = (textureData.channels == 4) ? GL_RGBA : GL_RGB;
        glTexImage2D(GL_TEXTURE_2D, 0, fmt,
            textureData.width, textureData.height,
            0, fmt, GL_UNSIGNED_BYTE, textureData.pixels);
    }

    GLenum glError = glGetError();
    if (glError != GL_NO_ERROR) {
        LOG_DEBUG("[ResourceTexture] OpenGL ERROR after texture upload: 0x%04X", glError);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDeleteTextures(1, &gpu_id);
        gpu_id = 0;
        return false;
    }

    if (useMipmaps) {
        glGenerateMipmap(GL_TEXTURE_2D);
    }

    glBindTexture(GL_TEXTURE_2D, 0);

    width = textureData.width;
    height = textureData.height;
    depth = textureData.channels;
    bytes = textureData.dataSize;
    format = (textureData.channels == 4) ? RGBA : RGB;

    return true;
}

void ResourceTexture::UnloadFromMemory() {
    if (!IsLoadedToMemory()) return;

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