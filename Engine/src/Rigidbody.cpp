#include "Rigidbody.h"
#include "Collider.h"
#include "Joint.h"
#include "Application.h"
#include "ModulePhysics.h"
#include "Time.h"
#include "GameObject.h"
#include "Transform.h"
#include "imgui.h"


Rigidbody::Rigidbody(GameObject* owner) : Component(owner, ComponentType::RIGIDBODY)
{
    name = "Rigidbody";
    lastPose = physx::PxTransform(physx::PxIdentity);
    currentPose = physx::PxTransform(physx::PxIdentity);
    kinematicTargetPos = glm::vec3(0.0f);
    kinematicTargetRot = glm::quat(1.0f, 0.0f, 0.0f, 0.0f);
    CreateBody();
}

Rigidbody::~Rigidbody()
{
    for (Collider* col : attachedColliders) {
        if (col) {
            col->attachedRigidbody = nullptr;
        }
    }
    attachedColliders.clear();

    for (Joint* joint : connectedJoints) {
        if (joint) {

            joint->OnRigidbodyDeleted(this);
        }
    }
    connectedJoints.clear();

    if (actor) {
        actor->userData = nullptr;
        Application::GetInstance().physics->GetScene()->removeActor(*actor);
        actor->release();
        actor = nullptr;
    }
}

void Rigidbody::FixedUpdate() 
{
    if (!Application::GetInstance().time.get()->IsPaused() && actor)
    {
        lastPose = currentPose;

        if (type == Type::DYNAMIC) {
            physx::PxTransform p = actor->getGlobalPose();
            currentPose = p;
        }
        else if (type == Type::KINEMATIC && hasKinematicTarget) {
            physx::PxTransform target(
                physx::PxVec3(kinematicTargetPos.x, kinematicTargetPos.y, kinematicTargetPos.z),
                physx::PxQuat(kinematicTargetRot.x, kinematicTargetRot.y, kinematicTargetRot.z, kinematicTargetRot.w)
            );
            actor->is<physx::PxRigidDynamic>()->setKinematicTarget(target);
            currentPose = target;
            hasKinematicTarget = false;
        }
    }
}

void Rigidbody::Update() {
    
    if (!actor) return;

    if (Application::GetInstance().time.get()->IsPaused())
    {
        physx::PxTransform pose = actor->getGlobalPose();

        lastPose = pose;
        currentPose = pose;

        isSyncingFromPhysics = true;

        owner->transform->SetGlobalPosition(glm::vec3(pose.p.x, pose.p.y, pose.p.z));
        owner->transform->SetGlobalRotationQuat(glm::quat(pose.q.w, pose.q.x, pose.q.y, pose.q.z));
        isSyncingFromPhysics = false;

        return;
    }

    float alpha = Application::GetInstance().time.get()->GetFixedAlpha();

    glm::vec3 p0(lastPose.p.x, lastPose.p.y, lastPose.p.z);
    glm::vec3 p1(currentPose.p.x, currentPose.p.y, currentPose.p.z);
    glm::vec3 visualPos = glm::mix(p0, p1, alpha);

    glm::quat q0(lastPose.q.w, lastPose.q.x, lastPose.q.y, lastPose.q.z);
    glm::quat q1(currentPose.q.w, currentPose.q.x, currentPose.q.y, currentPose.q.z);
    glm::quat visualRot = glm::slerp(q0, q1, alpha);

    isSyncingFromPhysics = true;
    owner->transform->SetGlobalPosition(visualPos);
    owner->transform->SetGlobalRotationQuat(visualRot);
    isSyncingFromPhysics = false;
}


void Rigidbody::CollectColliders(GameObject* obj, std::vector<Collider*>& list) {
    
    std::vector<Component*> components = obj->GetComponentsOfType(ComponentType::COLLIDER);
    
    for (Component* component : components)
    {
        Collider* collider = (Collider*) component;
        if (collider && collider->owner->active)
        {
            if (collider->CanBeDynamic() || type == Type::STATIC)
            {
                list.push_back(collider);
            }
            else
            {
                LOG_CONSOLE("%s ignored on GameObject '%s': This collider type is only compatible with STATIC Rigidbodies.", collider->name.c_str(), owner->name.c_str());
            }
        }
    }

    for (GameObject* child : obj->GetChildren()) {

        if (child->GetComponent(ComponentType::RIGIDBODY) == nullptr) {
            CollectColliders(child, list);
        }
    }
}

