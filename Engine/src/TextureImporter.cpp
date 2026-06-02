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

#define STB_DXT_IMPLEMENTATION
#include "stb_dxt.h"

// GL compressed format constants
#define GL_COMPRESSED_RGB_S3TC_DXT1   0x83F0
#define GL_COMPRESSED_RGBA_S3TC_DXT1  0x83F1
#define GL_COMPRESSED_RGBA_S3TC_DXT5  0x83F3

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

// Comprime un bloque 4x4 RGBA a DXT1 (sin alpha) o DXT5 (con alpha)
static void CompressBlock(const unsigned char* rgba, unsigned char* dst, bool hasAlpha) {
    if (hasAlpha) {
        stb_compress_dxt_block(dst, rgba, 1, STB_DXT_HIGHQUAL);        // 16 bytes DXT5
    }
    else {
        stb_compress_dxt_block(dst, rgba, 0, STB_DXT_HIGHQUAL);        // 8 bytes DXT1
    }
}

static void DownsampleRGBA(const unsigned char* src, int srcW, int srcH,
    unsigned char* dst, int dstW, int dstH)
{
    for (int y = 0; y < dstH; y++) {
        for (int x = 0; x < dstW; x++) {
            float s[4] = {};
            int n = 0;
            for (int sy = y * 2; sy < std::min(y * 2 + 2, srcH); sy++)
                for (int sx = x * 2; sx < std::min(x * 2 + 2, srcW); sx++) {
                    int i = (sy * srcW + sx) * 4;
                    s[0] += src[i]; s[1] += src[i + 1]; s[2] += src[i + 2]; s[3] += src[i + 3];
                    n++;
                }
            int d = (y * dstW + x) * 4;
            dst[d] = (unsigned char)(s[0] / n); dst[d + 1] = (unsigned char)(s[1] / n);
            dst[d + 2] = (unsigned char)(s[2] / n); dst[d + 3] = (unsigned char)(s[3] / n);
        }
    }
}

// Comprime imagen RGBA completa a DXT1 o DXT5
// Devuelve buffer con los datos comprimidos y actualiza outSize
static unsigned char* CompressRGBA(const unsigned char* rgba,
    int width, int height,
    bool hasAlpha, unsigned int& outSize)
{
    int blockSize = hasAlpha ? 16 : 8;
    int blocksX = (width + 3) / 4;
    int blocksY = (height + 3) / 4;
    outSize = blocksX * blocksY * blockSize;

    unsigned char* dst = nullptr;
    try {
        dst = new unsigned char[outSize];
    }
    catch (const std::bad_alloc&) {
        return nullptr;
    }

    for (int by = 0; by < blocksY; ++by) {
        for (int bx = 0; bx < blocksX; ++bx) {
            // Extraer bloque 4x4 con clamp en bordes
            unsigned char block[64] = {};  // 4x4 x 4 canales

            for (int py = 0; py < 4; ++py) {
                for (int px = 0; px < 4; ++px) {
                    int srcX = std::min(bx * 4 + px, width - 1);
                    int srcY = std::min(by * 4 + py, height - 1);
                    int srcIdx = (srcY * width + srcX) * 4;
                    int dstIdx = (py * 4 + px) * 4;
                    block[dstIdx + 0] = rgba[srcIdx + 0];
                    block[dstIdx + 1] = rgba[srcIdx + 1];
                    block[dstIdx + 2] = rgba[srcIdx + 2];
                    block[dstIdx + 3] = rgba[srcIdx + 3];
                }
            }

            int blockIdx = (by * blocksX + bx) * blockSize;
            CompressBlock(block, dst + blockIdx, hasAlpha);
        }
    }

    return dst;
}

