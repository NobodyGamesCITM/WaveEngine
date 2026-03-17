#pragma once
#include <string>
#include <vector>
#include <filesystem>
#include "Globals.h"

namespace FileSystem
{
	void Initialize();
	
	std::string GetProjectRoot();
	std::string GetAssetsRoot();
	std::string GetLibraryRoot();

	std::string GetDirectoryFromPath(const std::string& filePath);

	std::string GetFileExtension(const std::string& filePath);

	std::string GetFileName(const std::string& filePath);

	std::string FindFileInDirectory(const std::string& directoryPath, const std::string& fileName);

	std::string GetPreviousPath(const std::string& directoryPath);

	std::vector<std::string> GetListDirectoryContents(const std::string& directoryPath, bool recursive = false);

	bool IsFileDirectory(const std::string& directoryPath);

	bool DoesFileExist(const std::string& filePath);

	bool CreateNewDirectory(const std::string& directoryPath);

	int64_t GetLastModificationTime(const std::string& path);

	uint32_t GetFileHash(const std::string& path);

	long long GetFileTimestamp(const std::string& filePath);

	bool MoveAssetToFolder(const std::string& oldPath, const std::string& destinationFolder);

	bool CopyAssetToFolder(const std::string& oldPath, const std::string& destinationFolder);

	bool DeletePath(const std::string& path);

	std::string GetFileNameNoExtension(const std::string& path);

	std::string GetCleanPath(const std::string& path);

	void EnsureDirectoryExists(const std::string& path);
}