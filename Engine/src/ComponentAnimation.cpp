#include "ComponentAnimation.h"
#include "Transform.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleResources.h"
#include "Time.h"
#include "Log.h"
#include "imgui.h"

ComponentAnimation::ComponentAnimation(GameObject* owner) : Component(owner, ComponentType::ANIMATION)
{
    name = "Animation";
    Application::GetInstance().events->Subscribe(Event::Type::GameObjectDestroyed, this);
}

ComponentAnimation::~ComponentAnimation()
{
    UnloadAnimation(currentAnimation);
    Application::GetInstance().events->UnsubscribeAll(this);
}

void ComponentAnimation::AddAnimation(const std::string& name, UID uid)
{
    if (name.empty() || uid == 0) return;

    AnimationData data;
    data.uid = uid;
    data.loop = true;

    animationsLibrary[name] = data;
}

void ComponentAnimation::RemoveAnimation(const std::string& name)
{
    auto it = animationsLibrary.find(name);

    if (it == animationsLibrary.end()) return;

    UID uidToRemove = it->second.uid;

    if (currentAnimation.uid == uidToRemove)
    {
        Stop();
    }

    animationsLibrary.erase(it);
}

void ComponentAnimation::ResetPose()
{
    for (const auto& link : skeletonCache)
    {
        if (link.transform)
        {
            link.transform->SetPosition(link.originalPos);
            link.transform->SetRotationQuat(link.originalRot);
            link.transform->SetScale(link.originalScl);
        }
    }
}

void ComponentAnimation::Play(const std::string& name, float blendTime)
{
    auto it = animationsLibrary.find(name);
    if (it == animationsLibrary.end()) return;

    CaptureSnapshot();
    
    if (currentAnimation.uid != it->second.uid)
    {
        UnloadAnimation(currentAnimation);
        currentAnimation.name = it->first;
        currentAnimation.uid = it->second.uid;
        currentAnimation.speed = it->second.speed;
        currentAnimation.loop = it->second.loop;
        currentAnimation.resource = (ResourceAnimation*)Application::GetInstance().resources->RequestResource(currentAnimation.uid);
    }

    currentTime = 0.0f;
    ended = false;

    if (blendTime > 0.0f) {
        isBlending = true;
        currentBlendTime = 0.0f;
        blendDuration = blendTime;
    }
    else {
        isBlending = false;
    }

    playing = true;

    EnsureSkeletonMatches(currentAnimation.resource);
    UpdateChannelPointers();
}

void ComponentAnimation::Stop()
{
    playing = false;
    isBlending = false;
    currentBlendTime = 0.0f;
    
    UnloadAnimation(currentAnimation);

    ResetPose();
}

void ComponentAnimation::SetAnimationSpeed(const std::string& name, float newSpeed)
{

    auto it = animationsLibrary.find(name);
    if (it == animationsLibrary.end())
    {
        LOG_CONSOLE("Trying to set speed for non-existent animation '%s'", name.c_str());
        return;
    }

    float speed = newSpeed;

    if (speed < 0) speed = 0;

    AnimationData& data = it->second;
    data.speed = speed;


    if (currentAnimation.resource && currentAnimation.uid == data.uid)
    {
        currentAnimation.speed = speed;
    }
}

void ComponentAnimation::SetAnimationLoop(const std::string& name, bool loop)
{
    auto it = animationsLibrary.find(name);
    if (it == animationsLibrary.end()) return;

    AnimationData& data = it->second;
    data.loop = loop;

    if (currentAnimation.resource && currentAnimation.uid == data.uid)
    {
        currentAnimation.loop = loop;
    }
}

void ComponentAnimation::UnloadAnimation(AnimationInstance& animation)
{
    if (animation.resource)
    {
        Application::GetInstance().resources->ReleaseResource(currentAnimation.uid);
    }
    animation.resource = nullptr;
    animation.uid = 0;
}

