#include "Application.h"
#include "ModuleAudio.h"
//#include "ReverbZone.h"



ModuleAudio::ModuleAudio() : Module() {
    name = "Audio";
    audioSystem = std::make_unique<AudioSystem>();
}

ModuleAudio::~ModuleAudio() {}

bool ModuleAudio::Start() {
    return audioSystem->Awake(); // Initializes Wwise
 
}


bool ModuleAudio::Update() {
    ZoneScopedNC("Audio::Update", 0x1ABC9C);
    /*audioSystem->Update();*/


    if (Application::GetInstance().GetPlayState() == Application::PlayState::PLAYING) {

        //play on awake triggers
        for (auto* component : audioSystem->GetAudioComponents()) {
            if (component->GetType() == ComponentType::AUDIOSOURCE) {
                AudioSource* source = static_cast<AudioSource*>(component);

                //trigger if not played yet
                if (source->playOnAwake && !source->hasAwoken) {
                    std::wstring wideName(source->eventName.begin(), source->eventName.end());
                    audioSystem->PlayEvent(wideName.c_str(), source->goID);
                    source->hasAwoken = true;
                }
            }
        }

        
    }
    else if (Application::GetInstance().GetPlayState() == Application::PlayState::EDITING) {
        //reset hasAwoken
        for (auto* component : audioSystem->GetAudioComponents()) {
            if (component->GetType() == ComponentType::AUDIOSOURCE) {
                static_cast<AudioSource*>(component)->hasAwoken = false;
            }
        }
    }
    

    return true;
}



bool ModuleAudio::PostUpdate() {
    ZoneScopedNC("Audio::PostUpdate", 0x17A589);
    audioSystem->Update();
    
    return true;
}

bool ModuleAudio::CleanUp() {
    return audioSystem->CleanUp();
}

void ModuleAudio::PlayAudio(AudioSource* source, AkUniqueID event) {
    if (source != nullptr) {
        
        audioSystem->PlayEvent(event, source->goID);
    }
    else
        LOG_CONSOLE(__FILE__, __LINE__, "There is no component Audio Source to play");
}

void ModuleAudio::PlayAudio(AudioSource* source, const wchar_t* eventName) {
    if (source != nullptr)
        audioSystem->PlayEvent(eventName, source->goID);
    else
        LOG_CONSOLE(__FILE__, __LINE__, "There is no component Audio Source to play");
}


void ModuleAudio::StopAudio(AudioSource* source, AkUniqueID event) {
    if (source != nullptr)
        audioSystem->StopEvent(event, source->goID);
    else
        LOG_CONSOLE(__FILE__, __LINE__, "Audio Error: Attempted to play Event ID %u on a NULL AudioSource!", event);
}


void ModuleAudio::PauseAudio(AudioSource* source, AkUniqueID event) {
    audioSystem->PauseEvent(event, source->goID);
}


void ModuleAudio::ResumeAudio(AudioSource* source, AkUniqueID event) {
    audioSystem->ResumeEvent(event, source->goID);
}

void ModuleAudio::SetSwitch(AudioSource* source, AkSwitchGroupID switchGroup, AkSwitchStateID switchState)
{
    audioSystem->SetSwitch(switchGroup, switchState, source->goID);
}

void ModuleAudio::SetGlobalVolume(float vol) {
    audioSystem->SetGlobalVolume(vol);
}


void ModuleAudio::SetMusicVolume(float vol) {
    audioSystem->SetMusicVolume(vol);
}

void ModuleAudio::SetSFXVolume(float vol) {
    audioSystem->SetSFXVolume(vol);
}