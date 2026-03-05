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

	const float backupInterval = 5.0f; 
	const float cleanupInterval = 15.0f;  
	const long long backupMaxAge = 20;    
	// for testing try: backupInterval = 5.0f, cleanupInterval = 15.0f, backupMaxAge = 20;
	// also uncomment the log lines in PerformBackup, Start and CleanOldBackups to see the backup process 
	std::string tempSceneDir;
};

