#include "ModulePhysics.h"
#include "glm/glm.hpp"
#include "Application.h"
#include "Renderer.h"
#include "Rigidbody.h"
#include "Collider.h"
#include "Joint.h"

using namespace physx;

PxFilterFlags CustomFilterShader(
    PxFilterObjectAttributes attributes0, PxFilterData filterData0,
    PxFilterObjectAttributes attributes1, PxFilterData filterData1,
    PxPairFlags& pairFlags, const void* constantBlock, PxU32 constantBlockSize)
{
    if (PxFilterObjectIsTrigger(attributes0) || PxFilterObjectIsTrigger(attributes1))
    {
        pairFlags = PxPairFlag::eTRIGGER_DEFAULT | PxPairFlag::eNOTIFY_TOUCH_PERSISTS;
        return PxFilterFlag::eDEFAULT;
    }

    pairFlags = PxPairFlag::eCONTACT_DEFAULT;
    pairFlags |= PxPairFlag::eDETECT_CCD_CONTACT;

    pairFlags |= PxPairFlag::eNOTIFY_TOUCH_FOUND;
    pairFlags |= PxPairFlag::eNOTIFY_TOUCH_PERSISTS;
    pairFlags |= PxPairFlag::eNOTIFY_TOUCH_LOST;

    return PxFilterFlag::eDEFAULT;
}

ModulePhysics::ModulePhysics(bool startEnabled) : Module() {
    name = "Physics";
}

ModulePhysics::~ModulePhysics() {}

bool ModulePhysics::Start() {
    
    //LOG(LogType::LOG_INFO, "Iniciando PhysX 5.5...");

    gFoundation = PxCreateFoundation(PX_PHYSICS_VERSION, gAllocator, gErrorCallback);
    if (!gFoundation) {
        //LOG(LogType::LOG_ERROR, "¡Fallo al crear PxFoundation!");
        return false;
    }

    gPhysics = PxCreatePhysics(PX_PHYSICS_VERSION, *gFoundation, PxTolerancesScale(), true);
    if (!gPhysics) {
   /*     LOG(LogType::LOG_ERROR, "¡Fallo al crear PxPhysics!");*/
        return false;
    }

    gMaterial = gPhysics->createMaterial(0.5f, 0.5f, 0.6f);

    gDispatcher = PxDefaultCpuDispatcherCreate(2);

    PxSceneDesc sceneDesc(gPhysics->getTolerancesScale());
    sceneDesc.gravity = PxVec3(0.0f, -50.0f, 0.0f);
    sceneDesc.cpuDispatcher = gDispatcher;
    sceneDesc.filterShader = CustomFilterShader;
    sceneDesc.simulationEventCallback = this;
    sceneDesc.flags |= PxSceneFlag::eENABLE_CCD;

    gScene = gPhysics->createScene(sceneDesc);

    if (!gScene) {
     /*   LOG(LogType::LOG_ERROR, "¡Fallo al crear PxScene!");*/
        return false;
    }

    return true;
}

bool ModulePhysics::FixedUpdate() {

    gScene->simulate(Application::GetInstance().time.get()->GetFixedDeltaTime());

    gScene->fetchResults(true);

    DrawDebug();
    return true;
}

bool ModulePhysics::CleanUp() {
    
    //LOG(LogType::LOG_INFO, "Cleaning PhysX...");

    if (gScene) gScene->release();
    if (gDispatcher) gDispatcher->release();
    if (gPhysics) gPhysics->release();
    if (gFoundation) gFoundation->release();

    return true;
}


void ModulePhysics::onContact(const PxContactPairHeader& pairHeader, const PxContactPair* pairs, PxU32 nbPairs)
{
    for (PxU32 i = 0; i < nbPairs; i++)
    {
        const PxContactPair& cp = pairs[i];

        if (cp.flags & (PxContactPairFlag::eREMOVED_SHAPE_0 | PxContactPairFlag::eREMOVED_SHAPE_1))
            continue;

        Rigidbody* rb0 = (Rigidbody*)pairHeader.actors[0]->userData;
        Rigidbody* rb1 = (Rigidbody*)pairHeader.actors[1]->userData;

        if (!rb0 || !rb1) continue;

        PhysicsEventType eventType;
        if (cp.events & PxPairFlag::eNOTIFY_TOUCH_FOUND)         eventType = PhysicsEventType::ON_COLLISION_ENTER;
        else if (cp.events & PxPairFlag::eNOTIFY_TOUCH_PERSISTS) eventType = PhysicsEventType::ON_COLLISION_STAY;
        else if (cp.events & PxPairFlag::eNOTIFY_TOUCH_LOST)     eventType = PhysicsEventType::ON_COLLISION_EXIT;
        else continue;
        rb0->CastPhysicsEvent(eventType, rb1);
        rb1->CastPhysicsEvent(eventType, rb0);
    }
}

void ModulePhysics::onTrigger(PxTriggerPair* pairs, PxU32 count)
{
    for (PxU32 i = 0; i < count; i++)
    {
        if (pairs[i].flags & (PxTriggerPairFlag::eREMOVED_SHAPE_TRIGGER | PxTriggerPairFlag::eREMOVED_SHAPE_OTHER))
            continue;

        Rigidbody* rbTrigger = (Rigidbody*)pairs[i].triggerActor->userData;
        Rigidbody* rbOther = (Rigidbody*)pairs[i].otherActor->userData;

        if (!rbTrigger || !rbOther) continue;

        PhysicsEventType eventType;
        if (pairs[i].status & PxPairFlag::eNOTIFY_TOUCH_FOUND)         eventType = PhysicsEventType::ON_TRIGGER_ENTER;
        else if (pairs[i].status & PxPairFlag::eNOTIFY_TOUCH_PERSISTS) eventType = PhysicsEventType::ON_TRIGGER_STAY;
        else if (pairs[i].status & PxPairFlag::eNOTIFY_TOUCH_LOST)     eventType = PhysicsEventType::ON_TRIGGER_EXIT;
        else continue;

        rbTrigger->CastPhysicsEvent(eventType, rbOther);
        rbOther->CastPhysicsEvent(eventType, rbTrigger);
    }
}

void ModulePhysics::RegisterCollider(Collider* col)
{
    if (col) registeredColliders.push_back(col);
}

void ModulePhysics::UnregisterCollider(Collider* col)
{
    auto it = std::find(registeredColliders.begin(), registeredColliders.end(), col);
    if (it != registeredColliders.end())
        registeredColliders.erase(it);
}

void ModulePhysics::DrawDebug()
{
    for (Collider* col : registeredColliders)
    {
        if (col && col->showDebug)
            col->SafeDebugDraw();
    }

    //for (Joint* joint : registeredJoints)
    //    if (joint && joint->showDebug) joint->DrawDebug();
}

void ModulePhysics::SetDebugAll(bool value)
{
    for (Collider* col : registeredColliders)
    {
        if (col) col->showDebug = value;
    }
}

void ModulePhysics::RegisterJoint(Joint* joint)
{
    if (joint) registeredJoints.push_back(joint);
}

void ModulePhysics::UnregisterJoint(Joint* joint)
{
    auto it = std::find(registeredJoints.begin(), registeredJoints.end(), joint);
    if (it != registeredJoints.end())
        registeredJoints.erase(it);
}