void Rigidbody::CreateBody()
{
    auto* physicsModule = Application::GetInstance().physics.get();
    auto* physics = physicsModule->GetPhysics();
    auto* trans = owner->transform;

    glm::vec3 savedLinearVel(0.0f);
    glm::vec3 savedAngularVel(0.0f);
    bool needsRestoration = (actor != nullptr && type != Type::STATIC);

    if (needsRestoration) {
        physx::PxRigidDynamic* dyn = actor->is<physx::PxRigidDynamic>();
        if (dyn) {
            physx::PxVec3 lv = dyn->getLinearVelocity();
            physx::PxVec3 av = dyn->getAngularVelocity();
            savedLinearVel = glm::vec3(lv.x, lv.y, lv.z);
            savedAngularVel = glm::vec3(av.x, av.y, av.z);
        }
    }

    if (actor) {
        physicsModule->GetScene()->removeActor(*actor);
        actor->release();
        actor = nullptr;
    }

    for (Collider* col : attachedColliders) {
        if (col) col->attachedRigidbody = nullptr;
    }
    attachedColliders.clear();

    physx::PxRigidActor* tempActor = nullptr;

    glm::vec3 pos = trans->GetGlobalPosition();
    glm::quat rot = trans->GetGlobalRotationQuat();
    physx::PxTransform pxTransform(
        physx::PxVec3(pos.x, pos.y, pos.z),
        physx::PxQuat(rot.x, rot.y, rot.z, rot.w)
    );

    lastPose = pxTransform;
    currentPose = pxTransform;

    if (type == Type::STATIC) {
        tempActor = physics->createRigidStatic(pxTransform);
    }
    else {
        tempActor = physics->createRigidDynamic(pxTransform);
        if (type == Type::KINEMATIC)
            tempActor->is<physx::PxRigidDynamic>()->setRigidBodyFlag(physx::PxRigidBodyFlag::eKINEMATIC, true);
    }

    tempActor->userData = (void*)this;
    CollectListeners();
    physicsModule->GetScene()->addActor(*tempActor);

    std::vector<Collider*> colliders;
    CollectColliders(owner, colliders);

    for (Collider* col : colliders) {
        
        AttachCollider(col);
        physx::PxGeometry* geo = col->GetGeometry();

        if (!geo) continue;

        float sF, dF, rest;
        col->GetMaterialValues(sF, dF, rest);
        physx::PxMaterial* mat = physics->createMaterial(sF, dF, rest);

        physx::PxShape* shape = physx::PxRigidActorExt::createExclusiveShape(*tempActor, *geo, *mat);

        col->SetShape(shape);

        UpdateShapeLocalPose(tempActor,shape, col);

        shape->setFlag(physx::PxShapeFlag::eSIMULATION_SHAPE, !col->IsTrigger());
        shape->setFlag(physx::PxShapeFlag::eTRIGGER_SHAPE, col->IsTrigger());

        mat->release();
        delete geo;
    }

    actor = tempActor;
    SyncPropertiesToPhysics();

    if (needsRestoration) {
        physx::PxRigidDynamic* dyn = actor->is<physx::PxRigidDynamic>();
        if (dyn) {
            dyn->setLinearVelocity(physx::PxVec3(savedLinearVel.x, savedLinearVel.y, savedLinearVel.z));
            dyn->setAngularVelocity(physx::PxVec3(savedAngularVel.x, savedAngularVel.y, savedAngularVel.z));
        }
    }

    for (Joint* joint : connectedJoints)
    {
        if (joint)
        {
            joint->OnRigidbodyReset(this);
        }
    }
}

