#pragma once

#include <AK/SoundEngine/Common/AkMemoryMgr.h>			// Memory Manager interface
#include <AK/SoundEngine/Common/AkMemoryMgrModule.h>				// Default memory manager

#include <AK/SoundEngine/Common/IAkStreamMgr.h>			// Streaming Manager
#include <AK/Tools/Common/AkPlatformFuncs.h>			// Thread defines
//#include <AK/Common/AkFilePackageLowLevelIODeferred.h>		// Sample low-level I/O implementation

#include <AK/SoundEngine/Common/AkSoundEngine.h>		// Sound engine


#include <AK/SpatialAudio/Common/AkSpatialAudio.h>		// Spatial Audio
//#include <AK/Plugin/AkRoomVerbFXFactory.h> //Roomverb


#ifndef AK_OPTIMIZED
#include <AK/Comm/AkCommunication.h>
#endif  AK_OPTIMIZED


#include "Module.h"
#include "AudioSystem.h"
#include "AudioSource.h"
#include "Time.h"
#include <memory>



class ModuleAudio : public Module {
public:
    ModuleAudio();
    ~ModuleAudio();

    bool Start() override;
    bool Update() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    void PlayAudio(AudioSource* source, AkUniqueID event);
    void PlayAudio(AudioSource* source, const wchar_t* eventName);

    void StopAudio(AudioSource* source, AkUniqueID event);

    void PauseAudio(AudioSource* source, AkUniqueID event);

    void ResumeAudio(AudioSource* source, AkUniqueID event);

    void SetSwitch(AudioSource* source, AkSwitchGroupID switchGroup, AkSwitchStateID switchState);

    void SetMusicVolume(float volume);

    void SetSFXVolume(float volume);

    //for drawing reverbZones on editor
    void DrawReverbZones();

    //for switching bg music
    void SwitchBGM();
    float musicTimer = 0.0f;
    bool music1 = true;

    std::unique_ptr<AudioSystem> audioSystem;
};


