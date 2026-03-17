#pragma once

#include "Component.h"
#include "AudioComponent.h"
#include <string>

class AudioSource : public Component, public AudioComponent {
public:
    AudioSource(GameObject* container);
    virtual ~AudioSource();

    //override from AudioComponent
    void SetTransform() override;

    //void SetVolume(); 

    ComponentType GetType() const override { return ComponentType::AUDIOSOURCE; }
    bool IsType(ComponentType type) override { return type == ComponentType::AUDIOSOURCE; };
    bool IsIncompatible(ComponentType type) override { return false; };

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    void OnEditor() override;

public:
    std::string eventName = "";
    bool playOnAwake = false;
    bool hasAwoken = false;
    float volume = 100.0f;
    float radius = 100.0f;
};