void Rigidbody::UpdateShapesGeometry() {
    
    if (!actor) return;

    std::vector<physx::PxShape*> shapes(actor->getNbShapes());
    actor->getShapes(shapes.data(), shapes.size());

    auto* physics = Application::GetInstance().physics.get()->GetPhysics();

    for (size_t i = 0; i < attachedColliders.size() && i < shapes.size(); ++i) {
        Collider* col = attachedColliders[i];
        physx::PxShape* shape = shapes[i];

        physx::PxGeometry* newGeo = col->GetGeometry();

        if (newGeo) {
            
            shape->setGeometry(*newGeo);

            shape->setFlag(physx::PxShapeFlag::eSIMULATION_SHAPE, !col->IsTrigger());
            shape->setFlag(physx::PxShapeFlag::eTRIGGER_SHAPE, col->IsTrigger());
            shape->setFlag(physx::PxShapeFlag::eSCENE_QUERY_SHAPE, true);

            float sF, dF, rest;
            col->GetMaterialValues(sF, dF, rest);
            physx::PxMaterial* newMat = physics->createMaterial(sF, dF, rest);
            shape->setMaterials(&newMat, 1);
            newMat->release();

            UpdateShapeLocalPose(actor, shape, col);

            delete newGeo;
        }
        else {
            shape->setFlag(physx::PxShapeFlag::eSIMULATION_SHAPE, false);
            shape->setFlag(physx::PxShapeFlag::eTRIGGER_SHAPE, false);
            shape->setFlag(physx::PxShapeFlag::eSCENE_QUERY_SHAPE, false);
        }
    }

    if (type == Type::DYNAMIC) {
        physx::PxRigidDynamic* dyn = actor->is<physx::PxRigidDynamic>();
        if (dyn) {
            physx::PxRigidBodyExt::updateMassAndInertia(*dyn, mass);
        }
    }
    WakeUp();
}

void Rigidbody::UpdateShapeProperties(Collider* col) {
    
    if (!actor) return;

    physx::PxShape* shape = col->GetShape();
    
    if (!shape) return;

    float sF, dF, rest;
    col->GetMaterialValues(sF, dF, rest);
    physx::PxMaterial* newMat = Application::GetInstance().physics.get()->GetPhysics()->createMaterial(sF, dF, rest);
    shape->setMaterials(&newMat, 1);
    newMat->release();

    shape->setFlag(physx::PxShapeFlag::eSIMULATION_SHAPE, !col->IsTrigger());
    shape->setFlag(physx::PxShapeFlag::eTRIGGER_SHAPE, col->IsTrigger());

    UpdateShapeLocalPose(actor, shape, col);
    WakeUp();
}

void Rigidbody::UpdateShapeLocalPose(physx::PxRigidActor* actor ,physx::PxShape* shape, Collider* col)
{
    if (!shape || !col) return;

    physx::PxTransform rbGlobalPose = actor->getGlobalPose();

    Transform* colTrans = col->owner->transform;
    glm::vec3 colGlobalPos = colTrans->GetGlobalPosition();
    glm::quat colGlobalRot = colTrans->GetGlobalRotationQuat();
    glm::vec3 colGlobalScale = colTrans->GetScale();

    glm::vec3 offset = colGlobalRot * (col->GetCenter() * colGlobalScale);
    glm::vec3 finalGlobalColPos = colGlobalPos + offset;

    physx::PxTransform colGlobalPose(
        physx::PxVec3(finalGlobalColPos.x, finalGlobalColPos.y, finalGlobalColPos.z),
        physx::PxQuat(colGlobalRot.x, colGlobalRot.y, colGlobalRot.z, colGlobalRot.w)
    );

    physx::PxTransform relativePose = rbGlobalPose.getInverse().transform(colGlobalPose);

    shape->setLocalPose(relativePose);
    WakeUp();
}

void Rigidbody::AttachCollider(Collider* collider)
{
    attachedColliders.push_back(collider);
    collider->attachedRigidbody = this;
    if (actor) {
        CreateBody();
    }
}


void Rigidbody::UnattachCollider(Collider* collider)
{
    if (!collider) return;

    auto& list = attachedColliders;
    list.erase(std::remove(list.begin(), list.end(), collider), list.end());

    collider->attachedRigidbody = nullptr;
    collider->SetShape(nullptr);

    if (!owner->IsCleaning() && actor) {
        CreateBody();
    }
}

void Rigidbody::SetType(Type newType) {
   
    if (this->type == newType) return;

    Type oldType = this->type;
    this->type = newType;

    bool needsHardReset = (oldType == Type::STATIC || newType == Type::STATIC);

    if (needsHardReset)
    {
        CreateBody();
    }
    else
    {
        physx::PxRigidDynamic* dyn = actor->is<physx::PxRigidDynamic>();
        if (dyn) {
            bool kinematicEnabled = (newType == Type::KINEMATIC);
            dyn->setRigidBodyFlag(physx::PxRigidBodyFlag::eKINEMATIC, kinematicEnabled);

            if (!kinematicEnabled) {
                WakeUp();
            }
        }
    }
}

