#include "Application.h"
#include "ModuleAudio.h"
#include "ReverbZone.h"



ModuleAudio::ModuleAudio() : Module() {
    name = "Audio";
    audioSystem = std::make_unique<AudioSystem>();
}

ModuleAudio::~ModuleAudio() {}

bool ModuleAudio::Start() {
    return audioSystem->Awake(); // Initializes Wwise
    audioSystem->SetState(AK::STATES::BGM_STATE::GROUP, AK::STATES::BGM_STATE::STATE::COFFEESHOP);
}


bool ModuleAudio::Update() {
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
    SwitchBGM(); //Keep switching bg music

    return true;
}

void ModuleAudio::DrawReverbZones() {
    //Draw Reverb Zone on Editor

    for (ReverbZone* zone : audioSystem->reverbZones) {
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

void ModuleAudio::SwitchBGM() {
    // Accumulate time (dt is in seconds)
    musicTimer += Application::GetInstance().time.get()->GetRealDeltaTime();

    if (musicTimer >= 15.0f) //switch every 15 sec
    {
        musicTimer = 0.0f; //reset timer
        music1 = !music1; 

        if (music1)
        {
            // Make sure these strings match your Wwise Game Syncs exactly!
            AK::SoundEngine::SetState(AK::STATES::BGM_STATE::GROUP, AK::STATES::BGM_STATE::STATE::COFFEESHOP);
            //LOG_CONSOLE("WWISE: BGM_State switched to Music1");
        }
        else
        {
            AK::SoundEngine::SetState(AK::STATES::BGM_STATE::GROUP, AK::STATES::BGM_STATE::STATE::PIZZAPARLOR);
            //LOG_CONSOLE("WWISE: BGM_State switched to Music2");
        }

        // Render audio to ensure Wwise processes the state change this frame
        AK::SoundEngine::RenderAudio();
    }
}

bool ModuleAudio::PostUpdate() {
    audioSystem->Update();
    DrawReverbZones();
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

void ModuleAudio::SetMusicVolume(float vol) {
    audioSystem->SetMusicVolume(vol);
}

void ModuleAudio::SetSFXVolume(float vol) {
    audioSystem->SetSFXVolume(vol);
}