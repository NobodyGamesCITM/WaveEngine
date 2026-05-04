#include "ComponentSkybox.h"
#include "GameObject.h"
#include "ResourceTexture.h"
#include "AssetsWindow.h"
#include "Application.h"
#include "Renderer.h"
#include "ModuleResources.h"
#include <glad/glad.h>


ComponentSkybox::ComponentSkybox(GameObject* owner) : Component(owner, ComponentType::SKYBOX)
{
    SetupCubeMesh();
    Application::GetInstance().renderer.get()->SetActiveSkybox(this);
}

ComponentSkybox::~ComponentSkybox()
{
    CleanUp();
}


void ComponentSkybox::SetFaceTexture(SkyboxFace face, UID textureUID)
{
    int index = (int)face;

    if (facesResourcesUID[index] != 0)
    {
        Application::GetInstance().resources.get()->ReleaseResource(facesResourcesUID[index]);
        faces[index] = nullptr;
        facesResourcesUID[index] = 0;
    }

    ResourceTexture* texture = (ResourceTexture*)Application::GetInstance().resources.get()->RequestResource(textureUID);

    if (texture)
    {
        faces[index] = texture;
        facesResourcesUID[index] = textureUID;

        bool allFacesLoaded = true;
        for (int i = 0; i < 6; i++) {
            if (faces[i] == nullptr || faces[i]->GetGPU_ID() == 0) {
                allFacesLoaded = false;
                break;
            }
        }

        if (allFacesLoaded) {
            BuildCubemapFromResources();
        }
    }
}

ResourceTexture* ComponentSkybox::GetFaceTexture(SkyboxFace face) const
{
    return faces[(int)face];
}

void ComponentSkybox::BuildCubemapFromResources()
{
    if (cubemapID != 0) glDeleteTextures(1, &cubemapID);

    glGenTextures(1, &cubemapID);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);

    int width = faces[0]->GetWidth();
    int height = faces[0]->GetHeight();

    for (unsigned int i = 0; i < 6; i++) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    }

    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    GLuint tempFBO;
    glGenFramebuffers(1, &tempFBO);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, tempFBO);

    for (unsigned int i = 0; i < 6; i++)
    {
        glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, faces[i]->GetGPU_ID(), 0);

        glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);
        glCopyTexSubImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, 0, 0, 0, 0, width, height);
    }

    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &tempFBO);
}

void ComponentSkybox::SetupCubeMesh()
{
    float skyboxVertices[] = {
        // positions          
        -1.0f,  1.0f, -1.0f, -1.0f, -1.0f, -1.0f,  1.0f, -1.0f, -1.0f,
         1.0f, -1.0f, -1.0f,  1.0f,  1.0f, -1.0f, -1.0f,  1.0f, -1.0f,
        -1.0f, -1.0f,  1.0f, -1.0f, -1.0f, -1.0f, -1.0f,  1.0f, -1.0f,
        -1.0f,  1.0f, -1.0f, -1.0f,  1.0f,  1.0f, -1.0f, -1.0f,  1.0f,
         1.0f, -1.0f, -1.0f,  1.0f, -1.0f,  1.0f,  1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,  1.0f,  1.0f, -1.0f,  1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f,  1.0f, -1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,  1.0f, -1.0f,  1.0f, -1.0f, -1.0f,  1.0f,
        -1.0f,  1.0f, -1.0f,  1.0f,  1.0f, -1.0f,  1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f, -1.0f,  1.0f,  1.0f, -1.0f,  1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f, -1.0f, -1.0f,  1.0f,  1.0f, -1.0f, -1.0f,
         1.0f, -1.0f, -1.0f, -1.0f, -1.0f,  1.0f,  1.0f, -1.0f,  1.0f
    };

    glGenVertexArrays(1, &skyboxVAO);
    glGenBuffers(1, &skyboxVBO);

    glBindVertexArray(skyboxVAO);
    glBindBuffer(GL_ARRAY_BUFFER, skyboxVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(skyboxVertices), &skyboxVertices, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);

    glBindVertexArray(0);
}

void ComponentSkybox::CleanUp()
{
    if (Application::GetInstance().renderer.get()->IsSkyboxActive(this)) Application::GetInstance().renderer.get()->SetActiveSkybox(nullptr);

    if (skyboxVAO != 0) glDeleteVertexArrays(1, &skyboxVAO);
    if (skyboxVBO != 0) glDeleteBuffers(1, &skyboxVBO);
    if (cubemapID != 0) glDeleteTextures(1, &cubemapID);

    for (unsigned int i = 0; i < 6; i++) {
        
        if (facesResourcesUID[i] != 0)
        {
            Application::GetInstance().resources.get()->ReleaseResource(facesResourcesUID[i]);
            faces[i] = nullptr;
            facesResourcesUID[i] = 0;
        }
    }
}

void ComponentSkybox::OnEditor() 
{
    const char* facesNames[] = { "Right face", "Left face", "Top face", "Bottom face", "Front face", "Back face" };
    float availableWidth = ImGui::GetContentRegionAvail().x;

    for (int i = 0; i < 6; i++)
    {
        std::string buttonText = std::string(facesNames[i]) + " Face: ";

        if (faces[i] != nullptr) {

            buttonText += "[ " + std::to_string(faces[i]->GetUID()) + " ]";
        }
        else {
            buttonText += "[ Empty ]";
        }

        ImGui::Button(buttonText.c_str(), ImVec2(availableWidth, 20));

        if (ImGui::BeginDragDropTarget())
        {
            if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("ASSET_ITEM"))
            {
                DragDropPayload* dropData = (DragDropPayload*)payload->Data;
                UID droppedUID = dropData->assetUID;

                const Resource* res = Application::GetInstance().resources->PeekResource(droppedUID);
                if (res && res->GetType() == Resource::Type::TEXTURE)
                {
                    LOG_CONSOLE("Cargando skybox face %d: %llu", i, droppedUID);
                    SetFaceTexture((SkyboxFace)i, droppedUID);
                }
            }
            ImGui::EndDragDropTarget();
        }
    }

    bool active = Application::GetInstance().renderer.get()->IsSkyboxActive(this);
    bool isActive = active;
    if (ImGui::Checkbox("Active", &isActive))
    {
        if (active != isActive)
        {
            if (active) Application::GetInstance().renderer.get()->SetActiveSkybox(nullptr);
            else Application::GetInstance().renderer.get()->SetActiveSkybox(this);
        }
    }
}
