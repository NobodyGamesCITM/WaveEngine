#include "AABB.h"
#include "ComponentMesh.h"
#include "ComponentMaterial.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceMesh.h"
#include "Transform.h"
#include "Log.h"
#include <glad/glad.h>
#include "LightManager.h"
#include "Application.h"

ComponentMesh::ComponentMesh(GameObject* owner, ComponentType type)
    : Component(owner, type), meshUID(0), hasDirectMesh(false), aabbDirty(true)
{
    attachedMaterial = (ComponentMaterial*)owner->GetComponent(ComponentType::MATERIAL);
    name = "Mesh";

    if (type == ComponentType::MESH)
        Application::GetInstance().renderer->AddMesh(this);
}

ComponentMesh::~ComponentMesh()
{
    attachedMaterial = nullptr;
    ReleaseCurrentMesh();

    if (GetType() == ComponentType::MESH)
        Application::GetInstance().renderer->RemoveMesh(this);

    if (hasDirectMesh && directMesh.VAO != 0) {
        glDeleteVertexArrays(1, &directMesh.VAO);
        glDeleteBuffers(1, &directMesh.VBO);
        glDeleteBuffers(1, &directMesh.EBO);
    }
}
void ComponentMesh::ReleaseCurrentMesh()
{
    if (meshUID != 0) {
        Application::GetInstance().resources->ReleaseResource(meshUID);
        meshUID = 0;
    }

    hasDirectMesh = false;
}

bool ComponentMesh::LoadMeshByUID(UID meshUID)
{
    if (meshUID == 0)
    {
        LOG_CONSOLE("ERROR: Invalid mesh UID (0)");
        return false;
    }

    ModuleResources* resources = Application::GetInstance().resources.get();
    if (!resources)
    {
        LOG_CONSOLE("ERROR: ModuleResources not available");
        return false;
    }

    Resource* resource = resources->RequestResource(meshUID);

    if (!resource)
    {
        LOG_CONSOLE("ERROR: Failed to load mesh resource with UID: %llu", meshUID);
        return false;
    }

    if (resource->GetType() != Resource::MESH)
    {
        LOG_CONSOLE("ERROR: Resource UID %llu is not a mesh", meshUID);
        return false;
    }

    ResourceMesh* meshResource = static_cast<ResourceMesh*>(resource);

    const Mesh& loadedMesh = meshResource->GetMesh();

    if (loadedMesh.vertices.empty() || loadedMesh.indices.empty())
    {
        LOG_CONSOLE("ERROR: Loaded mesh is empty (UID: %llu)", meshUID);
        return false;
    }

    // Assign mesh to component
    SetMesh(loadedMesh);

    // Store UID for reference
    this->meshUID = meshUID;

    return true;
}

void ComponentMesh::SetMesh(const Mesh& mesh)
{
    // Release resource system mesh if any
    ReleaseCurrentMesh();

    // Copy mesh data for direct storage
    directMesh = mesh;
    hasDirectMesh = true;

    // Upload mesh to GPU if data is available
    if (!directMesh.vertices.empty() && !directMesh.indices.empty())
    {
        // Generate OpenGL buffers
        glGenVertexArrays(1, &directMesh.VAO);
        glGenBuffers(1, &directMesh.VBO);
        glGenBuffers(1, &directMesh.EBO);

        glBindVertexArray(directMesh.VAO);

        // Upload vertex data
        glBindBuffer(GL_ARRAY_BUFFER, directMesh.VBO);
        glBufferData(GL_ARRAY_BUFFER,
            directMesh.vertices.size() * sizeof(Vertex),
            directMesh.vertices.data(),
            GL_STATIC_DRAW);

        // Upload index data
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, directMesh.EBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER,
            directMesh.indices.size() * sizeof(unsigned int),
            directMesh.indices.data(),
            GL_STATIC_DRAW);

        // Configure vertex attributes
        // Position
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);

        // Normal
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex),
            (void*)offsetof(Vertex, normal));

        // TexCoords
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex),
            (void*)offsetof(Vertex, texCoords));

        glBindVertexArray(0);
    }

    UpdateStaticAABB();

    owner->PublishGameObjectEvent(GameObjectEvent::MESH_CHANGED, this);
}

