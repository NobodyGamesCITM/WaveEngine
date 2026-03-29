#include "AudioListener.h"
#include "GameObject.h"
#include "Transform.h"
#include "Application.h"
#include "AudioSystem.h"

AudioListener::AudioListener(GameObject* containerGO)
    : Component(containerGO, ComponentType::LISTENER)
{
    /*this->owner = containerGO;*/
    this->goID = (AkGameObjectID)GenerateUID(); 
    this->GO = std::shared_ptr<GameObject>(containerGO, [](GameObject*) {});
    if (this->goID == 0){
        LOG_CONSOLE("Listener gameobject ID was nullptr");
        return;
    }


    AK::SoundEngine::RegisterGameObj(this->goID, "MainListener");
    AK::SoundEngine::SetDefaultListeners(&this->goID, 1);

    Application::GetInstance().audio->audioSystem->RegisterAudioComponent(this);
}

AudioListener::~AudioListener()
{
    Application::GetInstance().audio->audioSystem->UnregisterAudioComponent(this);
    AK::SoundEngine::UnregisterGameObj(this->goID);
}

void AudioListener::SetTransform() {
    Transform* trans = static_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
    if (trans) {
        // Use the recursive version to ensure we have the absolute truth
        glm::mat4 globalMat = trans->GetWorldMatrixRecursive();

        // Extract World Position (4th Column)
        glm::vec3 worldPos = glm::vec3(globalMat[3]);

        // Extract World Orientation (Rotation only)
        glm::vec3 worldForward = glm::normalize(glm::vec3(globalMat * glm::vec4(0, 0, 1, 0)));
        glm::vec3 worldUp = glm::normalize(glm::vec3(globalMat * glm::vec4(0, 1, 0, 0)));

        AkSoundPosition listenerPos;
        listenerPos.SetPosition(worldPos.x,worldPos.y,worldPos.z);

        listenerPos.SetOrientation(
            worldForward.x, worldForward.y, worldForward.z,
            worldUp.x, worldUp.y, worldUp.z
        );

        AK::SoundEngine::SetPosition(this->goID, listenerPos);
    }
    else {
        LOG_CONSOLE("ERROR: Could not find the listener's transform component");
    }
}

void AudioListener::SetAsDefaultListener()
{
    AK::SoundEngine::SetDefaultListeners(&this->goID, 1);
}

void AudioListener::Serialize(nlohmann::json& componentObj) const {
    componentObj["isDefault"] = isDefault; 
}

void AudioListener::Deserialize(const nlohmann::json& componentObj) {
    if (componentObj.contains("isDefault")) {
        isDefault = componentObj["isDefault"].get<bool>();
        if (isDefault) {
            SetAsDefaultListener(); //set as default listener if saved like that
        }
    }
}

void AudioListener::OnEditor() {
    #ifndef WAVE_GAME
    ImGui::Text("This object is acting as the 3D ears of the scene.");

    if (ImGui::Checkbox("Is Default Listener", &isDefault)) {
        if (isDefault) {
            SetAsDefaultListener();
        }
    }

    if (ImGui::Button("Set as Default Listener (Now)")) {
        SetAsDefaultListener();
    }

    #endif 
}