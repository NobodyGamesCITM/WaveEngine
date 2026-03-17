#include "MeshRenderer.h"
#include "../GameObject.h"
#include "../Engine.h"
#include "../ModuleResources.h"
#include "../ModuleRender.h"
#include "../ModuleEvents.h"
#include "../resources/ResourceMesh.h"
#include "../resources/ResourceTexture.h"
#include "../components/Transform.h"
#include "../utils/Config.h"
#include "../utils/FileSystem.h"
#include "../utils/LOG.h"
#include "imgui.h"

MeshRenderer::MeshRenderer(GameObject* owner) : Component(owner)
{
    name = "Mesh Renderer";
    Engine::GetInstance().moduleEvents->Subscribe(Event::Type::GameObjectDestroyed, this);
    Engine::GetInstance().moduleRender->AddMesh(this);
}

MeshRenderer::~MeshRenderer()
{
    CleanUp();
}


void MeshRenderer::CleanUp()
{
    Engine::GetInstance().moduleRender->RemoveMesh(this);
    Engine::GetInstance().moduleEvents->Unsubscribe(Event::Type::GameObjectDestroyed,this);

    if (meshResource)
    {
        Engine::GetInstance().moduleResources->ReleaseResource(meshResource->GetUID());
        meshResource->RemoveReference(this);
        meshResource = nullptr;
        meshUID = 0;
    }

    if (textureResource)
    {
        Engine::GetInstance().moduleResources->ReleaseResource(textureResource->GetUID());
        textureResource->RemoveReference(this);
        textureResource = nullptr;
        textureUID = 0;
    }
}

void MeshRenderer::Save(Config& componentNode)
{
    componentNode.SetUInt("MeshUID", meshUID);
    componentNode.SetUInt("TextureUID", textureUID);
    componentNode.SetBool("DrawNormals", drawNormals);
    componentNode.SetBool("DrawMesh", drawMesh);
    componentNode.SetBool("DrawStencil", drawStencil);
    componentNode.SetBool("DrawChecker", drawChecker);
    componentNode.SetBool("Transparent", transparent);
}

void MeshRenderer::Load(Config& componentNode)
{
    UID meshUid = componentNode.GetUInt("MeshUID");
    UID textureUid = componentNode.GetUInt("TextureUID");
    drawNormals = componentNode.GetBool("DrawNormals");
    drawMesh = componentNode.GetBool("DrawMesh");
    drawStencil = componentNode.GetBool("DrawStencil");
    drawChecker = componentNode.GetBool("DrawChecker");
    transparent = componentNode.GetBool("Transparent");

    if (meshUid != 0) SetMeshResource(meshUid);
    if (textureUid != 0) SetTextureResource(textureUid);
}

void MeshRenderer::SetMeshResource(UID uid)
{
    if (meshResource != nullptr)
    {
        Engine::GetInstance().moduleResources->ReleaseResource(meshResource->GetUID());
        meshResource->RemoveReference(this);
    }

    meshUID = uid;
    Resource* res = Engine::GetInstance().moduleResources->RequestResource(uid);

    if (res != nullptr && res->GetType() == Resource::Type::mesh)
    {
        meshResource = (ResourceMesh*)res;
        meshResource->AddReference(this);
    }
    else
    {
        meshResource = nullptr;
    }

    owner->PublishGameObjectEvent(GameObjectEvent::MESH_CHANGED, this);
}

void MeshRenderer::SetTextureResource(UID uid)
{
    if (textureResource != nullptr)
    {
        Engine::GetInstance().moduleResources->ReleaseResource(textureResource->GetUID());
        textureResource->RemoveReference(this);
    }

    textureUID = uid;
    Resource* res = Engine::GetInstance().moduleResources->RequestResource(uid);

    if (res != nullptr && res->GetType() == Resource::Type::texture)
    {
        textureResource = (ResourceTexture*)res;
        textureResource->AddReference(this);
    }
    else
    {
        textureResource = nullptr;
    }
}

 AABB MeshRenderer::GetGlobalAABB()
{
    if (meshResource && owner && owner->transform)
    {
         ResourceMesh* r = GetMeshResource();
         if (r && r->IsLoadedToMemory())
         {
             glm::mat4 globalMatrix;

             if (owner->GetGlobalMatrix(globalMatrix))
             {
                 return r->localAABB.GetGlobalAABB(globalMatrix);
             }
         }
    }

    return AABB();
}


void MeshRenderer::OnEditor()
{
    OnEditorMesh();
    ImGui::Separator();
    OnEditorTexture();
}

