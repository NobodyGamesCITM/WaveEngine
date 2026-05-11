#include "TextureImporter.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include "Log.h"
#include <IL/il.h>
#include <IL/ilu.h>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <algorithm>
#include <iomanip>

bool TextureImporter::s_devilInitialized = false;

TextureImporter::TextureImporter() {}
TextureImporter::~TextureImporter() {}

void TextureImporter::InitDevIL() {
    if (!s_devilInitialized) {
        ilInit();
        iluInit();
        ilEnable(IL_ORIGIN_SET);
        ilOriginFunc(IL_ORIGIN_LOWER_LEFT);
        s_devilInitialized = true;
        LOG_DEBUG("[TextureImporter] DevIL initialized");
    }
}


bool TextureImporter::ImportFromFile(const std::string& filepath, const MetaFile& meta) 
{
    InitDevIL();

    TextureData texture;

    if (!std::filesystem::exists(filepath)) {
        LOG_DEBUG("[TextureImporter] ERROR: File does not exist: %s", filepath.c_str());
        return false;
    }

    std::filesystem::path path(filepath);
    std::string extension = path.extension().string();
    std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);

    // Create new image ID for each import to avoid state conflicts
    ILuint imageID;
    ilGenImages(1, &imageID);
    ilBindImage(imageID);

    // Clear any previous errors
    while (ilGetError() != IL_NO_ERROR);
    LOG_DEBUG("[TextureImporter] Loading: %s (flipV=%d, flipH=%d)",
        filepath.c_str(), meta.importSettings, meta.importSettings.flipHorizontal);

    // Load image
    if (!ilLoadImage(filepath.c_str())) {
        ILenum error = ilGetError();
        LOG_DEBUG("[TextureImporter] ERROR: DevIL failed to load image: %s (error: 0x%04X)",
            iluErrorString(error), error);
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Get original dimensions
    int originalWidth = ilGetInteger(IL_IMAGE_WIDTH);
    int originalHeight = ilGetInteger(IL_IMAGE_HEIGHT);
    LOG_DEBUG("[TextureImporter] Original size: %dx%d", originalWidth, originalHeight);

    // Apply horizontal flip FIRST (if needed)
    if (meta.importSettings.flipHorizontal) {
        iluMirror();
        LOG_DEBUG("[TextureImporter] Applied horizontal flip");
    }

    // Apply vertical flip (if needed)
    if (meta.importSettings.flipUVs) {
        iluFlipImage();
        LOG_DEBUG("[TextureImporter] Applied vertical flip");
    }

    // Apply max texture size
    int maxSize = meta.importSettings.GetMaxTextureSizeValue();
    int imgWidth = ilGetInteger(IL_IMAGE_WIDTH);
    int imgHeight = ilGetInteger(IL_IMAGE_HEIGHT);

    if (imgWidth > maxSize || imgHeight > maxSize) {
        float scale = std::min((float)maxSize / imgWidth, (float)maxSize / imgHeight);
        int newWidth = (int)(imgWidth * scale);
        int newHeight = (int)(imgHeight * scale);

        iluImageParameter(ILU_FILTER, ILU_BILINEAR);
        if (!iluScale(newWidth, newHeight, 1)) {
            LOG_DEBUG("[TextureImporter] WARNING: Failed to resize texture");
        }
        else {
            LOG_DEBUG("[TextureImporter] Resized from %dx%d to %dx%d",
                imgWidth, imgHeight, newWidth, newHeight);
        }
    }

    // Convert to RGBA
    if (!ilConvertImage(IL_RGBA, IL_UNSIGNED_BYTE)) {
        ILenum error = ilGetError();
        LOG_DEBUG("[TextureImporter] ERROR: Failed to convert to RGBA (error: 0x%04X)", error);
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Get final dimensions after all operations
    texture.width = ilGetInteger(IL_IMAGE_WIDTH);
    texture.height = ilGetInteger(IL_IMAGE_HEIGHT);
    texture.channels = 4;

    if (texture.width == 0 || texture.height == 0) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid image dimensions after processing");
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Get pixel data
    ILubyte* data = ilGetData();
    if (!data) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to get image data");
        ilDeleteImages(1, &imageID);
        return false;
    }

    size_t dataSize = static_cast<size_t>(texture.width) * static_cast<size_t>(texture.height) * 4;

    if (dataSize == 0 || dataSize > 100000000) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid data size: %zu bytes", dataSize);
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Allocate and copy pixel data
    try {
        texture.pixels = new unsigned char[dataSize];
        memcpy(texture.pixels, data, dataSize);
    }
    catch (const std::bad_alloc&) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to allocate %zu bytes", dataSize);
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Clean up DevIL resources
    ilDeleteImages(1, &imageID);

    LOG_DEBUG("[TextureImporter] Texture imported successfully: %dx%d, %zu bytes",
        texture.width, texture.height, dataSize);

    return SaveToCustomFormat(texture, meta.uid);
}

