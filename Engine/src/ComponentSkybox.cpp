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
    if (Application::GetInstance().renderer.get()->IsSkyboxActive(nullptr)) SetActive(true);
}

ComponentSkybox::~ComponentSkybox()
{
    CleanUp();
}

void ComponentSkybox::SetFaceTexture(SkyboxFace face, UID textureUID)
{
    int index = (int)face;

    if (facesResourcesUID[index] == textureUID) return;

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
        for (int i = 0; i < 6; i++)
        {
            if (faces[i] == nullptr || faces[i]->GetGPU_ID() == 0) {
                allFacesLoaded = false;
                break;
            }
        }

        if (allFacesLoaded)
        {
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

    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    for (unsigned int i = 0; i < 6; i++)
    {
        size_t dataSize = (size_t)width * height * 4;
        unsigned char* pixels = new unsigned char[dataSize];

        glBindTexture(GL_TEXTURE_2D, faces[i]->GetGPU_ID());
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

        glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);
        glTexImage2D(
            GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGBA,
            width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

        GLenum err = glGetError();
        if (err != GL_NO_ERROR)
            LOG_DEBUG("[Skybox] OpenGL ERROR face %d: 0x%X", i, err);

        delete[] pixels;
    }

    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
}

void ComponentSkybox::SetActive(bool b)
{
    if (b != active)
    {
        active = b;
        if (active)
        {
            Application::GetInstance().renderer.get()->SetActiveSkybox(this);
        }
        else
        {
            Application::GetInstance().renderer.get()->SetActiveSkybox(nullptr);
        }
    }
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
    if (active) Application::GetInstance().renderer.get()->SetActiveSkybox(nullptr);

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

        if (facesResourcesUID[i] != 0) {

            buttonText += "[ " + std::to_string(facesResourcesUID[i]) + " ]";
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

    bool isActive = active;
    if (ImGui::Checkbox("Active", &isActive))
    {
        if (active != isActive)
        {
            SetActive(isActive);
        }
    }
}

void ComponentSkybox::Serialize(nlohmann::json& componentObj) const
{
    const char* facesNames[] = { "Right face", "Left face", "Top face", "Bottom face", "Front face", "Back face" };
    componentObj["active"] = active;

    for (int i = 0; i < 6; i++)
    {
        componentObj[facesNames[i]] = facesResourcesUID[i];
    }
}

void ComponentSkybox::Deserialize(const nlohmann::json& componentObj)
{
    const char* facesNames[] = { "Right face", "Left face", "Top face", "Bottom face", "Front face", "Back face" };
    bool mustActive = false;
    UID uidsToLoad[6] = { 0,0,0,0,0,0 };

    mustActive = componentObj.value("active", false);
    for (int i = 0; i < 6; i++)
    {
        uidsToLoad[i] = componentObj.value(facesNames[i], (UID)0);
    }

    for (int i = 0; i < 6; i++)
    {
        if (uidsToLoad[i] != 0) SetFaceTexture((SkyboxFace)i, uidsToLoad[i]);
    }

    SetActive(mustActive);
}