void MeshRenderer::OnEditorMesh()
{
    if (meshResource && meshResource->IsLoadedToMemory())
    {
        ImGui::Text("Mesh:");
        ImGui::Button(meshResource->GetName(), ImVec2(ImGui::GetContentRegionAvail().x, 20));
        if (ImGui::BeginDragDropTarget())
        {
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload(RESOURCE_DRAG))
            {
                UID droppedUID = *(UID*)payload->Data;

                const Resource* res = Engine::GetInstance().moduleResources->PeekResource(droppedUID);
                if (res && res->GetType() == Resource::Type::mesh)
                {
                    SetMeshResource(droppedUID);
                }
            }
            ImGui::EndDragDropTarget();
        }
        ImGui::Text("Path:");
        ImGui::TextWrapped(meshResource->GetAssetFile());
        ImGui::Text("Vertices:");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.0f, 1.0f), "%d", meshResource->numVertices);

        ImGui::Text("Indices:");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.0f, 1.0f), "%d", meshResource->numIndices);

        ImGui::Text("VAO (ID):");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.0f, 0.7f, 0.9f, 1.0f), "%u", meshResource->meshData.VAO);

        ImGui::Text("Has UVs:");
        ImGui::SameLine();
        ImGui::TextUnformatted(meshResource->hasUVs ? "Yes" : "No");
    }
    else
    {
        ImGui::Text("Mesh:");
        ImGui::Button("Drop mesh", ImVec2(ImGui::GetContentRegionAvail().x, 20));
        if (ImGui::BeginDragDropTarget())
        {
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload(RESOURCE_DRAG))
            {
                UID droppedUID = *(UID*)payload->Data;

                const Resource* res = Engine::GetInstance().moduleResources->PeekResource(droppedUID);
                if (res && res->GetType() == Resource::Type::mesh)
                {
                    SetMeshResource(droppedUID);
                }
            }
            ImGui::EndDragDropTarget();
        }
    }
}

void MeshRenderer::OnEditorTexture()
{
    if (textureResource && textureResource->IsLoadedToMemory())
    {
        ImGui::Text("Texture:");
        ImGui::Button(textureResource->GetName(), ImVec2(ImGui::GetContentRegionAvail().x, 20));

        if (ImGui::BeginDragDropTarget())
        {
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload(ASSETS_DRAG))
            {
                const char* dataPtr = (const char*)payload->Data;
                const char* endPtr = dataPtr + payload->DataSize;

                while (dataPtr < endPtr)
                {
                    std::string path = dataPtr;
                    if (path.empty()) break;

                    if (!IsFileDirectory(path))
                    {
                        Resource::Type type = Engine::GetInstance().moduleResources->GetTypeFromExtension(path);
                        if (type == Resource::texture)
                        {
                            UID droppedUID = Engine::GetInstance().moduleResources->Find(path);
                            const Resource* res = Engine::GetInstance().moduleResources->PeekResource(droppedUID);

                            if (res && res->GetType() == Resource::Type::texture)
                            {
                                SetTextureResource(droppedUID);
                            }
                        }
                    }

                    dataPtr += path.length() + 1;
                }
            }
            ImGui::EndDragDropTarget();
        }
        ImGui::Image(textureResource->GetTextureGpuId(), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().x));

        ImGui::Text("Path:");
        ImGui::TextWrapped(textureResource->GetAssetFile());
        ImGui::Text("Size:");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.0f, 0.7f, 0.9f, 1.0f), "%dx%d", textureResource->GetWidth(), textureResource->GetHeight());
    }
    else
    {
        ImGui::Text("Texture:");
        ImGui::Button("Drop texture", ImVec2(ImGui::GetContentRegionAvail().x, 20));

        if (ImGui::BeginDragDropTarget())
        {
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload(RESOURCE_DRAG))
            {
                UID droppedUID = *(UID*)payload->Data;

                const Resource* res = Engine::GetInstance().moduleResources->PeekResource(droppedUID);
                if (res && res->GetType() == Resource::Type::texture)
                {
                    SetTextureResource(droppedUID);
                }
            }
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload(ASSETS_DRAG))
            {
                const char* dataPtr = (const char*)payload->Data;
                const char* endPtr = dataPtr + payload->DataSize;

                while (dataPtr < endPtr)
                {
                    std::string path = dataPtr;
                    if (path.empty()) break;

                    if (!IsFileDirectory(path))
                    {
                        Resource::Type type = Engine::GetInstance().moduleResources->GetTypeFromExtension(path);
                        if (type == Resource::texture)
                        {
                            UID droppedUID = Engine::GetInstance().moduleResources->Find(path);
                            const Resource* res = Engine::GetInstance().moduleResources->PeekResource(droppedUID);

                            if (res && res->GetType() == Resource::Type::texture)
                            {
                                SetTextureResource(droppedUID);
                            }
                        }
                    }

                    dataPtr += path.length() + 1;
                }
            }
            ImGui::EndDragDropTarget();
        }

        ImGui::Text("Path:");
        ImGui::TextWrapped("Default texture");
    }

    ImGui::Checkbox("Transparent", &transparent);
}

void MeshRenderer::OnResourceLost(UID lostUID)
{
    if (meshResource)
    {
        if (meshResource->GetUID() == lostUID)
        {
            LOG(LogType::LOG_INFO, "Mesh resource deleted! Removing reference in in MeshRenderer component.");
            meshResource = nullptr;
            meshUID = 0;
        }
    }
    
    if (textureResource)
    {
        if (textureResource->GetUID() == lostUID)
        {
            LOG(LogType::LOG_INFO, "Texture resource deleted! Removing reference in MeshRenderer component.");
            textureResource = nullptr;
            textureResource = 0;
        }
    }
}