void ComponentAnimation::Update()
{
    if (!playing || !currentAnimation.resource) return;

    float dt = Application::GetInstance().time->GetRealDeltaTime();

    currentTime += dt * currentAnimation.resource->GetTicksPerSecond() * currentAnimation.speed;

    if (currentTime >= currentAnimation.resource->GetDuration()) {
        if (currentAnimation.loop)
            currentTime = std::fmod(currentTime, currentAnimation.resource->GetDuration());
        else {
            currentTime = currentAnimation.resource->GetDuration();
            ended = true;
        }
    }


    if (isBlending) {
        currentBlendTime += dt;
        if (currentBlendTime >= blendDuration) {
            isBlending = false;
            snapshotPose.clear();
        }
    }

    UpdateTransformations();
}

glm::vec3 ComponentAnimation::GetPositionValue(const Channel& channel, float currentAnimTime)
{
    int frameIndex = (int)currentAnimTime;

    int numKeys = channel.positionKeys.size();

    if (frameIndex >= numKeys - 1) return channel.positionKeys.back();
    if (frameIndex < 0) return channel.positionKeys[0];

    const auto& key0 = channel.positionKeys[frameIndex];
    const auto& key1 = channel.positionKeys[frameIndex + 1];

    float factor = currentAnimTime - (float)frameIndex;

    return glm::mix(key0, key1, factor);
}

glm::quat ComponentAnimation::GetRotationValue(const Channel& channel, float currentAnimTime)
{
    int frameIndex = (int)currentAnimTime;
    int numKeys = channel.rotationKeys.size();

    if (frameIndex >= numKeys - 1) return channel.rotationKeys.back();
    if (frameIndex < 0) return channel.rotationKeys[0];

    const auto& key0 = channel.rotationKeys[frameIndex];
    const auto& key1 = channel.rotationKeys[frameIndex + 1];

    float factor = currentAnimTime - (float)frameIndex;

    return glm::slerp(key0, key1, factor);
}

glm::vec3 ComponentAnimation::GetScaleValue(const Channel& channel, float currentAnimTime)
{
    int frameIndex = (int)currentAnimTime;
    int numKeys = channel.scaleKeys.size();

    if (frameIndex >= numKeys - 1) return channel.scaleKeys.back();
    if (frameIndex < 0) return channel.scaleKeys[0];

    const auto& key0 = channel.scaleKeys[frameIndex];
    const auto& key1 = channel.scaleKeys[frameIndex + 1];

    float factor = currentAnimTime - (float)frameIndex;

    return glm::mix(key0, key1, factor);
}

void ComponentAnimation::UpdateTransformations()
{
    float factor = isBlending ? glm::clamp(currentBlendTime / blendDuration, 0.0f, 1.0f) : 1.0f;

    for (size_t i = 0; i < skeletonCache.size(); ++i) {
        auto& link = skeletonCache[i];
        if (!link.transform) continue;

        glm::vec3 targetPos = link.originalPos;
        glm::quat targetRot = link.originalRot;
        glm::vec3 targetScl = link.originalScl;

        if (link.channelA) {
            targetPos = GetPositionValue(*link.channelA, currentTime);
            targetRot = GetRotationValue(*link.channelA, currentTime);
            targetScl = GetScaleValue(*link.channelA, currentTime);
        }

        if (isBlending && i < snapshotPose.size()) {
            link.transform->SetPosition(glm::mix(snapshotPose[i].pos, targetPos, factor));
            link.transform->SetRotationQuat(glm::slerp(snapshotPose[i].rot, targetRot, factor));
            link.transform->SetScale(glm::mix(snapshotPose[i].scl, targetScl, factor));
        }
        else {
            link.transform->SetPosition(targetPos);
            link.transform->SetRotationQuat(targetRot);
            link.transform->SetScale(targetScl);
        }
    }
}

void ComponentAnimation::UpdateChannelPointers()
{
    if (!currentAnimation.resource) return;

    for (auto& link : skeletonCache)
    {
        link.channelA = FindChannel(currentAnimation.resource, link.boneName);
    }
}

