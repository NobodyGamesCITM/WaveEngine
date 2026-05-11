#pragma comment(lib, "ws2_32.lib")

#ifndef _UCRT_NO_CPP_LIBC_MACROS
#define _UCRT_NO_CPP_LIBC_MACROS
#endif

#include <ctime>
#include <iostream>
#include <cwchar>
#include <fstream>
#include <nlohmann/json.hpp>
#include "AudioSystem.h"
#include "AudioUtility.h"
#include "AudioComponent.h"
#include "Log.h"
#include "ReverbZone.h"
#include "Application.h"
#include "AudioListener.h"
#include "LibraryManager.h"
#include "FileSystem.h"

#include <AK/SoundEngine/Common/AkSoundEngine.h>
#include <AK/SpatialAudio/Common/AkSpatialAudio.h>

#include <AK/SoundEngine/Common/IAkStreamMgr.h>
#include <AK/SoundEngine/Common/AkStreamMgrModule.h> 
#include <AK/Tools/Common/AkPlatformFuncs.h>
#include <AK/SoundEngine/Common/AkTypes.h>
#include <Common/AkGeneratedSoundBanksResolver.h>
#include <AK/Plugin/AkRoomVerbFXFactory.h>
#include <AK/Plugin/AkTimeStretchFXFactory.h>
#include <AK/Plugin/AkMatrixReverbFXFactory.h>
#include <AK/Plugin/AkTremoloFXFactory.h>
#include <windows.h>

AudioEvent::AudioEvent() {
    playingID = 0L;
    eventID = AK_INVALID_UNIQUE_ID; //<-- new
    eventCallback = (AkCallbackFunc)AudioSystem::EventCallBack;

}

AudioSystem::AudioSystem() {
    currentListenerZone = nullptr;
}

AudioSystem::~AudioSystem() {

}

bool AudioSystem::InitEngine() {

    if (enableDebugLogs) LOG_DEBUG("# Initializing Audio Engine...");
    
    //LibraryManager::Initialize(); 

    //Wwise submodules must be initialized in the following order:
    if (!InitMemoryManager()) {
        LOG_CONSOLE("Failed to initialize Wwise's Memory Manager");
        return false;
    }

    if (!InitStreamingManager()) {
        LOG_CONSOLE("Failed to initialize Wwise's Streaming Manager");
        return false;
    }

    if (!InitSoundEngine()) {
        LOG_CONSOLE("Failed to initialize Wwise's Sound Engine");
        return false;
    }
    
    if (!InitSpatialAudio()) {
        LOG_CONSOLE("Failed to initialize Wwise's Spatial Audio");
        return false;
    }

#ifndef AK_OPTIMIZED
    if (!InitCommunication()) {
        LOG_CONSOLE("Failed to initialize Wwise's Authoring Tool Communication");
        return false;
    }
#endif // AK_OPTIMIZED

    return true;

}


bool AudioSystem::InitMemoryManager() {

    AkMemSettings memSettings;
    AK::MemoryMgr::GetDefaultSettings(memSettings);

    //Init memory manager
    if (AK::MemoryMgr::Init(&memSettings) != AK_Success)
    {
        LOG_CONSOLE("Could not create the memory manager.");
        return false;
    }

    return true;
}

bool AudioSystem::InitStreamingManager() {

    wchar_t cwd[MAX_PATH];
    _wgetcwd(cwd, MAX_PATH);
    if (enableDebugLogs) LOG_CONSOLE("Current Working Directory: %ls", cwd);
    AkStreamMgrSettings stmSettings;
    AK::StreamMgr::GetDefaultSettings(stmSettings);

    if (!AK::StreamMgr::Create(stmSettings)) return false;

    AkDeviceSettings deviceSettings;
    AK::StreamMgr::GetDefaultDeviceSettings(deviceSettings);

    // Initializing the Deferred hook
    if (g_lowLevelIO.Init(deviceSettings) != AK_Success) return false;

    std::string projectRoot = FileSystem::GetProjectRoot();
    std::wstring wProjectRoot(projectRoot.begin(), projectRoot.end());
    mainSoundBankPath = wProjectRoot + std::wstring(L"\\Audio\\GeneratedSoundBanks\\Windows\\");
    g_lowLevelIO.SetBasePath(mainSoundBankPath.c_str());

    return true;
}

