#include "AudioSource.h"
#include "GameObject.h"
#include "Transform.h"
#include "Application.h"
#include "AudioSystem.h"
#include "Log.h"
#include <glm/gtc/matrix_access.hpp> // Required for column 

AudioSource::AudioSource(GameObject* containerGO)
    : Component(containerGO, ComponentType::AUDIOSOURCE) // This sets the base owner
{
    //this->goID = (AkGameObjectID)this;
    this->goID = (AkGameObjectID)containerGO;
    this->GO = std::shared_ptr<GameObject>(containerGO, [](GameObject*) {});

    // Check if the base owner is valid before using it
    if (owner != nullptr) {
        AK::SoundEngine::RegisterGameObj(this->goID, owner->name.c_str());
        
        Application::GetInstance().audio->audioSystem->RegisterAudioComponent(this);
    }
}

AudioSource::~AudioSource()
{
    AK::SoundEngine::StopAll(this->goID);
    Application::GetInstance().audio->audioSystem->UnregisterAudioComponent(this);
    AK::SoundEngine::UnregisterGameObj(this->goID);
}

void AudioSource::SetTransform() {

    /*float dist = 0*/
    //if (!enabled) return;
    if (owner) {
        Transform* trans = static_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
        if (trans) {
            // Use the recursive version to ensure we have the absolute truth
            glm::mat4 globalMat = trans->GetWorldMatrixRecursive();

            // Extract World Position (4th Column)
            glm::vec3 worldPos = glm::vec3(globalMat[3]);

            // Extract World Orientation (Rotation only)
            glm::vec3 worldForward = glm::normalize(glm::vec3(globalMat * glm::vec4(0, 0, 1, 0)));
            glm::vec3 worldUp = glm::normalize(glm::vec3(globalMat * glm::vec4(0, 1, 0, 0)));

            AkSoundPosition soundPos;
            soundPos.SetPosition(worldPos.x, worldPos.y, worldPos.z);

            soundPos.SetOrientation(
                worldForward.x, worldForward.y, worldForward.z,
                worldUp.x, worldUp.y, worldUp.z
            );

            //K::SoundEngine::SetRTPCValue("ObjectVolume", (AkRtpcValue)volume, goID);
            if (!enabled) {
                AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::AUDIOSOURCE_VOLUME, (AkRtpcValue)(0), goID);
            }
            else {
                AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::AUDIOSOURCE_VOLUME, (AkRtpcValue)(volume), goID);
            }
            
            AK::SoundEngine::SetPosition(this->goID, soundPos);
        }


        AK::SoundEngine::SetRTPCValue(L"Attenuation_Radius", radius, goID);
    
    }
    
    
}

void AudioSource::Serialize(nlohmann::json& componentObj) const {
    //save event name
    componentObj["eventName"] = eventName;

    //save Play on Awake 
    componentObj["playOnAwake"] = playOnAwake;

    //save volume
    componentObj["volume"] = volume;
}

void AudioSource::Deserialize(const nlohmann::json& componentObj) {
    //load event name
    if (componentObj.contains("eventName")) {
        eventName = componentObj["eventName"].get<std::string>();
    }

    //load Play on Awake
    if (componentObj.contains("playOnAwake")) {
        playOnAwake = componentObj["playOnAwake"].get<bool>();
    }

    //load volume
    if (componentObj.contains("volume")) {
        volume = componentObj["volume"].get<float>();
    }

    //reset
    hasAwoken = false;
}

void AudioSource::OnEditor() {

    #ifndef WAVE_GAME

    //get all Wwise events 
    auto& events = Application::GetInstance().audio->audioSystem->eventNames;
    auto& wwiseEvents = Application::GetInstance().audio->audioSystem->GetAudioEvents();


    if (ImGui::BeginCombo("##Wwise Event", eventName.c_str())) {
        for (int i = 0; i < events.size(); ++i) {
            const string name = events[i];
            const AudioEvent* event = wwiseEvents[i];

            bool isSelected = (eventName == name);
            if (ImGui::Selectable(name.c_str(), isSelected)) {
                if (eventName != name) {
                    bool hadPreviousEvent = !eventName.empty();

                    if (hadPreviousEvent) {
                        // Stop previous event
                        AK::SoundEngine::StopAll(goID);
                    }

                    eventName = name;

                    // Only auto-play if switching (not first selection)
                    if (hadPreviousEvent) {
                        std::wstring wideName(name.begin(), name.end());
                        AkUniqueID eventID = AK::SoundEngine::GetIDFromString(wideName.c_str());
                        if (eventID != AK_INVALID_UNIQUE_ID) {
                            Application::GetInstance().audio->PlayAudio(this, eventID);
                        }
                    }
                }
               
                
                
            }
            if (isSelected) {
                ImGui::SetItemDefaultFocus();
            }
        }
        ImGui::EndCombo();
    }

    if (ImGui::SliderFloat("Volume", &volume, 0.0f, 100.0f)){

        Application::GetInstance().audio.get()->audioSystem->SetAudioSourceVolume(volume, this->goID);
 
    }

    //if (ImGui::SliderFloat("Attenuation Radius", &radius, 0.0f, 1000.0f)) {
    //    //Application::GetInstance().audio.get()->audioSystem->SetMusicVolume(volume);
    //    AK::SoundEngine::SetRTPCValue(AK::GAME_PARAMETERS::AUDIOSOURCE_VOLUME, (AkRtpcValue)(volume), goID);
    //}

    ImGui::Checkbox("Play On Awake", &playOnAwake);

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    if (ImGui::Button("Play")) {
        std::wstring wideName(eventName.begin(), eventName.end());
        AkUniqueID eventID = AK::SoundEngine::GetIDFromString(wideName.c_str());

        if (eventID == AK_INVALID_UNIQUE_ID) {
            LOG_CONSOLE("Wwise Error: Event name '%s' not found!", eventName.c_str());
        }
        else {
            Application::GetInstance().audio->PlayAudio(this, eventID);
        }
    }

    ImGui::SameLine();

    if (ImGui::Button("Stop")) {
        std::wstring wideName(eventName.begin(), eventName.end());
        AkUniqueID eventID = AK::SoundEngine::GetIDFromString(wideName.c_str());

        if (eventID != AK_INVALID_UNIQUE_ID) {
            Application::GetInstance().audio->StopAudio(this, eventID);
        }
    }

    ImGui::Checkbox("Enabled", &enabled);

    

    #endif 
}
