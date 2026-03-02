#pragma once
#include "Component.h"
#include "ModulePhysics.h"
#include <physx/PxPhysicsAPI.h>
#include "glm/glm.hpp"
#include <glm/gtc/quaternion.hpp>


class Rigidbody;

class Joint : public Component {
public:
    
    enum class JointBody {
        Self = 0,
        Target = 1
    };

    Joint(GameObject* owner);
    virtual ~Joint() {};

    virtual void CleanUp();
    virtual void Update();

    virtual void DrawDebug() = 0;

    void OnRigidbodyReset(Rigidbody* rb);
    void OnRigidbodyDeleted(Rigidbody* rb);

    virtual void CreateJoint() = 0;
    virtual void DestroyJoint();
    virtual void RefreshJoint();

    virtual bool IsType(ComponentType type) override = 0;
    bool IsIncompatible(ComponentType type) override {
        return false;
    };

    void SetTarget(GameObject* targetGO);
    void SetAnchorPosition(JointBody jointBodyType, const glm::vec3& position);
    void SetAnchorRotation(JointBody jointBodyType, const glm::quat& rotation);
    void SetBreakForce(float force = INFINITY_PHYSIC);
    void SetBreakTorque(float torque= INFINITY_PHYSIC);

    void SerializeBase(nlohmann::json& componentObj) const;
    void DeserializeBase(const nlohmann::json& componentObj);

    virtual void Serialize(nlohmann::json& componentObj) const override { SerializeBase(componentObj); }
    virtual void Deserialize(const nlohmann::json& componentObj) override { DeserializeBase(componentObj); }
    void SolveReferences() override;

    void OnEditorBase();
    void OnGameObjectEvent(GameObjectEvent event, Component* component) override;

    //void Serialize(nlohmann::json& componentObj) const override;
    //void Deserialize(const nlohmann::json& componentObj) override;

    bool showDebug = false;

protected:
    
    UID bUID;

    Rigidbody* bodyA = nullptr;
    Rigidbody* bodyB = nullptr;

    physx::PxJoint* pxJoint = nullptr;

    glm::vec3 localPosA;
    glm::quat localRotA;

    glm::vec3 localPosB;
    glm::quat localRotB;

    float breakForce = INFINITY_PHYSIC;
    float breakTorque = INFINITY_PHYSIC;

    void SyncFrames();
};