bool AudioSystem::InitSoundEngine()
{
    //Sound Engine creation using default initialization parameters

    AkInitSettings initSettings;
    AkPlatformInitSettings platformInitSettings;
    AK::SoundEngine::GetDefaultInitSettings(initSettings);
    AK::SoundEngine::GetDefaultPlatformInitSettings(platformInitSettings);

    if (AK::SoundEngine::Init(&initSettings, &platformInitSettings) != AK_Success)
    {
        LOG_CONSOLE("Could not initialize the Sound Engine.");
        return false;
    }

    return true;

}

bool AudioSystem::InitSpatialAudio() {

    //Spatial Audio initalization using default initialization parameters
    AkSpatialAudioInitSettings settings; // The constructor fills AkSpatialAudioInitSettings with the recommended default settings. 
    if (AK::SpatialAudio::Init(settings) != AK_Success)
    {
        LOG_CONSOLE("Could not initialize the Spatial Audio.");
        return false;
    }


    return true;
}

bool AudioSystem::InitCommunication() {

    ////Necessary if we want to be able to connect the Wwise Authoring tool to the game and perform in-game mixing, profiling, and troubleshooting.

    #ifndef AK_OPTIMIZED
    // Initialize communications (not in release build!)

    AkCommSettings commSettings;
    AK::Comm::GetDefaultInitSettings(commSettings);
    if (AK::Comm::Init(commSettings) != AK_Success)
    {
        LOG_CONSOLE("Could not initialize communication.");
        return false;
    }
    #endif // AK_OPTIMIZED

    return true;
}

bool AudioSystem::Awake() {

	//Check engine has successfully initialized
    if (!InitEngine()) {
        LOG_CONSOLE("Failed to initialized the Audio Engine");
        return false;
    }
    else {
        LOG_CONSOLE("Successfully initialized Audio Engine");
    }

    LOG_CONSOLE("Header Version: %d", AK_WWISESDK_VERSION_MAJOR);
    LOG_CONSOLE("Build Date: %s", __DATE__);

    //create audio events
    for (size_t i = 0; i < MAX_AUDIO_EVENTS; ++i) {

        audioEvents.push_back(new AudioEvent);
    }

    //load init bank
    LoadBank(BANKNAME_INIT);

    //load project specific bank
    LoadBank(BANKNAME_MUSIC);

    //event list for the UI dropdown
    DiscoverEvents();

    SetGlobalVolume(globalVolume);
    return true;
}

bool AudioSystem::Update() { 
    if (!AK::SoundEngine::IsInitialized()) return true;


    // Process reverb zones (set aux sends on listener)
    ProcessReverbZones();
    DrawReverbZones();
    DrawSourceAttenuationRadius();

    //components push their current position to Wwise
    for (auto* component : audioComponents) {
        //if (!component->enabled) return true;
        component->SetTransform();
        
        AK::SoundEngine::RenderAudio();
    }
    

    //ProcessAudio() in the Sound Integration Walkthrough
    //processes bank requests, events, positions, RTPC, etc.
    
    return true;
}

bool AudioSystem::CleanUp() {
    //Stop all audio and unload banks first
    AK::SoundEngine::StopAll();
    AK::SoundEngine::ClearBanks(); // Always clear banks before termination
    AK::SoundEngine::RenderAudio(); // Process the stop/clear commands

    // Terminate Communication FIRST 
#ifndef AK_OPTIMIZED
    AK::Comm::Term();
#endif

    // Terminate Sound Engine
    AK::SoundEngine::Term();

    g_lowLevelIO.Term();

    // Terminate Stream Manager
    if (AK::IAkStreamMgr::Get()) {
        AK::IAkStreamMgr::Get()->Destroy();
    }

    // Terminate Memory Manager LAST
    AK::MemoryMgr::Term();

    return true;

}