const Mesh& ComponentMesh::GetMesh() const
{
    // Return resource mesh if loaded
    if (meshUID != 0) {
        // Retrieve resource without incrementing reference count
        const Resource* resource = Application::GetInstance().resources->GetResource(meshUID);

        if (resource && resource->IsLoadedToMemory()) {
            const ResourceMesh* meshResource = dynamic_cast<const ResourceMesh*>(resource);
            if (meshResource) {
                return meshResource->GetMesh();
            }
        }

        // Log warning if resource exists but is not loaded
        if (resource) {
            LOG_DEBUG("[ComponentMesh] WARNING: Resource UID %llu exists but not loaded in memory", meshUID);
        }
    }

    // Return direct mesh as fallback
    return directMesh;
}

Mesh& ComponentMesh::GetMesh()
{
    // Invoke const version and remove const qualifier from result
    return const_cast<Mesh&>(static_cast<const ComponentMesh*>(this)->GetMesh());
}

bool ComponentMesh::HasMesh() const
{
    // Verify resource mesh availability
    if (meshUID != 0) {
        const Resource* resource = Application::GetInstance().resources->GetResource(meshUID);

        if (resource && resource->IsLoadedToMemory()) {
            const ResourceMesh* meshResource = dynamic_cast<const ResourceMesh*>(resource);
            if (meshResource) {
                const Mesh& mesh = meshResource->GetMesh();
                return !mesh.vertices.empty() && !mesh.indices.empty();
            }
        }
    }

    // Verify direct mesh availability
    if (hasDirectMesh) {
        return !directMesh.vertices.empty() && !directMesh.indices.empty();
    }

    return false;
}

