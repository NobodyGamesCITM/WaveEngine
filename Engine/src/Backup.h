#pragma once
#include "Module.h"

class Backup : public Module 
{
public:
	Backup();
	~Backup();
	//bool Awake() override;
	bool Start() override;
	bool Update() override;
	bool CleanUp() override;


private:

	void PerformBackup();
	void CleanOldBackups();
	std::string GetTimestamp();

	float timeSinceLastBackup = 0.0f;
	float timeSinceLastCleanup = 0.0f;

	const float backupInterval = 300.0f; // 5min backup creation
	const float cleanupInterval = 600.0f;// 10 min backup cleanup interval
	const long long backupMaxAge = 1800; // 30 minutes if the backup is older than this, it is deleted. 
	// for testing : backupInterval = 5.0f, cleanupInterval = 15.0f, backupMaxAge = 20
	// also uncomment the log lines in PerformBackup, Start and CleanOldBackups to see el proses
	std::string tempSceneDir;
};