void AudioSystem::PlayEvent(AkUniqueID event, AkGameObjectID goID)
{   
    for (size_t i = 0; i < MAX_AUDIO_EVENTS; i++)
    {
        if (audioEvents[i]->playingID == 0L)
        {
            AK::SoundEngine::PostEvent(event, goID, AkCallbackType::AK_EndOfEvent, audioEvents[i]->eventCallback, (void*)audioEvents[i]);

            if (enableDebugLogs) LOG_DEBUG("Playing event from %d audiogameobject", goID);
            audioEvents[i]->playingID = 1L; //1L = event slot is now taken
            audioEvents[i]->eventID = event; //<-- new: storing the eventID passed as argument into the AudioEvent struct eventID field

            return;
        }
    }
    if (enableDebugLogs) LOG_DEBUG("Maximum amount of audio events at the same time reached: %d", MAX_AUDIO_EVENTS);
}


// wrapper for string version of PlayEvent
void AudioSystem::PlayEvent(const wchar_t* eventName, AkGameObjectID goID)
{
    AkUniqueID eventID = AK::SoundEngine::GetIDFromString(eventName);

    if (eventID == AK_INVALID_UNIQUE_ID)
    {
        LOG_CONSOLE("Wwise Error: Event name '%ls' not found!", eventName);
        return;
    }

    PlayEvent(eventID, goID);
}

void AudioSystem::StopEvent(AkUniqueID event, AkGameObjectID goID) {
    AK::SoundEngine::ExecuteActionOnEvent(event, AK::SoundEngine::AkActionOnEventType::AkActionOnEventType_Stop, goID);
    if (enableDebugLogs) LOG_DEBUG("Stopping event from %d audiogameobject", goID);
}

// wrapper for string version of StopEvent
void AudioSystem::StopEvent(const wchar_t* eventName, AkGameObjectID goID)
{
    AkUniqueID eventID = AK::SoundEngine::GetIDFromString(eventName);
    if (eventID == AK_INVALID_UNIQUE_ID)
    {
        LOG_CONSOLE("Wwise Error: Event name '%ls' not found!", eventName);
        return;
    }
    StopEvent(eventID, goID);
}

bool AudioSystem::IsEventPlaying(AkUniqueID event) {
    for (size_t i = 0; i < audioEvents.size(); i++)
    {
        if (audioEvents[i]->IsEventPlaying() && audioEvents[i]->eventID == event)
            return true;
    }
    return false;
}

bool AudioSystem::IsEventPlaying(const wchar_t* eventName) {

    AkUniqueID eventID = AK::SoundEngine::GetIDFromString(eventName);
    if (eventID == AK_INVALID_UNIQUE_ID)
    {
        LOG_CONSOLE("Wwise Error: Event name '%ls' not found!", eventName);
        return false;
    }
    return IsEventPlaying(eventID);
}

void AudioSystem::PauseEvent(AkUniqueID event, AkGameObjectID goID) {
    AK::SoundEngine::ExecuteActionOnEvent(event, AK::SoundEngine::AkActionOnEventType::AkActionOnEventType_Pause, goID);
    if (enableDebugLogs) LOG_DEBUG("Pausing event from %d audiogameobject", goID);
}

void AudioSystem::ResumeEvent(AkUniqueID event, AkGameObjectID goID) {
    AK::SoundEngine::ExecuteActionOnEvent(event, AK::SoundEngine::AkActionOnEventType::AkActionOnEventType_Resume, gameObjectIDs[goID]);
    if (enableDebugLogs) LOG_DEBUG("Resuming event from %d audiogameobject", goID);
}



AudioComponent* AudioSystem::GetAudioCompByID(AkGameObjectID goID) {
    bool found = false;
    for (AudioComponent* comp : audioComponents) {
        if (goID == comp->goID) {
            found = true;
            return comp;
        }
    }
    if (!found) {
        LOG_DEBUG("Could not find the corresponding GameObject from the given ID");
    }
}

void AudioSystem::SetState(AkStateGroupID stateGroup, AkStateID state)
{
    AK::SoundEngine::SetState(stateGroup, state);
    

    if (enableDebugLogs) LOG_DEBUG("Setting wWise state through ID");
}

void AudioSystem::SetState(const char* stateGroup, const char* state)
{   
    AK::SoundEngine::SetState(stateGroup, state);

    std::string stateGroupName = stateGroup;
    std::string stateName = state;
    std::wstring wStateGroupName(stateGroupName.begin(), stateGroupName.end());
    std::wstring wStateName(stateName.begin(), stateName.end());

    AkStateID stateID = AK::SoundEngine::GetIDFromString(wStateName.c_str());
    AkStateGroupID stateGroupID = AK::SoundEngine::GetIDFromString(wStateGroupName.c_str());

    currentState = state;
    currentStateGroup = stateGroup;
    if (enableDebugLogs) LOG_DEBUG("Setting wWise state through name");
}

