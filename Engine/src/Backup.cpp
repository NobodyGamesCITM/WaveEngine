#include "Backup.h"
#include "Log.h"
#include "Application.h"
#include "Time.h"
#include <filesystem>
#include <sstream>
#include <chrono>

Backup::Backup()
{
}

Backup::~Backup()
{
}

bool Backup::Start()
{
	std::filesystem::path tempScenePath = std::filesystem::current_path().parent_path() / "TempScene";

	if (!std::filesystem::exists(tempScenePath))
	{
		std::filesystem::create_directory(tempScenePath);
		LOG_CONSOLE("[BACKUP] TempScene directory created.");
	}
	else
	{
		LOG_CONSOLE("[BACKUP] TempScene directory already exists.");
	}

	tempSceneDir = tempScenePath.string();
	timeSinceLastBackup = 0.0f;
	timeSinceLastCleanup = 0.0f;

	CleanOldBackups();

	return true;
}

bool Backup::Update()
{
	// Don't generate backups while in Play or Paused mode
	if (Application::GetInstance().GetPlayState() != Application::PlayState::EDITING)
		return true;

	timeSinceLastBackup += Application::GetInstance().time->GetRealDeltaTime();

	if (timeSinceLastBackup >= backupInterval)
	{
		PerformBackup();
		timeSinceLastBackup = 0.0f;
	}

	timeSinceLastCleanup += Application::GetInstance().time->GetRealDeltaTime();

	if (timeSinceLastCleanup >= cleanupInterval)
	{
		CleanOldBackups();
		timeSinceLastCleanup = 0.0f;
	}

	return true;
}

bool Backup::CleanUp()
{
	return true;
}

void Backup::PerformBackup()
{
	std::string timestamp = GetTimestamp();
	std::string backupFilename = tempSceneDir + "/backup_" + timestamp + ".json";

	bool success = Application::GetInstance().scene->SaveScene(backupFilename);

	/*if (success)
	{
		LOG_CONSOLE("[BACKUP] Scene saved: %s", backupFilename.c_str());
	}
	else
	{
		LOG_CONSOLE("[BACKUP] ERROR: Failed to save scene: %s", backupFilename.c_str());
	}*/
}

std::string Backup::GetTimestamp()
{
	auto now = std::chrono::system_clock::now();
	auto time = std::chrono::system_clock::to_time_t(now);

	std::stringstream ss;
	ss << std::put_time(std::localtime(&time), "%Y%m%d_%H%M%S");

	return ss.str();
}

void Backup::CleanOldBackups()
{
	if (!std::filesystem::exists(tempSceneDir))
	{
		return;
	}

	auto now = std::chrono::system_clock::now();
	auto now_time_t = std::chrono::system_clock::to_time_t(now);
	long long currentTime = static_cast<long long>(now_time_t);

	int deletedCount = 0;

	std::filesystem::directory_iterator dirIt(tempSceneDir);
	for (const auto& entry : dirIt)
	{
		std::string filename = entry.path().filename().string();

		// obtain last write time
		auto lastWrite = entry.last_write_time();

		// file_clock::time_point  -->  system_clock::time_point  -->  time_t  -->  long long
		auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
			lastWrite - std::filesystem::file_time_type::clock::now() + std::chrono::system_clock::now()
		);
		auto tt = std::chrono::system_clock::to_time_t(sctp);
		long long fileTime = static_cast<long long>(tt);

		// calculate age in seconds
		long long age = currentTime - fileTime;

		// if age exceeds max age, delete the file
		if (age > backupMaxAge)
		{
			std::error_code ec;
			bool removed = std::filesystem::remove(entry.path(), ec);

			/*if (removed)
			{
				deletedCount++;
				LOG_CONSOLE("[BACKUP] Deleted old backup: %s (age: %lld seconds)", filename.c_str(), age);
			}
			else
			{
				LOG_CONSOLE("[BACKUP] WARNING: Could not delete %s (error code: %d)", filename.c_str(), ec.value());
			}*/
		}
	}

	/*if (deletedCount > 0)
	{
		LOG_CONSOLE("[BACKUP] Cleaned up %d old backup(s)", deletedCount);
	}*/
}