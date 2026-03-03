#pragma once
#include "Component.h"
#include "ResourceAnimation.h"
#include "EventListener.h"
#include <map>
#include <string>
#include <vector>
#include "glm/glm.hpp"
#include <glm/gtc/quaternion.hpp>

class GameObject;
class Transform;

struct BoneSnapshot {
    glm::vec3 pos;
    glm::quat rot;
    glm::vec3 scl;
};

struct BoneLink {
    std::string boneName;
    Transform* transform;
    const Channel* channelA;
    const Channel* channelB;

    glm::vec3 originalPos;
    glm::quat originalRot;
    glm::vec3 originalScl;
};

struct AnimationInstance {
    UID uid = 0;
    std::string name = "";
    ResourceAnimation* resource = nullptr;

    float speed = 1.0f;
    bool loop = true;
};

struct AnimationData {
    UID uid = 0;
    float speed = 1.0f;
    bool loop = true;
};

class ComponentAnimation : public Component, public EventListener
{
public:
    ComponentAnimation(GameObject* owner);
    virtual ~ComponentAnimation();

    void Update() override;

    bool IsType(ComponentType type) override { return type == ComponentType::ANIMATION; };
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::ANIMATION; };

    void AddAnimation(const std::string& name, UID uid);
    void RemoveAnimation(const std::string& name);

    void UnloadAnimation(AnimationInstance& animation);

    void Play(const std::string& name, float blendTime = 0.2f);
    void Stop();
    void ResetPose();

    const bool IsPlaying() { return playing; };
    const bool IsPlayingAnimation(std::string animationName) { return IsPlaying() && currentAnimation.name == animationName; };

    void SetAnimationSpeed(const std::string& name, float newSpeed);
    void SetAnimationLoop(const std::string& name, bool loop);

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    void OnEvent(const Event& event) override;
    //void OnResourceLost(UID resourceUID) override;

private:

    void EnsureSkeletonMatches(const ResourceAnimation* anim);
    void UpdateChannelPointers();
    const Channel* FindChannel(const ResourceAnimation* anim, const std::string& name);

    glm::vec3 GetPositionValue(const Channel& channel, float currentAnimTime);
    glm::quat GetRotationValue(const Channel& channel, float currentAnimTime);
    glm::vec3 GetScaleValue(const Channel& channel, float currentAnimTime);

    void UpdateTransformations();
    void CaptureSnapshot();
    void DrawSkeleton();

public:
    
    AnimationInstance currentAnimation;
    std::map<std::string, AnimationData> animationsLibrary;

private:

    bool addAnimation = false;

    bool playing = false;
    bool ended = false;
    bool isBlending = false;
    
    float currentTime;
    float blendDuration = 0.0f;
    float currentBlendTime = 0.0f;

    std::vector<BoneSnapshot> snapshotPose;
    std::vector<BoneLink> skeletonCache;
    std::map<std::string, int> boneIndexMap;
};