bool TextureImporter::SaveToCustomFormat(const TextureData& texture, const UID& uid) {
    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    if (!texture.IsValid()) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid texture data");
        return false;
    }

    if (texture.pixels == nullptr) {
        LOG_DEBUG("[TextureImporter] ERROR: texture.pixels is nullptr");
        return false;
    }

    if (texture.width == 0 || texture.height == 0) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid dimensions: %ux%u", texture.width, texture.height);
        return false;
    }

    size_t expectedSize = static_cast<size_t>(texture.width) * static_cast<size_t>(texture.height) * 4;
    if (expectedSize == 0 || expectedSize > 100000000) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid data size: %zu bytes", expectedSize);
        return false;
    }

    std::ofstream file(fullPath, std::ios::binary);
    if (!file.is_open()) {
        LOG_DEBUG("[TextureImporter] ERROR: Could not open file for writing: %s", fullPath.c_str());
        return false;
    }

    TextureHeader header;
    header.width = texture.width;
    header.height = texture.height;
    header.channels = 4;
    header.format = GetOpenGLFormat(4);
    header.dataSize = static_cast<unsigned int>(expectedSize);
    header.hasAlpha = true;
    header.compressed = false;

    file.write(reinterpret_cast<const char*>(&header), sizeof(TextureHeader));

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to write header");
        file.close();
        return false;
    }

    file.write(reinterpret_cast<const char*>(texture.pixels), header.dataSize);

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to write pixel data");
        file.close();
        return false;
    }

    file.close();

    return true;
}

TextureData TextureImporter::LoadFromCustomFormat(const UID& uid) {
    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    TextureData texture;

    std::ifstream file(fullPath, std::ios::binary);
    if (!file.is_open()) {
        LOG_DEBUG("[TextureImporter] ERROR: Could not open file for reading: %s", fullPath.c_str());
        return texture;
    }

    TextureHeader header;
    file.read(reinterpret_cast<char*>(&header), sizeof(TextureHeader));

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to read header");
        file.close();
        return texture;
    }

    if (header.width == 0 || header.height == 0 || header.dataSize == 0) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid header - width=%u, height=%u, dataSize=%u",
            header.width, header.height, header.dataSize);
        file.close();
        return texture;
    }

    if (header.dataSize > 100000000) {
        LOG_DEBUG("[TextureImporter] ERROR: Data size too large: %u bytes", header.dataSize);
        file.close();
        return texture;
    }

    texture.width = header.width;
    texture.height = header.height;
    texture.channels = header.channels;

    try {
        texture.pixels = new unsigned char[header.dataSize];
    }
    catch (const std::bad_alloc&) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to allocate %u bytes", header.dataSize);
        file.close();
        return texture;
    }

    file.read(reinterpret_cast<char*>(texture.pixels), header.dataSize);

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to read pixel data");
        delete[] texture.pixels;
        texture.pixels = nullptr;
        file.close();
        return texture;
    }

    file.close();

    LOG_DEBUG("[TextureImporter] Loaded texture: %s (%ux%u)",
        fullPath.c_str(), texture.width, texture.height);

    return texture;
}

std::string TextureImporter::GenerateTextureFilename(const std::string& originalPath) {
    std::filesystem::path path(originalPath);

    std::string canonicalPath;
    try {
        if (std::filesystem::exists(path)) {
            canonicalPath = std::filesystem::canonical(path).string();
        }
        else {
            canonicalPath = std::filesystem::absolute(path).string();
        }
    }
    catch (...) {
        canonicalPath = originalPath;
    }

    std::transform(canonicalPath.begin(), canonicalPath.end(),
        canonicalPath.begin(), ::tolower);

    std::replace(canonicalPath.begin(), canonicalPath.end(), '\\', '/');

    std::string basename = path.stem().string();

    if (basename.empty()) {
        basename = "unnamed_texture";
    }

    std::replace(basename.begin(), basename.end(), ' ', '_');
    basename.erase(
        std::remove_if(basename.begin(), basename.end(),
            [](char c) { return !std::isalnum(c) && c != '_'; }),
        basename.end()
    );
    std::transform(basename.begin(), basename.end(), basename.begin(), ::tolower);

    std::hash<std::string> hasher;
    size_t hashValue = hasher(canonicalPath);

    std::stringstream ss;
    ss << basename << "_" << std::hex << hashValue << ".texture";

    return ss.str();
}

unsigned int TextureImporter::GetOpenGLFormat(unsigned int channels) {
    switch (channels) {
    case 1: return 0x1903; // GL_RED
    case 2: return 0x8227; // GL_RG
    case 3: return 0x1907; // GL_RGB
    case 4: return 0x1908; // GL_RGBA
    default: return 0x1908; // GL_RGBA by default
    }
}