//get state from given stategroup (for Lua)
std::string AudioSystem::GetState(const char* stateGroup) {
    return currentState;
}

void AudioSystem::SetSwitch(AkSwitchGroupID switchGroup, AkSwitchStateID switchState, AkGameObjectID goID)
{
    AK::SoundEngine::SetSwitch(switchGroup, switchState, goID);
    if (enableDebugLogs) LOG_DEBUG("Setting wwise switch");
}

void AudioSystem::SetSwitch(const char* switchGroup, const char* switchState, AkGameObjectID goID)
{
    AK::SoundEngine::SetSwitch(switchGroup, switchState, goID);
    if (enableDebugLogs) LOG_DEBUG("Setting wwise switch");
}

void AudioSystem::SetRTPCValue(AkRtpcID rtpcID, AkRtpcValue value) {
    AK::SoundEngine::SetRTPCValue(rtpcID, value);
    if (enableDebugLogs) LOG_DEBUG("Setting RTPC value through ID");
}

void AudioSystem::SetRTPCValue(const char* name, int value) {
    AK::SoundEngine::SetRTPCValue(name, value);
    if (enableDebugLogs) LOG_DEBUG("Setting RTPC value through name");
}


void AudioSystem::SetGlobalVolume(float vol) {
    if (vol < 0.0f) vol = 0.0f;
    else if (vol > 100.0f) vol = 100.0f;

    globalVolume = vol;
    AK::SoundEngine::SetOutputVolume(AK::SoundEngine::GetOutputID(AK_INVALID_UNIQUE_ID, 0.0f), (AkReal32)(vol * 0.01f)); //because wwise maps volume 0 to 1!
}

void AudioSystem::SetMasterVolume(int vol) {
    AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::MASTER_VOLUME, (AkRtpcValue)vol);
}

void AudioSystem::SetMusicVolume(int vol) {
    musicVolume = vol;
    AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::MUSIC_VOLUME, (AkRtpcValue)vol);
}

void AudioSystem::SetSFXVolume(int vol) {
    sfxVolume = vol;
    AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::SFX_VOLUME, (AkRtpcValue)vol);
}

void AudioSystem::SetAudioSourceVolume(float vol, AkGameObjectID goID) {
    AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::AUDIOSOURCE_VOLUME, (AkRtpcValue)vol, goID);
}


// Reverb zone registration
void AudioSystem::RegisterReverbZone(ReverbZone* zone)
{
    if (!zone) return;
    if (std::find(reverbZones.begin(), reverbZones.end(), zone) == reverbZones.end())
        reverbZones.push_back(zone);
}

void AudioSystem::UnregisterReverbZone(ReverbZone* zone)
{
    if (!zone) return;
    auto it = std::find(reverbZones.begin(), reverbZones.end(), zone);
    if (it != reverbZones.end()) reverbZones.erase(it);
}