void ComponentAnimation::EnsureSkeletonMatches(const ResourceAnimation* anim)
{
    if (!anim || !owner) return;

    for (const auto& channel : anim->GetChanels())
    {
        if (boneIndexMap.find(channel.name) == boneIndexMap.end())
        {
            GameObject* go = owner->FindChild(channel.name);
            if (go)
            {
                BoneLink newLink;
                newLink.boneName = channel.name;
                newLink.transform = (Transform*)go->transform;
                newLink.channelA = nullptr;
                newLink.channelB = nullptr;

                Transform* t = newLink.transform;
                newLink.originalPos = t->GetPosition();
                newLink.originalRot = t->GetRotationQuat();
                newLink.originalScl = t->GetScale();

                skeletonCache.push_back(newLink);
                boneIndexMap[channel.name] = skeletonCache.size() - 1;
            }
        }
    }
}

const Channel* ComponentAnimation::FindChannel(const ResourceAnimation* anim, const std::string& name)
{
    if (!anim) return nullptr;
    for (const auto& ch : anim->GetChanels())
    {
        if (ch.name == name) return &ch;
    }
    return nullptr;
}

void ComponentAnimation::Serialize(nlohmann::json& componentObj) const
{
    nlohmann::json animationsArray = nlohmann::json::array();

    for (const auto& [name, data] : animationsLibrary)
    {
        nlohmann::json animNode;
        animNode["name"] = name;
        animNode["UID"] = data.uid;
        animNode["loop"] = data.loop;
        animNode["speed"] = data.speed;

        animationsArray.push_back(animNode);
    }

    componentObj["Animations"] = animationsArray;
}

void ComponentAnimation::Deserialize(const nlohmann::json& componentObj)
{
    if (componentObj.contains("Animations") && componentObj["Animations"].is_array())
    {
        animationsLibrary.clear();

        for (const auto& animNode : componentObj["Animations"])
        {
            UID animationUID = animNode["UID"].get<UID>();

            if (animationUID != 0)
            {
                std::string animationName = animNode["name"].get<std::string>();

                const Resource* resource = Application::GetInstance().resources->PeekResource(animationUID);

                if (resource)
                {
                    AddAnimation(animationName, animationUID);

                    animationsLibrary[animationName].loop = animNode["loop"].get<bool>();
                    animationsLibrary[animationName].speed = animNode["speed"].get<float>();
                }
            }
        }
    }
}


void ComponentAnimation::DrawSkeleton()
{
    glm::vec4 boneColor(0.0f, 1.0f, 1.0f, 1.0f);

    for (const auto& link : skeletonCache)
    {
        if (!link.transform) continue;

        GameObject* currentParent = link.transform->GetOwner()->GetParent();

        while (currentParent != nullptr && currentParent != owner)
        {
            if (boneIndexMap.find(currentParent->GetName()) != boneIndexMap.end())
            {
                Transform* parentTrans = (Transform*)currentParent->transform;
                if (parentTrans)
                {
                    glm::vec3 start = parentTrans->GetGlobalPosition();
                    glm::vec3 end = link.transform->GetGlobalPosition();

                    Application::GetInstance().renderer->DrawLine(start, end, boneColor);
                }
                break;
            }

            currentParent = currentParent->GetParent();
        }
    }
}

void ComponentAnimation::CaptureSnapshot()
{
    snapshotPose.clear();
    for (const auto& link : skeletonCache)
    {
        if (link.transform)
        {
            BoneSnapshot snap;
            snap.pos = link.transform->GetPosition();
            snap.rot = link.transform->GetRotationQuat();
            snap.scl = link.transform->GetScale();
            snapshotPose.push_back(snap);
        }
    }
    isBlending = true;
}

void ComponentAnimation::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::GameObjectDestroyed:
    {
        if (skeletonCache.empty()) return;

        GameObject* deletedGO = event.data.gameObject.gameObject;

        for (auto& link : skeletonCache)
        {
            if (link.transform && link.transform->owner == deletedGO)
            {
                link.transform = nullptr;
            }
        }
        break;
    }

    default:
        break;
    }
}