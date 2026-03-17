#include "FileSystem.h"
#include "Log.h"
#include <fstream>
#include <windows.h>
#include <chrono>

namespace fs = std::filesystem;

static bool s_initialized = false;
static std::filesystem::path s_projectRoot = "";
static std::filesystem::path s_assetsRoot = "";
static std::filesystem::path s_libraryRoot = "";

void FileSystem::Initialize()
{
    if (s_initialized) return;

    LOG_CONSOLE("[FileSystem] Initializing FileSystem and locating paths...");

    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    fs::path execPath(buffer);

    fs::path currentSearchPath = execPath.parent_path();
    bool assetsFound = false;
    int maxLevels = 5;

    for (int i = 0; i < maxLevels; ++i) {
        fs::path candidatePath = currentSearchPath / "Assets";

        if (fs::exists(candidatePath) && fs::is_directory(candidatePath)) {

            s_projectRoot = currentSearchPath;
            s_assetsRoot = candidatePath;
            s_libraryRoot = currentSearchPath / "Library";

            assetsFound = true;
            LOG_CONSOLE("[FileSystem] Project root found at: %s", s_projectRoot.string().c_str());
            break;
        }

        currentSearchPath = currentSearchPath.parent_path();

        if (currentSearchPath == currentSearchPath.parent_path()) break;
    }

    if (!assetsFound) {
        LOG_CONSOLE("[FileSystem] FATAL ERROR: Could not find Assets folder. Engine cannot run properly.");
        return;
    }

    s_initialized = true;
}

std::string FileSystem::GetLibraryRoot() {
    return (s_projectRoot / "Library").string();
}

std::string FileSystem::GetAssetsRoot() {
    return (s_projectRoot / "Assets").string();
}

std::string FileSystem::GetProjectRoot() {
    return (s_projectRoot).string();
}

std::string FileSystem::GetDirectoryFromPath(const std::string& filePath)
{
    std::filesystem::path path(filePath);

    std::string directory = path.parent_path().generic_string();

    if (!directory.empty() && directory.back() != '/')
    {
        directory += '/';
    }

    return directory;
}

std::string FileSystem::GetFileExtension(const std::string& filePath)
{
    std::filesystem::path path(filePath);
    std::string ext = path.extension().generic_string();

    if (!ext.empty() && ext[0] == '.')
    {
        ext = ext.substr(1);
    }

    std::transform(ext.begin(), ext.end(), ext.begin(),
        [](unsigned char c) { return std::tolower(c); });

    return ext;
}

std::string FileSystem::GetFileName(const std::string& filePath)
{
    std::filesystem::path path(filePath);
    return path.filename().generic_string();
}

std::string FileSystem::FindFileInDirectory(const std::string& directoryPath, const std::string& fileName)
{
    try
    {
        for (const auto& entry : std::filesystem::recursive_directory_iterator(directoryPath))
        {
            if (entry.is_regular_file() && entry.path().filename() == fileName)
            {
                return entry.path().generic_string();
            }
        }
    }
    catch (const std::filesystem::filesystem_error& e)
    {
        LOG_DEBUG("Failed searching in directory: %s", e.what());
    }

    return "";
}

std::vector<std::string> FileSystem::GetListDirectoryContents(const std::string& directoryPath, bool recursive)
{
    std::vector<std::string> allContent;

    auto options = std::filesystem::directory_options::skip_permission_denied;

    std::error_code ec;

    if (recursive)
    {
        for (const auto& entry : std::filesystem::recursive_directory_iterator(directoryPath, options, ec))
        {
            if (ec) {
                LOG_DEBUG("Failed accessing a file during recursive scan inside %s", directoryPath.c_str());
                ec.clear();
                continue;
            }

            try {
                if (entry.exists(ec) && !ec) {
                    allContent.push_back(entry.path().generic_string());
                }
            }
            catch (...) {
                continue;
            }
        }
    }
    else
    {
        for (const auto& entry : std::filesystem::directory_iterator(directoryPath, options, ec))
        {
            if (ec) {
                ec.clear();
                continue;
            }
            allContent.push_back(entry.path().generic_string());
        }
    }

    if (ec) {
        LOG_DEBUG("Could not open directory %s", directoryPath.c_str());
    }

    return allContent;
}

