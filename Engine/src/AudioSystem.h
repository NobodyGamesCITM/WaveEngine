#pragma once
#include "Module.h"
#include "AudioUtility.h"
#include <vector>
#include <algorithm>
#include <Win32/AkDefaultIOHookDeferred.h>
#include "AudioComponent.h"

class AudioComponent;
class ReverbZone;

#define MAX_AUDIO_EVENTS 30

class AudioEvent {
public:
	AudioEvent();

	bool IsEventPlaying() {
		return playingID != 0;
	};

	AkPlayingID playingID;
	AkCallbackFunc eventCallback; //callback function wwise uses to fire events
};

class AudioSystem : public Module {
public:

	AudioSystem();
	~AudioSystem();

	bool Awake();

	bool Update();

	bool CleanUp();


	void PlayEvent(AkUniqueID event, AkGameObjectID goID);

	void PlayEvent(const wchar_t* eventName, AkGameObjectID goID);
	void StopEvent(AkUniqueID event, AkGameObjectID goID);
	void PauseEvent(AkUniqueID event, AkGameObjectID goID);
	void ResumeEvent(AkUniqueID event, AkGameObjectID goID);

	// ----------------------- STATES ---------------------- //
	void SetState(AkStateGroupID stateGroup, AkStateID state);
	void SetState(const char* stateGroup, const char* state);

	// ---------------------- SWITCHES ---------------------- //
	void SetSwitch(AkSwitchGroupID switchGroup, AkSwitchStateID switchState, AkGameObjectID goID);

	// ------------------------ RTPC ------------------------ //
	void SetRTPCValue(const char* name, int value);
	void SetRTPCValue(AkRtpcID rtpcID, AkRtpcValue value);

	/* (From Wwise Docs) On playback, if no such game object-specific value has been set, 
	the sound engine will look for a global RTPC value that will have been set by calling 
	AK::SoundEngine::SetRTPCValue() with the AK_INVALID_GAME_OBJECT parameter or with no specified game object. 
	If this global value does not exist, the sound engine will use the 
	Game Parameter's default value as specified in the Wwise authoring application.
	
	Therefore these methods are for global parameters set in WWiseProject
	
	*/


	void SetGlobalVolume(float volume);
	float GetGlobalVolume() { return globalVolume; }
	
	void SetMasterVolume(int volume);
	/*void SetDialogVolume(int volume);*/
	void SetSFXVolume(int volume);
	void SetMusicVolume(int volume);

	// Register/unregister AudioComponent
	void RegisterAudioComponent(AudioComponent* component) {
		if (!component) return;
		AK::SoundEngine::RegisterGameObj(component->goID);
		audioComponents.push_back(component);
	}
	void UnregisterAudioComponent(AudioComponent* component) {
		if (!component) return;

		AK::SoundEngine::UnregisterGameObj(component->goID);

		auto it = std::find(audioComponents.begin(), audioComponents.end(), component);
		if (it != audioComponents.end()) {
			audioComponents.erase(it);
		}
	}

	std::vector<AudioEvent*> GetAudioEvents() { return audioEvents; }

	// Reverb zone registration
	void RegisterReverbZone(ReverbZone* zone);
	void UnregisterReverbZone(ReverbZone* zone);
	//void UpdateReverbPreset(AkGameObjectID sourceID, ReverbZone* bestZone);


	static void EventCallBack(AkCallbackType in_eType, AkEventCallbackInfo* in_pEventInfo, void* in_pCallbackInfo, void* in_pCookie);

	void DiscoverEvents();
	void StopAllAudio();

	// Control verbose debug logging for this subsystem (default: off)
	inline void SetDebugLogging(bool enable) { enableDebugLogs = enable; }
	inline bool IsDebugLoggingEnabled() const { return enableDebugLogs; }



private:
	bool InitEngine();
	bool InitMemoryManager();
	bool InitStreamingManager();
	bool InitSoundEngine();
	bool InitSpatialAudio();
	bool InitCommunication();

	// member function LoadBank
	void LoadBank(const wchar_t* bankName);

	// processing reverb zones each frame
	void ProcessReverbZones();
	

	// set aux send helper
	void SetGameObjectAuxSend(AkGameObjectID id, AkUniqueID busId, float controlValue);
	
	
	float globalVolume = 100.0f;

	std::vector<AkGameObjectID> gameObjectIDs;
	std::vector<AudioEvent*> audioEvents;

public:
	//low_level I/O implementation taken from the samples folder
	CAkDefaultIOHookDeferred g_lowLevelIO;

	// list of events
	std::vector<std::string> eventNames;
	

	// registered reverb zones
	std::vector<ReverbZone*> reverbZones;

	// Debug: current reverb zone containing the listener (if any)
	ReverbZone* GetCurrentListenerZone() const { return currentListenerZone; }
	bool IsListenerInReverbZone() const { return currentListenerZone != nullptr; }
	AkGameObjectID GetMainListenerWwiseID() const { return listenerID; }

	// Debug: list of auxiliary bus names discovered from the soundbank JSON
	std::vector<std::string> auxBusNames;

	// Populate auxBusNames from MainSoundBank.json (call from Awake for diagnostics)
	void DiscoverAuxBuses();

private:
    // Registered audio components (sources + listener wrappers)
    std::vector<AudioComponent*> audioComponents;

	//listener wwise object ID
	AkGameObjectID listenerID;

    // Add this member to track the current listener's reverb zone
    ReverbZone* currentListenerZone;

	// Toggle to reduce log noise (default: false)
	bool enableDebugLogs = false;




public:
    const std::vector<AudioComponent*>& GetAudioComponents() const { return audioComponents; }
};