void ComponentMesh::Draw()
{
    if (!IsActive()) return;

    const Mesh* meshToDraw = nullptr;

    // Prioritize resource mesh
    if (meshUID != 0) {
        const Resource* resource = Application::GetInstance().resources->GetResource(meshUID);

        if (resource && resource->IsLoadedToMemory()) {
            const ResourceMesh* meshResource = dynamic_cast<const ResourceMesh*>(resource);
            if (meshResource) {
                meshToDraw = &meshResource->GetMesh();
            }
        }
    }

    // Use direct mesh as fallback
    if (!meshToDraw && hasDirectMesh) {
        meshToDraw = &directMesh;
    }

    if (meshToDraw && meshToDraw->VAO != 0 && !meshToDraw->indices.empty()) {
        glBindVertexArray(meshToDraw->VAO);
        glDrawElements(GL_TRIANGLES, meshToDraw->indices.size(), GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }
}

const AABB& ComponentMesh::GetGlobalAABB()
{
    if (aabbDirty)
    {
        glm::mat4 mat = owner->transform->GetGlobalMatrix();
        if (pivotLocalOffset.x != 0.0f || pivotLocalOffset.y != 0.0f || pivotLocalOffset.z != 0.0f)
            mat = mat * glm::translate(glm::mat4(1.0f), pivotLocalOffset);
        cachedGlobalAABB = staticAABB.GetGlobalAABB(mat);
        aabbDirty = false;
    }
    return cachedGlobalAABB;
}

const AABB& ComponentMesh::GetAABB() const
{
    return staticAABB;
}

void ComponentMesh::UpdateStaticAABB()
{
    staticAABB.SetNegativeInfinity();
    
    const Mesh& mesh = GetMesh();
    if (!mesh.IsValid() || mesh.vertices.empty()) return;

    for (const auto& vertex : mesh.vertices) {
        staticAABB.Enclose(vertex.position);
    }
}

void ComponentMesh::Serialize(nlohmann::json& componentObj) const
{
    // UID
    if (meshUID != 0) {
        componentObj["meshUID"] = meshUID;
    }

    // Direct mesh
    if (hasDirectMesh && !primitiveType.empty()) {
        componentObj["primitiveType"] = primitiveType;
    }

    // Pivot offset
    if (pivotLocalOffset != glm::vec3(0.0f)) {
        componentObj["pivotOffset"] = { pivotLocalOffset.x, pivotLocalOffset.y, pivotLocalOffset.z };
    }

    // Shadow casting
    componentObj["castShadows"] = castShadows;

    // Silhouette
    componentObj["silhouetteEnabled"] = silhouetteEnabled;
    componentObj["silhouetteColor"] = { silhouetteColor.r, silhouetteColor.g, silhouetteColor.b, silhouetteColor.a };
}
void ComponentMesh::Deserialize(const nlohmann::json& componentObj)
{
    // Shadow casting
    if (componentObj.contains("castShadows")) {
        castShadows = componentObj["castShadows"].get<bool>();
    }

    // Silhouette
    if (componentObj.contains("silhouetteEnabled"))
        silhouetteEnabled = componentObj["silhouetteEnabled"].get<bool>();
    if (componentObj.contains("silhouetteColor")) {
        auto& c = componentObj["silhouetteColor"];
        silhouetteColor = { c[0].get<float>(), c[1].get<float>(), c[2].get<float>(), c[3].get<float>() };
    }

    // UID
    if (componentObj.contains("meshUID")) {
        UID uid = componentObj["meshUID"].get<UID>();
        if (uid != 0) {
            LoadMeshByUID(uid);
            // pivotOffset puede venir junto con meshUID
            if (componentObj.contains("pivotOffset")) {
                auto& p = componentObj["pivotOffset"];
                pivotLocalOffset = glm::vec3(p[0].get<float>(), p[1].get<float>(), p[2].get<float>());
            }
            return;
        }
    }

    if (componentObj.contains("pivotOffset")) {
        auto& p = componentObj["pivotOffset"];
        pivotLocalOffset = glm::vec3(p[0].get<float>(), p[1].get<float>(), p[2].get<float>());
    }

    // Primitive Type
    if (componentObj.contains("primitiveType")) {
        std::string primType = componentObj["primitiveType"].get<std::string>();
        primitiveType = primType;

        Mesh recreatedMesh;
        if (primType == "Cube") {
            recreatedMesh = Primitives::CreateCube();
        }
        else if (primType == "Pyramid") {
            recreatedMesh = Primitives::CreatePyramid();
        }
        else if (primType == "Plane") {
            recreatedMesh = Primitives::CreatePlane();
        }
        else if (primType == "Sphere") {
            recreatedMesh = Primitives::CreateSphere();
        }
        else if (primType == "Cylinder") {
            recreatedMesh = Primitives::CreateCylinder();
        }

        SetMesh(recreatedMesh);
    }
}
void ComponentMesh::OnGameObjectEvent(GameObjectEvent event, Component* component)
{
    switch (event)
    {
    case GameObjectEvent::COMPONENT_ADDED:
        if (component->IsType(ComponentType::MATERIAL))
            attachedMaterial = (ComponentMaterial*)component;
        break;
    case GameObjectEvent::COMPONENT_REMOVED:
        if (component->IsType(ComponentType::MATERIAL))
            attachedMaterial = nullptr;
        break;
    case GameObjectEvent::MESH_CHANGED:
        UpdateStaticAABB();
        aabbDirty = true;
        break;
    case GameObjectEvent::TRANSFORM_CHANGED:  
        aabbDirty = true;
        if (lightManager) lightManager->MarkShadowsDirty();
        break;
    }
}

void ComponentMesh::SetCastShadows(bool b)
{
    castShadows = b;
    Application::GetInstance().renderer->GetLightManager()->MarkStaticShadowsDirty();
}