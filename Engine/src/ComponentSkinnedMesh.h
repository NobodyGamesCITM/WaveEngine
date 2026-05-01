#pragma once

#include "Component.h"
#include "ComponentMesh.h"
#include "EventListener.h"
#include "ModuleLoader.h"  
#include "ModuleResources.h"  
#include "ComponentMesh.h"  
#include <glm/glm.hpp>

class ComponentSkinnedMesh : public ComponentMesh , public EventListener{
public:
    // Constructor and destructor
    ComponentSkinnedMesh(GameObject* owner);
    ~ComponentSkinnedMesh();

    virtual bool IsType(ComponentType type) override { return type == ComponentType::MESH || type == ComponentType::SKINNED_MESH; };
    virtual bool IsIncompatible(ComponentType type) override { return type == ComponentType::MESH || type == ComponentType::SKINNED_MESH; };

    void Update() override;

    void LinkBones();
    void UpdateSkinningMatrices();
    bool HasSkinning() const override { return hasSkinningData; }
    bool HasSkinningData() const { return hasSkinningData && bonesLinked; }

    void SetMesh(const Mesh& meshData) override;

    const glm::mat4& GetMeshInverse() const { return meshInverseTransform; }
    unsigned int GetSSBOGlobal() const { return ssboGlobalMatrices; }
    unsigned int GetSSBOOffset() const { return ssboOffsetMatrices; }
    int GetLinkedBonesNum() const { return boneGameObjects.size(); }

    void OnEvent(const Event& event);

    const AABB& GetGlobalAABB() override;

protected:

    UID meshUID = 0;
    void ReleaseCurrentMesh();

private:

    AABB skinnedAABB;
    
    struct BoneInfo {
        const glm::mat4* globalMatrixPtr;
        glm::mat4 offsetMatrix;
    };

    std::vector<BoneInfo> fastBones;
    std::vector<GameObject*> boneGameObjects;
    std::vector<glm::mat4> cachedBoneMatrices;
    std::vector<glm::mat4> boneGlobalMatrices;
    glm::mat4 meshInverseTransform;

    unsigned int ssboGlobalMatrices = 0;
    unsigned int ssboOffsetMatrices = 0;

    bool bonesLinked = false;
    bool hasSkinningData = false;
};