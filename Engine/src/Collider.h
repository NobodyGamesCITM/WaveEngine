#pragma once
#include "GameObject.h"
#include "Component.h"
#include <PxPhysicsAPI.h>
#include <glm/glm.hpp>

class Rigidbody;

class Collider : public Component
{
public:
    
    enum class ColliderType
    {
        BOX_COLLIDER,
        SPHERE_COLLIDER,
        CAPSULE_COLLIDER,
        CONVEX_COLLIDER,
        MESH_COLLIDER,
        PLANE_COLLIDER,
        INFINITE_PLANE_COLLIDER
    };

    Collider(GameObject* owner);

    virtual ~Collider() override;

    virtual void Update() override {};
    void Enable() override;
    void Disable() override;

    virtual physx::PxGeometry* GetGeometry() = 0;
    virtual ColliderType GetColliderType() = 0;
    
    void GetMaterialValues(float& staticF, float& dynamicF, float& rest) const {
        staticF = staticFriction;
        dynamicF = dynamicFriction;
        rest = restitution;
    }

    virtual bool CanBeDynamic() const { return true; };
    virtual bool IsType(ComponentType type) override = 0;
    bool IsIncompatible(ComponentType type) override { return false; };

    virtual void Serialize(nlohmann::json& componentObj) const override { SerializeBase(componentObj); };
    void SerializeBase(nlohmann::json& componentObj) const;
    virtual void Deserialize(const nlohmann::json& componentObj) override { DeserializeBase(componentObj); };
    void DeserializeBase(const nlohmann::json& componentObj);

    virtual void OnEditor() override = 0;
    void OnEditorBase();
    
    void SetCenter(glm::vec3 center);
    void SetTrigger(bool trigger);
    void SetStaticFriction(float staticFriction);
    void SetDynamicFriction(float dynamicFriction);
    void SetRestitution(float restitution);

    const glm::vec3& GetCenter() { return center; }
    const bool IsTrigger() { return isTrigger; };
    const float GetStaticFriction() { return staticFriction; };
    const float GetDynamicFriction() { return dynamicFriction; };
    const float GetRestitution() { return restitution; };

    void SetShape(physx::PxShape* s) { shape = s; };
    physx::PxShape* GetShape() { return shape; };
    virtual void DebugShape() {}
    void SafeDebugDraw();

    virtual void OnGameObjectEvent(GameObjectEvent event, Component* component) override;

    Rigidbody* attachedRigidbody = nullptr;

    //void Serialize(nlohmann::json& componentObj) const override;
    //void Deserialize(const nlohmann::json& componentObj) override;
    bool showDebug = false;

protected:
    
    physx::PxShape* shape = nullptr;

    glm::vec3 center = { 0, 0, 0 };
   
    bool isTrigger = false;
    float staticFriction = 0.5f;
    float dynamicFriction = 0.5f;
    float restitution = 0.6f;
};