// processing reverb zones each frame
void AudioSystem::ProcessReverbZones()
{
    // Find the listener game object (first registered AudioComponent that is a listener)

    listenerID = AK_INVALID_GAME_OBJECT;
    std::shared_ptr<GameObject> listenerGO;

    for (AudioComponent* comp : audioComponents) {
        AudioListener* listener = dynamic_cast<AudioListener*>(comp);
        if (listener) {
            listenerID = listener->goID;
            listenerGO = listener->GetGameObject();
            break;
        }
    }

    //if (listenerID == AK_INVALID_GAME_OBJECT || !listenerGO) {
    //    // no listener, still process source sends (they can be independent)
    //}

    // Get listener world position (if available)
    glm::vec3 listenerPos(0.0f);
    if (listenerGO) {
        Transform* lt = static_cast<Transform*>(listenerGO->GetComponent(ComponentType::TRANSFORM));
        if (lt) listenerPos = glm::vec3(lt->GetWorldMatrixRecursive()[3]);

        if (enableDebugLogs) LOG_DEBUG("Listener Pos: %.2f, %.2f, %.2f", listenerPos.x, listenerPos.y, listenerPos.z);
    }

    

    // Determine best (highest-priority) zone that contains the listener (for debug & consistent send)
    ReverbZone* listenerBestZone = nullptr;


    int listenerBestPriority = INT_MIN;
    for (ReverbZone* zone : reverbZones) {
        if (!zone || !zone->enabled) continue;
        if (zone->ContainsPoint(listenerPos)) {
            if (enableDebugLogs) LOG_DEBUG("Checking zone with ID: '%u': Result=%d", zone->auxBusID, zone->ContainsPoint(listenerPos));

            if (zone->priority > listenerBestPriority) {
                listenerBestPriority = zone->priority;
                listenerBestZone = zone;
            }
        }
    }

    // Update debug tracking and log transitions
    if (listenerBestZone != currentListenerZone) {
        if (currentListenerZone) {
            if (enableDebugLogs) LOG_DEBUG("Listener left reverb zone with ID '%u'", currentListenerZone->auxBusID);
        }
        if (listenerBestZone) {
            if (enableDebugLogs) LOG_DEBUG("Listener entered reverb zone with ID '%u' (wet=%.2f priority=%d)", listenerBestZone->auxBusID, listenerBestZone->wetLevel, listenerBestZone->priority);
        }
        currentListenerZone = listenerBestZone;
    }

    // Apply aux send for listener: turn off all, then enable only the best zone's bus (if any)
    if (listenerID != AK_INVALID_GAME_OBJECT) {
        // First clear sends for known busses (conservative)
        for (ReverbZone* zone : reverbZones) {
            if (!zone || zone->auxBusID == AK_INVALID_AUX_ID) continue;
            /*std::wstring wideName(zone->auxBusName.begin(), zone->auxBusName.end());*/
            SetGameObjectAuxSend(listenerID, zone->auxBusID, 0.0f);
        }

        if (listenerBestZone && listenerBestZone->auxBusID != AK_INVALID_AUX_ID) {
            /*std::wstring wideName(listenerBestZone->auxBusName.begin(), listenerBestZone->auxBusName.end());*/
            SetGameObjectAuxSend(listenerID, listenerBestZone->auxBusID, listenerBestZone->wetLevel);
        }
    }

    // NEW: set aux sends per audio source (AudioComponent) so each source can be routed to zone aux bus
    // This selects the highest-priority zone that contains the source and applies that zone's wetLevel.
    for (AudioComponent* comp : audioComponents) {
        if (!comp) continue;

        if (comp->goID == GetMainListenerWwiseID()) {
            continue;
        }
        // Each AudioComponent is expected to expose its Wwise gameobject id (goID) and game object
        AkGameObjectID sourceID = comp->goID;
        std::shared_ptr<GameObject> sourceGO = comp->GetGameObject();
        if (sourceID == AK_INVALID_GAME_OBJECT || !sourceGO) {
            continue;
        }

        // Get source world position
        Transform* st = static_cast<Transform*>(sourceGO->GetComponent(ComponentType::TRANSFORM));
        if (!st) {
            // If no transform, ensure sends are off for this source
            // We need a bus name to switch off; but we don't know which bus was used previously
            // Skip clearing here (listener will still handle global reverb)
            continue;
        }
        glm::vec3 sourcePos = glm::vec3(st->GetWorldMatrixRecursive()[3]);

        // Find the best matching zone for this source (highest priority)
        ReverbZone* bestZone = nullptr;
        int bestPriority = INT_MIN;
        for (ReverbZone* zone : reverbZones) {
            if (!zone || !zone->enabled) continue;
            if (zone->ContainsPoint(sourcePos)) {
                if (enableDebugLogs) LOG_DEBUG("Checking zone from auxBusID %u: Result=%d", zone->auxBusID, zone->ContainsPoint(sourcePos));
                if (zone->priority > bestPriority) {
                    bestPriority = zone->priority;
                    bestZone = zone;
                }
            }
        }

        if (bestZone) {
            //// We found a zone! Only set the reverb for THIS specific bus.
            //std::wstring wideName(bestZone->auxBusName.begin(), bestZone->auxBusName.end());
            SetGameObjectAuxSend(sourceID, bestZone->auxBusID, bestZone->wetLevel);
        }
        else {
            // ONLY if we are in NO zone at all, then we clear the faders.
            for (ReverbZone* zone : reverbZones) {
                /*std::wstring wideName(zone->auxBusName.begin(), zone->auxBusName.end());*/
                SetGameObjectAuxSend(sourceID, zone->auxBusID, 0.0f);
            }
        }

        
    }
}