void Rigidbody::EnableSimulation(bool enable)
{
    if (actor)
    {
        actor->setActorFlag(physx::PxActorFlag::eDISABLE_SIMULATION, !enable);
        if (enable)
        {
            if (auto* dyn = GetDynamic()) 
            {
                WakeUp();
            }
        }  
    }
}

void Rigidbody::Serialize(nlohmann::json& componentObj) const
{
    componentObj["Type"] = static_cast<int>(type);
    componentObj["Mass"] = mass;
    componentObj["LinearDamping"] = linearDamping;
    componentObj["AngularDamping"] = angularDamping;
    componentObj["UseGravity"] = useGravity;
    componentObj["UseCCD"] = useContiniusCollisionDetection;

    componentObj["FreezePos"] = { freezePosX, freezePosY, freezePosZ };
    componentObj["FreezeRot"] = { freezeRotX, freezeRotY, freezeRotZ };
}

void Rigidbody::Deserialize(const nlohmann::json& componentObj)
{
    if (componentObj.contains("Type"))
        type = static_cast<Type>(componentObj["Type"].get<int>());

    mass = componentObj.value("Mass", 1.0f);
    linearDamping = componentObj.value("LinearDamping", 0.0f);
    angularDamping = componentObj.value("AngularDamping", 0.0f);
    useGravity = componentObj.value("UseGravity", true);
    useContiniusCollisionDetection = componentObj.value("UseCCD", false);

    if (componentObj.contains("FreezePos")) {
        auto fPos = componentObj["FreezePos"];
        freezePosX = fPos[0];
        freezePosY = fPos[1];
        freezePosZ = fPos[2];
    }

    if (componentObj.contains("FreezeRot")) {
        auto fRot = componentObj["FreezeRot"];
        freezeRotX = fRot[0];
        freezeRotY = fRot[1];
        freezeRotZ = fRot[2];
    }

    CreateBody();
}

void Rigidbody::AddForce(const glm::vec3& force, ForceMode mode) {
    if (type == Type::DYNAMIC && actor) {
        
        physx::PxForceMode::Enum m = physx::PxForceMode::Enum::eFORCE;
        switch (mode)
        {
            case IMPULSE:
                m = physx::PxForceMode::Enum::eIMPULSE;
                break;
            case VELOCITY_CHANGE:
                m = physx::PxForceMode::Enum::eVELOCITY_CHANGE;
                break;
            case FORCE:
                m = physx::PxForceMode::Enum::eFORCE;
                break;
            case ACCELERATION:
                m = physx::PxForceMode::Enum::eACCELERATION;
                break;
        }

        if (auto* dyn = GetDynamic()) 
        {
            WakeUp();
            dyn->addForce(physx::PxVec3(force.x, force.y, force.z), m);
        }
    }
}

void Rigidbody::AddTorque(const glm::vec3& force, ForceMode mode) {
    if (type == Type::DYNAMIC && actor) {

        physx::PxForceMode::Enum m = physx::PxForceMode::Enum::eFORCE;
        switch (mode)
        {
        case IMPULSE:
            m = physx::PxForceMode::Enum::eIMPULSE;
            break;
        case VELOCITY_CHANGE:
            m = physx::PxForceMode::Enum::eVELOCITY_CHANGE;
            break;
        case FORCE:
            m = physx::PxForceMode::Enum::eFORCE;
            break;
        case ACCELERATION:
            m = physx::PxForceMode::Enum::eACCELERATION;
            break;
        }

        if (auto* dyn = GetDynamic()) 
        {
            WakeUp();
            dyn->addTorque(physx::PxVec3(force.x, force.y, force.z), m);
        }
    }
}

void Rigidbody::MovePosition(const glm::vec3& position) {
    if (type != Type::KINEMATIC) return;
    kinematicTargetPos = position;
    hasKinematicTarget = true;
}

void Rigidbody::MoveRotation(const glm::quat& rotation) {
    if (type != Type::KINEMATIC) return;
    kinematicTargetRot = rotation;
    hasKinematicTarget = true;
}

