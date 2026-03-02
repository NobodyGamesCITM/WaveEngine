#pragma once
#include "Module.h"
#include <vector>
#include <PxPhysicsAPI.h>

enum class PhysicsEventType {
    ON_COLLISION_ENTER,
    ON_COLLISION_STAY,
    ON_COLLISION_EXIT,
    ON_TRIGGER_ENTER,
    ON_TRIGGER_STAY,
    ON_TRIGGER_EXIT
};

#define INFINITY_PHYSIC 3.402823466e+38f
class Collider;
class Joint;

class ModulePhysics : public Module, public physx::PxSimulationEventCallback
{
public:


    ModulePhysics(bool startEnabled = true);
    ~ModulePhysics();

    bool Start() override;
    bool FixedUpdate() override;
    bool CleanUp() override;

    void DrawDebug();
    void SetDebugAll(bool value);

    void RegisterCollider(Collider* col);
    void UnregisterCollider(Collider* col);
    void RegisterJoint(Joint* joint);
    void UnregisterJoint(Joint* joint);

    physx::PxPhysics* GetPhysics() { return gPhysics; }
    physx::PxScene* GetScene() { return gScene; } 
    physx::PxMaterial* GetDefaultMaterial() { return gMaterial; }

    //PHYSX CALLBACKS
    void onConstraintBreak(physx::PxConstraintInfo*, physx::PxU32) override {}
    void onWake(physx::PxActor**, physx::PxU32) override {}
    void onSleep(physx::PxActor**, physx::PxU32) override {}
    void onAdvance(const physx::PxRigidBody* const*, const physx::PxTransform*, const physx::PxU32) override {}
    void onContact(const physx::PxContactPairHeader& pairHeader, const physx::PxContactPair* pairs, physx::PxU32 nbPairs) override;
    void onTrigger(physx::PxTriggerPair* pairs, physx::PxU32 count) override;

private:
    
    physx::PxDefaultAllocator gAllocator;
    physx::PxDefaultErrorCallback  gErrorCallback;
    physx::PxFoundation* gFoundation = nullptr;
    physx::PxPhysics* gPhysics = nullptr;
    physx::PxDefaultCpuDispatcher* gDispatcher = nullptr;
    physx::PxScene* gScene = nullptr;
    physx::PxMaterial* gMaterial = nullptr;

    bool debugPhysics = true;
    std::vector<Collider*> registeredColliders;
    std::vector<Joint*> registeredJoints;
};