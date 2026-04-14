#pragma once

#include "Component.h"
#include "ModuleResources.h"  
#include "ResourceMesh.h"
#include <glm/glm.hpp>

#include "AABB.h"

class ComponentMaterial;
class AABB;
class LightManager;

class ComponentMesh : public Component {
public:

    ComponentMesh(GameObject* owner, ComponentType type = ComponentType::MESH);
    ~ComponentMesh();

    void Update() override { cachedBones = false; }

    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    virtual bool IsType(ComponentType type) override { return type == ComponentType::MESH; };
    virtual bool IsIncompatible(ComponentType type) override { return type == ComponentType::MESH || type == ComponentType::SKINNED_MESH; };

    bool LoadMeshByUID(UID uid);

    virtual void SetMesh(const Mesh& meshData);

    const Mesh& GetMesh() const;
    Mesh& GetMesh();

    bool HasMesh() const;

    void Draw();

    UID GetMeshUID() const { return meshUID; }

    bool IsUsingResourceMesh() const { return meshUID != 0; }
    bool IsUsingDirectMesh() const { return hasDirectMesh && meshUID == 0; }

    void SetPrimitiveType(const std::string& type) { primitiveType = type; }
    const std::string& GetPrimitiveType() const { return primitiveType; }

    unsigned int GetNumVertices() const {
        const Mesh& m = GetMesh();
        return static_cast<unsigned int>(m.vertices.size());
    }
    
    std::vector<Vertex> GetVertices() const {
        const Mesh& m = GetMesh();
        return m.vertices;
    }

    unsigned int GetNumIndices() const {
        const Mesh& m = GetMesh();
        return static_cast<unsigned int>(m.indices.size());
    }

    std::vector<unsigned int> GetIndices() const {
        const Mesh& m = GetMesh();
        return m.indices;
    }


    unsigned int GetNumTriangles() const {
        return GetNumIndices() / 3;
    }

    unsigned int GetNumTextures() const {
        const Mesh& m = GetMesh();
        return static_cast<unsigned int>(m.textures.size());
    }

    ComponentMaterial* GetAttachedMaterial() { return attachedMaterial; }

    const AABB& GetAABB() const;
    const AABB& GetGlobalAABB();
    void UpdateStaticAABB();
    virtual void UpdateDynamicAABB() {}

    //SKINNING
    virtual void UpdateSkinningMatrices() {}

    virtual bool HasSkinning() const { return false; }
    virtual const std::vector<glm::mat4>& GetBoneMatrices() const { static std::vector<glm::mat4> empty; return empty; }

    //DEBUG
    void SetDrawMesh(bool b) { drawMesh = b; };
    bool GetDrawMesh() { return drawMesh; }
    void SetDrawNormals(bool b) { drawNormals = b; };
    bool GetDrawNormals() { return drawNormals; }

private:
    void OnGameObjectEvent(GameObjectEvent event, Component* component);

    bool aabbDirty = false;
protected:

    UID meshUID = 0;
    void ReleaseCurrentMesh();

    Mesh directMesh;
    bool hasDirectMesh;
    std::string primitiveType;       
    
    AABB staticAABB;
    AABB dynamicAABB;
    AABB cachedGlobalAABB;

    //MATERIAL
    ComponentMaterial* attachedMaterial;

    //ANIMATION
    bool cachedBones = false;   

    LightManager* lightManager = nullptr;

    //DEBUG
    bool drawMesh = false;
    bool drawNormals = false;
};