void Rigidbody::SetLinearVelocity(const glm::vec3& velocity) {
    
    if (auto* dyn = GetDynamic()) dyn->setLinearVelocity(physx::PxVec3(velocity.x, velocity.y, velocity.z));
}

glm::vec3 Rigidbody::GetLinearVelocity() const
{
    if (actor && type != Type::STATIC)
    {
        physx::PxRigidBody* body = actor->is<physx::PxRigidBody>();
        if (body)
        {
            physx::PxVec3 v = body->getLinearVelocity();

            return glm::vec3(v.x, v.y, v.z);
        }
    }

    return glm::vec3(0.0f, 0.0f, 0.0f);
}

void Rigidbody::WakeUp()
{
    if (type != DYNAMIC) return;

    if (auto* dyn = GetDynamic())
    {
        bool inScene = (dyn->getScene() != nullptr);
        bool simEnabled = !(dyn->getActorFlags() & physx::PxActorFlag::eDISABLE_SIMULATION);

        if (inScene && simEnabled)
        {
            dyn->wakeUp();
        }
    }
}

void Rigidbody::PutToSleep()
{
    if (type != DYNAMIC) return;

    if (auto* dyn = GetDynamic())
    {
        bool inScene = (dyn->getScene() != nullptr);
        bool simEnabled = !(dyn->getActorFlags() & physx::PxActorFlag::eDISABLE_SIMULATION);

        if (inScene && simEnabled)
        {
            dyn->putToSleep();
        }
    }
}

bool Rigidbody::IsSleeping()
{
    if (type == DYNAMIC)
    {
        if (auto* dyn = GetDynamic())
        {
            return dyn->isSleeping();
        }
    }

    return false;
}

void Rigidbody::SyncPropertiesToPhysics() {
    if (!actor) return;

    actor->setActorFlag(physx::PxActorFlag::eDISABLE_GRAVITY, !useGravity);

    physx::PxRigidDynamic* dyn = GetDynamic();
    if (dyn) {
        dyn->setMass(mass);
        dyn->setLinearDamping(linearDamping);
        dyn->setAngularDamping(angularDamping);

        dyn->setRigidBodyFlag(physx::PxRigidBodyFlag::eENABLE_CCD, useContiniusCollisionDetection);

        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_LINEAR_X, freezePosX);
        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_LINEAR_Y, freezePosY);
        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_LINEAR_Z, freezePosZ);
        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_ANGULAR_X, freezeRotX);
        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_ANGULAR_Y, freezeRotY);
        dyn->setRigidDynamicLockFlag(physx::PxRigidDynamicLockFlag::eLOCK_ANGULAR_Z, freezeRotZ);

        WakeUp();
    }
}

void Rigidbody::SyncToTransform() {
        
    if (!actor || !owner->transform) return;

    glm::vec3 pos = owner->transform->GetGlobalPosition();
    glm::quat rot = owner->transform->GetGlobalRotationQuat();

    physx::PxTransform targetPose(
        physx::PxVec3(pos.x, pos.y, pos.z),
        physx::PxQuat(rot.x, rot.y, rot.z, rot.w)
    );

    actor->setGlobalPose(targetPose);

    lastPose = targetPose;
    currentPose = targetPose;

    if (type == Type::DYNAMIC) {
        physx::PxRigidDynamic* dyn = actor->is<physx::PxRigidDynamic>();
        if (dyn) {
            dyn->wakeUp();

            dyn->setLinearVelocity(physx::PxVec3(0.0f));
            dyn->setAngularVelocity(physx::PxVec3(0.0f));
        }
    }
}

void Rigidbody::FreezePosition(bool x, bool y, bool z)
{
    freezePosX = x;
    freezePosY = y;
    freezePosZ = z;
    SyncPropertiesToPhysics();
}

void Rigidbody::FreezeRotation(bool x, bool y, bool z)
{
    freezeRotX = x;
    freezeRotY = y;
    freezeRotZ = z;
    SyncPropertiesToPhysics();
}

void Rigidbody::SetConstraints(bool moveX, bool moveY, bool moveZ, bool rotateX, bool rotateY, bool rotateZ) 
{
    freezePosX = moveX;
    freezePosY = moveY;
    freezePosZ = moveZ;

    freezeRotX = rotateX;
    freezeRotY = rotateY;
    freezeRotZ = rotateZ;

    SyncPropertiesToPhysics();
}