void AudioSystem::SetGameObjectAuxSend(AkGameObjectID id, AkUniqueID busId, float controlValue)
{
    // basic parameter validation
    if (id == AK_INVALID_GAME_OBJECT) {
        if (enableDebugLogs) LOG_DEBUG("SetGameObjectAuxSendByID: invalid Game Object ID.");
        return;
    }

    // handle reverb clearing if no zone is active
    if (busId == AK_INVALID_UNIQUE_ID) {
        AK::SoundEngine::SetGameObjectAuxSendValues(id, nullptr, 0);
        if (enableDebugLogs) LOG_DEBUG("SetGameObjectAuxSendByID: Clearing sends for GO %u", id);
        return;
    }

    // listener validation
    AkGameObjectID listenerID = GetMainListenerWwiseID();
    if (listenerID == AK_INVALID_UNIQUE_ID) {
        if (enableDebugLogs) LOG_DEBUG("SetGameObjectAuxSendByID: main listener ID was invalid.");
        return;
    }

    // build akauxsendvalue
    AkAuxSendValue send;
    send.auxBusID = (AkAuxBusID)busId;
    send.listenerID = listenerID;
    send.fControlValue = controlValue;



    if (controlValue > 0) {
        // apply the routing
        AK::SoundEngine::SetGameObjectAuxSendValues(id, &send, 1);
        SetRTPCValue(AK::GAME_PARAMETERS::REVERB_VOLUME, controlValue);
    }
    else {
        AK::SoundEngine::SetGameObjectAuxSendValues(id, nullptr, 0);
    }
    

    if (enableDebugLogs) {
        LOG_DEBUG("SetGameObjectAuxSendByID: Applying Bus ID %u (Vol: %.2f) to GO %u",
            (unsigned int)busId, controlValue, (unsigned int)id);
    }
}

void AudioSystem::DrawSourceAttenuationRadius() {
    for (AudioComponent* comp : audioComponents) {
        if (comp->GetType() != ComponentType::AUDIOSOURCE) return;

        AudioSource* source = static_cast<AudioSource*>(comp);

        if (!source->enabled) return;

        Transform* t = source->owner->transform;
        if (!t) return;

        glm::vec4 debugColor(0.0f, 6.0f, 4.0f, 0.5f);
        
        //transform to worldSpace
        glm::vec3 worldPos = t->GetGlobalPosition();

        glm::mat4 modelMatrix = t->GetGlobalMatrix();
        // Transform offset from local to world space 
        glm::mat4 rotOnly = glm::mat4(glm::mat3(
            glm::normalize(glm::vec3(modelMatrix[0])),
            glm::normalize(glm::vec3(modelMatrix[1])),
            glm::normalize(glm::vec3(modelMatrix[2]))
        ));
        
        glm::vec3 sphereCenter = worldPos;
        
        if (source->owner->IsSelected())
            Application::GetInstance().renderer->DrawSphere(sphereCenter, source->radius, debugColor);
    }
}