bool TextureImporter::ImportFromFile(const std::string& filepath, const MetaFile& meta)
{
    InitDevIL();
    TextureData texture;

    if (!std::filesystem::exists(filepath)) {
        LOG_DEBUG("[TextureImporter] ERROR: File does not exist: %s", filepath.c_str());
        return false;
    }

    ILuint imageID;
    ilGenImages(1, &imageID);
    ilBindImage(imageID);

    if (!ilLoadImage(filepath.c_str())) {
        ILenum error = ilGetError();
        LOG_DEBUG("[TextureImporter] ERROR: DevIL failed to load: %s (error: 0x%04X)",
            iluErrorString(error), error);
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Flips
    if (meta.importSettings.flipHorizontal) iluMirror();
    if (meta.importSettings.flipUVs)        iluFlipImage();

    // Max texture size
    int maxSize = meta.importSettings.GetMaxTextureSizeValue();
    int imgWidth = ilGetInteger(IL_IMAGE_WIDTH);
    int imgHeight = ilGetInteger(IL_IMAGE_HEIGHT);

    if (imgWidth > maxSize || imgHeight > maxSize) {
        float scale = std::min((float)maxSize / imgWidth, (float)maxSize / imgHeight);
        iluImageParameter(ILU_FILTER, ILU_BILINEAR);
        iluScale((int)(imgWidth * scale), (int)(imgHeight * scale), 1);
        imgWidth = ilGetInteger(IL_IMAGE_WIDTH);
        imgHeight = ilGetInteger(IL_IMAGE_HEIGHT);
    }

    // DXT necesita potencia de 2
    auto IsPOT = [](int n) { return n > 0 && (n & (n - 1)) == 0; };
    auto NextPOT = [](int n) { int r = 1; while (r < n) r <<= 1; return r; };

    if (!IsPOT(imgWidth) || !IsPOT(imgHeight)) {
        int newW = NextPOT(imgWidth);
        int newH = NextPOT(imgHeight);
        iluImageParameter(ILU_FILTER, ILU_BILINEAR);
        iluScale(newW, newH, 1);
        imgWidth = newW;
        imgHeight = newH;
    }

    // Leer alpha ANTES de convertir
    ILint originalFormat = ilGetInteger(IL_IMAGE_FORMAT);
    bool hasAlpha = (originalFormat == IL_RGBA ||
        originalFormat == IL_BGRA ||
        originalFormat == IL_LUMINANCE_ALPHA);

    // Convertir a RGBA
    if (!ilConvertImage(IL_RGBA, IL_UNSIGNED_BYTE)) {
        ILenum error = ilGetError();
        LOG_DEBUG("[TextureImporter] ERROR: Failed to convert to RGBA (0x%04X)", error);
        ilDeleteImages(1, &imageID);
        return false;
    }

    ILubyte* rawPixels = ilGetData();
    if (!rawPixels) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to get image data");
        ilDeleteImages(1, &imageID);
        return false;
    }

    // Comprimir con stb_dxt
    unsigned int compressedSize = 0;
    unsigned char* compressedPixels = CompressRGBA(rawPixels, imgWidth, imgHeight,
        hasAlpha, compressedSize);

    if (!compressedPixels || compressedSize == 0) {
        ilDeleteImages(1, &imageID);
        LOG_DEBUG("[TextureImporter] ERROR: Compression failed");
        return false;
    }

    struct MipLvl { 
        unsigned int size; 
        unsigned char* data; 
    };

    std::vector<MipLvl> mips;
    mips.push_back({ compressedSize, compressedPixels });

    if (meta.importSettings.generateMipmaps) {
        std::vector<unsigned char> prev(rawPixels, rawPixels + imgWidth * imgHeight * 4);
        int pw = imgWidth, ph = imgHeight;
        while (pw > 1 || ph > 1) {
            int mw = std::max(1, pw / 2), mh = std::max(1, ph / 2);
            std::vector<unsigned char> cur(mw * mh * 4);
            DownsampleRGBA(prev.data(), pw, ph, cur.data(), mw, mh);
            unsigned int ms = 0;
            unsigned char* md = CompressRGBA(cur.data(), mw, mh, hasAlpha, ms);
            if (md) mips.push_back({ ms, md });
            prev = std::move(cur);
            pw = mw; ph = mh;
        }
    }

    ilDeleteImages(1, &imageID);

    unsigned int total = 0;
    for (const auto& m : mips) { texture.mipSizes.push_back(m.size); total += m.size; }

    texture.pixels = new unsigned char[total];
    unsigned char* p = texture.pixels;
    for (const auto& m : mips) { memcpy(p, m.data, m.size); p += m.size; delete[] m.data; }

    texture.width = (unsigned int)imgWidth;
    texture.height = (unsigned int)imgHeight;
    texture.channels = hasAlpha ? 4 : 3;
    texture.format = hasAlpha ? GL_COMPRESSED_RGBA_S3TC_DXT5
        : GL_COMPRESSED_RGBA_S3TC_DXT1;
    texture.dataSize = compressedSize;
    texture.compressed = true;

    return SaveToCustomFormat(texture, meta.uid);
}