void Rigidbody::GetConstraints(bool& moveX, bool& moveY, bool& moveZ, bool& rotateX, bool& rotateY, bool& rotateZ)
{
    moveX = freezePosX;
    moveY = freezePosY;
    moveZ = freezePosZ;
    rotateX = freezeRotX;
    rotateY = freezeRotY;
    rotateZ = freezeRotZ;
}

void Rigidbody::SetMass(float newMass) 
{
    mass = newMass;
    SyncPropertiesToPhysics();
}

void Rigidbody::SetLinearDamping(float damping) 
{
    linearDamping = damping;
    SyncPropertiesToPhysics();
}

void Rigidbody::SetAngularDamping(float damping) 
{
    angularDamping = damping;
    SyncPropertiesToPhysics();
}

void Rigidbody::SetUseGravity(bool use) 
{
    useGravity = use;
    SyncPropertiesToPhysics();
}

void Rigidbody::SetUseCCD(bool enable) 
{
    useContiniusCollisionDetection = enable;
    SyncPropertiesToPhysics();
}

void Rigidbody::CollectListeners()
{
    listeners.clear();

    for (Component* component : owner->GetComponents())
    {
        if (component)
        {
            PhysicsEventsListener* listener = dynamic_cast<PhysicsEventsListener*>(component);

            if (listener)
            {
                listeners.push_back(listener);
            }
        }
    }
}

void Rigidbody::RegisterJoint(Joint* joint) {
    if (joint == nullptr) return;

    auto it = std::find(connectedJoints.begin(), connectedJoints.end(), joint);
    if (it == connectedJoints.end()) {
        connectedJoints.push_back(joint);
    }
}

void Rigidbody::UnregisterJoint(Joint* joint) {
    auto it = std::find(connectedJoints.begin(), connectedJoints.end(), joint);
    if (it != connectedJoints.end()) {
        connectedJoints.erase(it);
    }
}


void Rigidbody::CastPhysicsEvent(PhysicsEventType type, Rigidbody* other)
{
    for (PhysicsEventsListener* listener : listeners)
    {
        switch (type)
        {
        case PhysicsEventType::ON_COLLISION_ENTER: listener->OnCollisionEnter(other); break;
        case PhysicsEventType::ON_COLLISION_STAY:  listener->OnCollisionStay(other);  break;
        case PhysicsEventType::ON_COLLISION_EXIT:  listener->OnCollisionExit(other);  break;

        case PhysicsEventType::ON_TRIGGER_ENTER:   listener->OnTriggerEnter(other);   break;
        case PhysicsEventType::ON_TRIGGER_STAY:    listener->OnTriggerStay(other);    break;
        case PhysicsEventType::ON_TRIGGER_EXIT:    listener->OnTriggerExit(other);    break;
        }
    }
}

void Rigidbody::OnGameObjectEvent(GameObjectEvent event, Component* component)
{
    switch (event)
    {
    case GameObjectEvent::COMPONENT_ADDED:
        if (dynamic_cast<PhysicsEventsListener*>(component))
        {
            CollectListeners();
            WakeUp();
        }
        break;
    case GameObjectEvent::COMPONENT_REMOVED:
        if (dynamic_cast<PhysicsEventsListener*>(component))
        {
            CollectListeners();
            WakeUp();
        }
        break;
    case GameObjectEvent::TRANSFORM_SCALED:
        UpdateShapesGeometry();
        break;
    case GameObjectEvent::TRANSFORM_CHANGED:
        if (!isSyncingFromPhysics) SyncToTransform();
        break;
    }
}