void AudioSystem::DrawReverbZones() {
    //Draw Reverb Zone on Editor

    for (ReverbZone* zone : reverbZones) {
        if (!zone->enabled) return;

        Transform* t = zone->owner->transform;
        if (!t) return;

        float alpha;

        if (zone->owner->IsSelected()) alpha = 0.8f;
        else alpha = 0.3f;

        glm::vec4 sphereDebugColor(0.0f, 6.0f, 4.0f, alpha);
        glm::vec4 boxDebugColor(0.0f, 4.0f, 6.0f, alpha);

        //transform to worldSpace
        glm::vec3 worldPos = t->GetGlobalPosition();

        glm::mat4 modelMatrix = t->GetGlobalMatrix();
        // Transform offset from local to world space 
        glm::mat4 rotOnly = glm::mat4(glm::mat3(
            glm::normalize(glm::vec3(modelMatrix[0])),
            glm::normalize(glm::vec3(modelMatrix[1])),
            glm::normalize(glm::vec3(modelMatrix[2]))
        ));
        glm::vec3 worldOffset = glm::vec3(rotOnly * glm::vec4(zone->centerOffset, 0.0f));
        glm::vec3 sphereCenter = worldPos + worldOffset;
        glm::vec3 extents = zone->extents;


        if (zone->shape == ReverbZone::Shape::SPHERE)
        {
            
            Application::GetInstance().renderer->DrawSphere(sphereCenter, zone->radius, sphereDebugColor);
        }
        else
        {
            glm::mat4 worldMat = t->GetGlobalMatrix();
            glm::vec3 zonePos = t->GetGlobalPosition();

            glm::mat4 noScaleWorldMat = glm::translate(glm::mat4(1.0f), zonePos) * rotOnly;

            glm::vec3 v[8];
            v[0] = glm::vec3(-extents.x, -extents.y, -extents.z);
            v[1] = glm::vec3(extents.x, -extents.y, -extents.z);
            v[2] = glm::vec3(extents.x, extents.y, -extents.z);
            v[3] = glm::vec3(-extents.x, extents.y, -extents.z);
            v[4] = glm::vec3(-extents.x, -extents.y, extents.z);
            v[5] = glm::vec3(extents.x, -extents.y, extents.z);
            v[6] = glm::vec3(extents.x, extents.y, extents.z);
            v[7] = glm::vec3(-extents.x, extents.y, extents.z);



            for (int i = 0; i < 8; ++i) {
                v[i] = glm::vec3(noScaleWorldMat * glm::vec4(v[i], 1.0f)) + worldOffset;
            }

            auto draw = [&](int a, int b) {
                Application::GetInstance().renderer->DrawLine(v[a], v[b], boxDebugColor);
                };

            draw(0, 1); draw(1, 2); draw(2, 3); draw(3, 0);
            draw(4, 5); draw(5, 6); draw(6, 7); draw(7, 4);
            draw(0, 4); draw(1, 5); draw(2, 6); draw(3, 7);
        }
    }


}



void AudioSystem::DiscoverAuxBuses()
{
    auxBusNames.clear();

    /*std::wstring path = (std::string)mainSoundBankPath;*/
    std::ifstream file(mainSoundBankPath);
    if (!file.is_open()) {
        LOG_CONSOLE("Audio Error: Could not open MainSoundBank.json at %s", mainSoundBankPath.c_str());
        return;
    }

    try {
        nlohmann::json data;
        file >> data;

        // The generated JSON often contains lists for AuxBusses under "SoundBanksInfo" or "AuxBusses".
        // Try a few likely places.
        if (data.contains("SoundBanksInfo") && data["SoundBanksInfo"].contains("AuxBusses")) {
            for (auto& bus : data["SoundBanksInfo"]["AuxBusses"]) {
                if (bus.contains("Name")) {
                    auxBusNames.push_back(bus["Name"].get<std::string>());
                }
            }
        }
        // Older or different resolvers might have AuxBusses at top-level
        if (data.contains("AuxBusses")) {
            for (auto& bus : data["AuxBusses"]) {
                if (bus.contains("Name")) {
                    auxBusNames.push_back(bus["Name"].get<std::string>());
                }
            }
        }

        // Deduplicate & sort for neatness
        std::sort(auxBusNames.begin(), auxBusNames.end());
        auxBusNames.erase(std::unique(auxBusNames.begin(), auxBusNames.end()), auxBusNames.end());

        LOG_CONSOLE("Audio: Discovered %d aux busses from MainSoundBank.json", (int)auxBusNames.size());
        if (enableDebugLogs) {
            for (const auto& n : auxBusNames) {
                LOG_DEBUG(" - AuxBus: %s", n.c_str());
            }
        }
    }
    catch (const nlohmann::json::exception& e) {
        LOG_CONSOLE("Audio Error: Failed to parse MainSoundBank.json for aux busses: %s", e.what());
    }
}


void AudioSystem::ReloadSoundBanks() {
   
    
    AK::SoundEngine::StopAll();
    AK::SoundEngine::UnloadBank(AK::BANKS::MAINSOUNDBANK, nullptr);
    AK::SoundEngine::RenderAudio();

   
    AkBankID bankID = AK_INVALID_BANK_ID;
    AKRESULT result = AK::SoundEngine::LoadBank(BANKNAME_MUSIC, bankID);

    if (result == AK_Success) {
        LOG_CONSOLE("[Audio] MainSoundBank reloaded successfully");
        DiscoverEvents();
        DiscoverAuxBuses();
    }
    else {
        LOG_CONSOLE("[Audio] Failed to reload MainSoundBank: %d", result);
    }

    AK::SoundEngine::RenderAudio();
}