bool TextureImporter::SaveToCustomFormat(const TextureData& texture, const UID& uid) {
    std::string fullPath = LibraryManager::GetLibraryPath(uid);

    if (!texture.IsValid()) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid texture data");
        return false;
    }

    std::ofstream file(fullPath, std::ios::binary);
    if (!file.is_open()) {
        LOG_DEBUG("[TextureImporter] ERROR: Could not open for writing: %s", fullPath.c_str());
        return false;
    }

    TextureHeader header;
    header.width = texture.width;
    header.height = texture.height;
    header.channels = texture.channels;
    header.format = texture.format;
    header.dataSize = texture.dataSize;
    header.hasAlpha = (texture.channels == 4);
    header.compressed = true;
    header.numMips = (unsigned short)std::max((size_t)1, texture.mipSizes.size());

    file.write(reinterpret_cast<const char*>(&header), sizeof(TextureHeader));

    // Formato: [size0][size1]...[sizeN][data0 data1 ... dataN]
    std::vector<unsigned int> sizes = texture.mipSizes.empty()
        ? std::vector<unsigned int>{texture.dataSize}
        : texture.mipSizes;

    unsigned int total = 0;
    for (unsigned int s : sizes) {
        file.write(reinterpret_cast<const char*>(&s), sizeof(unsigned int));
        total += s;
    }
    file.write(reinterpret_cast<const char*>(texture.pixels), total);

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Write failed: %s", fullPath.c_str());
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
        LOG_DEBUG("[TextureImporter] ERROR: Could not open for reading: %s", fullPath.c_str());
        return texture;
    }

    TextureHeader header;
    file.read(reinterpret_cast<char*>(&header), sizeof(TextureHeader));

    if (!file.good() || header.width == 0 || header.height == 0 || header.dataSize == 0) {
        LOG_DEBUG("[TextureImporter] ERROR: Invalid header");
        file.close();
        return texture;
    }

    if (header.numMips == 0) {
        LOG_DEBUG("[TextureImporter] Outdated texture format, forcing reimport: %s", fullPath.c_str());
        file.close();
        std::filesystem::remove(fullPath);
        return texture;
    }

    if (header.dataSize > 200000000) {
        LOG_DEBUG("[TextureImporter] ERROR: Data size too large: %u bytes", header.dataSize);
        file.close();
        return texture;
    }

    texture.width = header.width;
    texture.height = header.height;
    texture.channels = header.channels;
    texture.format = header.format;
    texture.dataSize = header.dataSize;
    texture.compressed = header.compressed;

    unsigned short numMips = header.numMips > 0 ? header.numMips : 1;

    std::vector<unsigned int> mipSizes;
    unsigned int total = 0;
    for (int i = 0; i < numMips; i++) {
        unsigned int s = 0;
        file.read(reinterpret_cast<char*>(&s), sizeof(unsigned int));
        if (!file.good() || s == 0) {
            LOG_DEBUG("[TextureImporter] ERROR: Invalid mip size at level %d", i);
            file.close();
            return texture;
        }
        mipSizes.push_back(s);
        total += s;
    }

    try {
        texture.pixels = new unsigned char[total];
    }
    catch (const std::bad_alloc&) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to allocate %u bytes", total);
        file.close();
        return texture;
    }

    file.read(reinterpret_cast<char*>(texture.pixels), total);

    if (!file.good()) {
        LOG_DEBUG("[TextureImporter] ERROR: Failed to read pixel data");
        delete[] texture.pixels;
        texture.pixels = nullptr;
        file.close();
        return texture;
    }

    texture.mipSizes = std::move(mipSizes);

    file.close();
    return texture;
}

std::string TextureImporter::GenerateTextureFilename(const std::string& originalPath) {
    std::filesystem::path path(originalPath);

    std::string canonicalPath;
    try {
        canonicalPath = std::filesystem::exists(path)
            ? std::filesystem::canonical(path).string()
            : std::filesystem::absolute(path).string();
    }
    catch (...) {
        canonicalPath = originalPath;
    }

    std::transform(canonicalPath.begin(), canonicalPath.end(), canonicalPath.begin(), ::tolower);
    std::replace(canonicalPath.begin(), canonicalPath.end(), '\\', '/');

    std::string basename = path.stem().string();
    if (basename.empty()) basename = "unnamed_texture";

    std::replace(basename.begin(), basename.end(), ' ', '_');
    basename.erase(
        std::remove_if(basename.begin(), basename.end(),
            [](char c) { return !std::isalnum(c) && c != '_'; }),
        basename.end());
    std::transform(basename.begin(), basename.end(), basename.begin(), ::tolower);

    std::hash<std::string> hasher;
    std::stringstream ss;
    ss << basename << "_" << std::hex << hasher(canonicalPath) << ".texture";
    return ss.str();
}

unsigned int TextureImporter::GetOpenGLFormat(unsigned int channels) {
    switch (channels) {
    case 1:  return 0x1903; // GL_RED
    case 2:  return 0x8227; // GL_RG
    case 3:  return 0x1907; // GL_RGB
    case 4:  return 0x1908; // GL_RGBA
    default: return 0x1908;
    }
}