void Rigidbody::OnEditor()
{
#ifndef WAVE_GAME
    const char* bodyTypes[] = { "Static", "Dynamic", "Kinematic" };
    int currentType = (int)this->type;
    ImGui::Text("Body Type:");
    ImGui::PushItemWidth(-FLT_MIN);
    if (ImGui::Combo("##Type", &currentType, bodyTypes, IM_ARRAYSIZE(bodyTypes))) {

        SetType((Type)currentType);
    }
    ImGui::PopItemWidth();

    ImGui::Separator();

    if (actor && type != Type::STATIC) {
        physx::PxRigidDynamic* dynamicActor = actor->is<physx::PxRigidDynamic>();
        bool isKinematic = (type == Type::KINEMATIC);

        if (ImGui::BeginTable("RigidbodyTable", 2, ImGuiTableFlags_Resizable)) {
            ImGui::TableSetupColumn("Property", ImGuiTableColumnFlags_WidthFixed);
            ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthStretch);

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::Text("Mass");
            ImGui::TableNextColumn();
            ImGui::PushItemWidth(-FLT_MIN);
            float mass = dynamicActor->getMass();
            if (ImGui::InputFloat("##Mass", &mass)) {
                SetMass(mass);
            }
            ImGui::PopItemWidth();

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::Text("Use CCD");
            ImGui::TableNextColumn();
            bool ccd = IsUsingCCD();
            if (ImGui::Checkbox("##CCD", &ccd)) {
                SetUseCCD(ccd);
            }

            ImGui::EndTable();
            ImGui::Separator();

            if (ImGui::BeginTable("ConstraintsTable", 4)) {

                bool freezePX = false;
                bool freezePY = false;
                bool freezePZ = false;
                bool freezeRX = false;
                bool freezeRY = false;
                bool freezeRZ = false;

                bool changed = false;

                GetConstraints(freezePX, freezePY, freezePZ, freezeRX, freezeRY, freezeRZ);

                ImGui::TableSetupColumn("Label", ImGuiTableColumnFlags_WidthStretch);
                ImGui::TableSetupColumn("X", ImGuiTableColumnFlags_WidthFixed, 15.0f);
                ImGui::TableSetupColumn("Y", ImGuiTableColumnFlags_WidthFixed, 15.0f);
                ImGui::TableSetupColumn("Z", ImGuiTableColumnFlags_WidthFixed, 15.0f);

                ImGui::TableNextColumn();
                ImGui::Text("Constraints");
                ImGui::TableNextColumn();
                ImGui::Text("X");
                ImGui::TableNextColumn();
                ImGui::Text("Y");
                ImGui::TableNextColumn();
                ImGui::Text("Z");

                ImGui::TableNextRow();
                ImGui::TableNextColumn(); ImGui::Text("Position");
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FPX", &freezePX)) changed = true;
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FPY", &freezePY)) changed = true;
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FPZ", &freezePZ)) changed = true;

                ImGui::TableNextRow();
                ImGui::TableNextColumn(); ImGui::Text("Rotation");
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FRX", &freezeRX)) changed = true;
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FRY", &freezeRY)) changed = true;
                ImGui::TableNextColumn(); if (ImGui::Checkbox("##FRZ", &freezeRZ)) changed = true;

                if (changed)
                {
                    SetConstraints(freezePX, freezePY, freezePZ, freezeRX, freezeRY, freezeRZ);
                }
            }

            ImGui::Separator();

            if (!isKinematic) {

                // GRAVEDAD
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("Use Gravity");
                ImGui::TableNextColumn();
                bool useGravity = !(actor->getActorFlags() & physx::PxActorFlag::eDISABLE_GRAVITY);
                if (ImGui::Checkbox("##Gravity", &useGravity)) {
                    SetUseGravity(useGravity);
                }

                // LINEAR DRAG
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("Linear Damping");
                ImGui::TableNextColumn();
                ImGui::PushItemWidth(-FLT_MIN);
                float linDrag = dynamicActor->getLinearDamping();
                if (ImGui::InputFloat("##Linear Damping", &linDrag)) {
                    SetLinearDamping(linDrag);
                }
                ImGui::PopItemWidth();

                // ANGULAR DRAG
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("Angular Damping");
                ImGui::TableNextColumn();
                ImGui::PushItemWidth(-FLT_MIN);
                float angDrag = dynamicActor->getAngularDamping();
                if (ImGui::InputFloat("##Angular Damping", &angDrag)) {
                    SetAngularDamping(angDrag);
                }
                ImGui::PopItemWidth();
            }

            ImGui::EndTable();
            ImGui::Separator();
        }
        physx::PxVec3 vel = dynamicActor->getLinearVelocity();
        ImGui::Text("Velocity:");
        ImGui::Text("X:%.2f | Y:%.2f | Z:%.2f", vel.x, vel.y, vel.z);
    }
#endif
}