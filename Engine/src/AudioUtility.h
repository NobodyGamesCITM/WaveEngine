#pragma once
#include <ctime>
#include <string>
#include "Log.h"

// Standard C++ used by Wwise logic
#include <iostream>
#include <list>
#include <string>
#include <vector>

// Wwise Memory and Module Management
#include <AK/SoundEngine/Common/AkMemoryMgr.h>
#include <AK/SoundEngine/Common/AkMemoryMgrModule.h>
//#include <Common/AkFilePackageLowLevelIODeferred.h>		// Low-level I/O implementation from samples folder

// Wwise Streaming and Tools
#include <AK/SoundEngine/Common/IAkStreamMgr.h>
#include <AK/Tools/Common/AkPlatformFuncs.h>

// Wwise Sound Engine and Spatial Audio
// Note: We skip AkMusicEngine.h as it is now integrated into the Sound Engine
#include <AK/SoundEngine/Common/AkSoundEngine.h>
#include <AK/SpatialAudio/Common/AkSpatialAudio.h>

// Communication (Only for Debug/Profile builds)
#ifndef AK_OPTIMIZED
#include <AK/Comm/AkCommunication.h>
#endif


// SoundBank Name Definitions
// Using AKTEXT to ensure platform compatibility (Wide chars for Windows)
#define BANKNAME_INIT AKTEXT("Init.bnk")
#define BANKNAME_MUSIC AKTEXT("MainSoundBank.bnk")

// Generated IDs (This connects your C++ strings to Wwise UIDs)
// Ensure this path matches your exported Wwise project location
//#include "../Assets/Audio/GeneratedSoundBanks/Wwise_IDs.h"
#include "Wwise_IDs.h"
