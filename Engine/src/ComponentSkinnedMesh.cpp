#include "ComponentSkinnedMesh.h"
#include "ComponentMesh.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ModuleEvents.h"
#include "ResourceMesh.h"
#include "Transform.h"
#include "Log.h"
#include <glad/glad.h>
#include "Application.h"

ComponentSkinnedMesh::ComponentSkinnedMesh(GameObject* owner) 
    : ComponentMesh(owner, ComponentType::SKINNED_MESH)
{
    name = "Skinned Mesh";
    bonesLinked = false;
    Application::GetInstance().renderer->AddSkinnedMesh(this);
    Application::GetInstance().events->Subscribe(Event::Type::GameObjectDestroyed, this);
}

ComponentSkinnedMesh::~ComponentSkinnedMesh()
{
    if (meshUID != 0) {
        Application::GetInstance().resources->ReleaseResource(meshUID);
        meshUID = 0;
    }

    if (Application::GetInstance().renderer)
        Application::GetInstance().renderer->RemoveSkinnedMesh(this);

    if (Application::GetInstance().renderer) {
        Application::GetInstance().renderer->DeleteSSBO(ssboGlobalMatrices);
        Application::GetInstance().renderer->DeleteSSBO(ssboOffsetMatrices);
    }

    Application::GetInstance().events->UnsubscribeAll(this);
}

void ComponentSkinnedMesh::SetMesh(const Mesh& meshData)
{
    ComponentMesh::SetMesh(meshData);
    bonesLinked = false;
    boneGameObjects.clear();
}

void ComponentSkinnedMesh::LinkBones() {

    bonesLinked = true;

    if (!GetMesh().IsValid() || !GetMesh().IsSkinned()) return;

    size_t numBones = GetMesh().bones.size();
    fastBones.clear();
    fastBones.resize(numBones);
    boneGlobalMatrices.resize(numBones);
    boneGameObjects.resize(numBones);

    GameObject* root = nullptr;

    if (owner->GetParent()->GetParent() != nullptr)
        root = owner->GetParent();
    else root = owner;

    std::vector<glm::mat4> offsets(numBones);

    for (size_t i = 0; i < numBones; ++i) {
        GameObject* foundBone = root->FindChild(GetMesh().bones[i].name);
        if (foundBone) {
            boneGameObjects[i] = foundBone;
            fastBones[i].globalMatrixPtr = &foundBone->transform->GetGlobalMatrix();
            fastBones[i].offsetMatrix = GetMesh().bones[i].offsetMatrix;
            offsets[i] = fastBones[i].offsetMatrix;
        }
    }

    Application::GetInstance().renderer->CreateSkinningSSBOs(ssboGlobalMatrices, ssboOffsetMatrices, offsets);
}

void ComponentSkinnedMesh::Update()
{
    if (!bonesLinked)
    {
        LinkBones();
    }
}

void ComponentSkinnedMesh::UpdateSkinningMatrices()
{
    if (!bonesLinked) return;

    meshInverseTransform = glm::inverse(owner->transform->GetGlobalMatrix());

    if (boneGlobalMatrices.size() != boneGameObjects.size())
        boneGlobalMatrices.resize(boneGameObjects.size());

    for (size_t i = 0; i < boneGameObjects.size(); ++i)
    {
        if (boneGameObjects[i])
            boneGlobalMatrices[i] = boneGameObjects[i]->transform->GetGlobalMatrix();
        else
            boneGlobalMatrices[i] = glm::mat4(1.0f);
    }

    Application::GetInstance().renderer->UploadGlobalMatricesToGPU(ssboGlobalMatrices, boneGlobalMatrices);

    hasSkinningData = true;
}

void ComponentSkinnedMesh::ReleaseCurrentMesh()
{
    ComponentMesh::ReleaseCurrentMesh();
    bonesLinked = false;
    boneGameObjects.clear();
}

void ComponentSkinnedMesh::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::GameObjectDestroyed:
    {
        if (boneGameObjects.empty()) return;

        GameObject* deletedGO = event.data.gameObject.gameObject;

        for (size_t i = 0; i < boneGameObjects.size(); ++i)
        {
            if (boneGameObjects[i] == deletedGO)
            {
                boneGameObjects[i] = nullptr;
            }
        }

        break;
    }

    default:
        break;
    }
}

//const AABB& ComponentSkinnedMesh::GetGlobalAABB()
//{
//    if (!bonesLinked || boneGameObjects.empty())
//        return ComponentMesh::GetGlobalAABB();
//
//    skinnedAABB.SetNegativeInfinity();
//
//    for (GameObject* bone : boneGameObjects)
//    {
//        if (!bone) continue;
//        skinnedAABB.Enclose(bone->transform->GetGlobalPosition());
//    }
//
//    skinnedAABB.min -= glm::vec3(0.5f);
//    skinnedAABB.max += glm::vec3(0.5f);
//
//    cachedGlobalAABB = skinnedAABB;
//    return cachedGlobalAABB;
//}