void AudioSystem::EventCallBack(AkCallbackType in_eType, AkEventCallbackInfo* in_pEventInfo, void* in_pCallbackInfo, void* in_pCookie)
{
    // in this version of Wwise, the 'cookie' is passed as the 4th parameter
    // this is the pointer to the AudioEvent passed in PostEvent
    AudioEvent* pEvent = (AudioEvent*)in_pCookie;

    if (pEvent && in_eType == AkCallbackType::AK_EndOfEvent)
    {
        pEvent->playingID = 0L; 
        pEvent->eventID = AK_INVALID_UNIQUE_ID;
    }
}


void AudioSystem::DiscoverEvents() {
    // Clear existing names to avoid duplicates
    eventNames.clear();
    eventIDs.clear();
    
    std::string soundBankDir(mainSoundBankPath.begin(), mainSoundBankPath.end());
    std::string soundBankFileName = "MainSoundBank.json";
    std::string soundBankFilePath = soundBankDir + soundBankFileName;
        
    std::ifstream file(soundBankFilePath);
    if (!file.is_open()) {
        LOG_CONSOLE("Audio Error: Could not open %s at %s", soundBankFileName, soundBankFilePath);
        return;
    }

    try {
        nlohmann::json data;
        file >> data;

        //SoundBanksInfo -> SoundBanks
        if (data.contains("SoundBanksInfo") && data["SoundBanksInfo"].contains("SoundBanks")) {
            for (auto& bank : data["SoundBanksInfo"]["SoundBanks"]) {
                // Check the "Events" array
                if (bank.contains("Events")) {
                    for (auto& event : bank["Events"]) {
                        if (event.contains("Name")) {
                            std::string name = event["Name"].get<std::string>();
                            eventNames.push_back(name);
                        }
                        /*if (event.contains("Id")) {
                            AkUniqueID eventID = event["Id"].get<uint32_t>();
                            eventIDs.push_back(eventID);
                        }*/
                    }
                }
            }
        }

        std::sort(eventNames.begin(), eventNames.end());
        
        LOG_CONSOLE("Audio: Discovered %d events from MainSoundBank.json", (int)eventNames.size());
    }
    catch (const nlohmann::json::exception& e) {
        LOG_CONSOLE("Audio Error: Failed to parse MainSoundBank.json: %s", e.what());
    }
}

void AudioSystem::StopAllAudio() {
    AK::SoundEngine::StopAll();
    AK::SoundEngine::RenderAudio();
}

void AudioSystem::LoadBank(const wchar_t * bankName)
{
    if (!bankName) {
        LOG_CONSOLE("AudioSystem::LoadBank called with null bankName");
        return;
    }

    AkBankID bankID = AK::SoundEngine::LoadBank(bankName, bankID);
  

    // Try to detect success via bankID (non-zero usually means success) and log
    if (bankID != AK_INVALID_BANK_ID) {
        LOG_CONSOLE("Loaded Bank: %ls (BankID: %u)", bankName, (unsigned int)bankID);
    } else {
        LOG_CONSOLE("Wwise Bank Error: %ls (Could not load bank or invalid bank ID)", bankName);
    }
}

//---------------AK and helpers

namespace AK
{
    void ConvertFileIdToFilename(AkOSChar* out_pszTitle, AkUInt32 in_pszTitleMaxLen, AkUInt32 in_codecId, AkFileID in_fileID)
    {
        // This handles loading by ID (e.g., 1355168291.bnk)
        swprintf(out_pszTitle, in_pszTitleMaxLen, AKTEXT("%u.bnk"), (unsigned int)in_fileID);
    }

    bool ResolveGeneratedSoundBanksPath(StringBuilder& dest, const AkOSChar* in_pszFileName, AkFileSystemFlags* in_pFlags, bool bUseSubfoldering)
    {
        //append name to the dest (which already contains the BasePath)
        if (in_pszFileName)
        {
            return dest.Append(in_pszFileName);
        }
        return true;
    }
}