bool FileSystem::IsFileDirectory(const std::string& directoryPath)
{
    return std::filesystem::is_directory(directoryPath);
}

bool FileSystem::DoesFileExist(const std::string& filePath)
{
    return std::filesystem::exists(filePath);
}

std::string FileSystem::GetPreviousPath(const std::string& directoryPath)
{

    std::filesystem::path path(directoryPath);

    if (path.has_parent_path())
    {
        return path.parent_path().generic_string();
    }

    return path.generic_string();
}

bool FileSystem::CreateNewDirectory(const std::string& directoryPath)
{
    return std::filesystem::create_directory(directoryPath);
}

int64_t FileSystem::GetLastModificationTime(const std::string& path)
{
    if (!std::filesystem::exists(path)) return 0;

    auto fileTime = std::filesystem::last_write_time(path);

    auto duration = fileTime.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::seconds>(duration).count();
}

uint32_t FileSystem::GetFileHash(const std::string& path)
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


long long FileSystem::GetFileTimestamp(const std::string& filePath) {
    if (!std::filesystem::exists(filePath)) {
        return 0;
    }

    return std::filesystem::last_write_time(filePath).time_since_epoch().count();
}

bool FileSystem::MoveAssetToFolder(const std::string& oldPath, const std::string& destinationFolder)
{
    std::error_code ec;

    std::filesystem::path source(oldPath);
    std::filesystem::path destDir(destinationFolder);
    std::filesystem::path finalDestination = destDir / source.filename();

    if (!std::filesystem::exists(source)) {
        LOG_DEBUG("Source file does not exist. Move cancelled: %s", oldPath.c_str());
        return false;
    }

    if (std::filesystem::exists(finalDestination)) {
        LOG_DEBUG("Destination file already exists. Move cancelled: %s", finalDestination.string().c_str());
        return false;
    }

    std::filesystem::rename(source, finalDestination, ec);

    if (ec) {
        LOG_DEBUG("Failed moving asset: %s", ec.message().c_str());
        return false;
    }


    return true;
}

bool FileSystem::CopyAssetToFolder(const std::string& sourcePath, const std::string& destinationFolder)
{
    std::error_code ec;

    std::filesystem::path source(sourcePath);
    std::filesystem::path destDir(destinationFolder);
    std::filesystem::path finalDestination = destDir / source.filename();

    if (!std::filesystem::exists(source)) {
        LOG_DEBUG("Source file does not exist. Copy cancelled: %s", sourcePath.c_str());
        return false;
    }

    if (std::filesystem::exists(finalDestination)) {
        LOG_DEBUG("Destination file already exists. Copy cancelled: %s", finalDestination.string().c_str());
        return false;
    }

    std::filesystem::copy(source, finalDestination, std::filesystem::copy_options::recursive, ec);

    if (ec) {
        LOG_DEBUG("Failed copying asset: %s", ec.message().c_str());
        return false;
    }

    return true;
}

bool FileSystem::DeletePath(const std::string& path)
{
    std::error_code ec;

    if (!std::filesystem::exists(path))
    {
        LOG_DEBUG("File to delete not found: %s", path.c_str());
        return false;
    }

    bool success = std::filesystem::remove_all(path, ec);

    if (ec)
    {
        LOG_DEBUG("Failed deleting asset: %s. Message: %s", path.c_str(), ec.message().c_str());
        return false;
    }

    LOG_DEBUG("Deleted asset successfully: %s", path.c_str());

    return true;
}

std::string FileSystem::GetFileNameNoExtension(const std::string& filePath)
{
    std::filesystem::path path(filePath);

    return path.stem().string();
}

std::string FileSystem::GetCleanPath(const std::string& incomingPath)
{
    std::filesystem::path path(incomingPath);
    return path.generic_string().c_str();
}

void FileSystem::EnsureDirectoryExists(const std::string& incomingPath) {

    std::filesystem::path path(incomingPath);

    try {
        if (!std::filesystem::exists(path)) {
            std::filesystem::create_directories(path);
            LOG_DEBUG("Created directory: %s", path.string().c_str());
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[FileSystem] ERROR creating directory %s: %s", path.string().c_str(), e.what());
    }
}