#include "ComponentSkybox.h"
#include "GameObject.h"
#include "ResourceTexture.h"
#include <glad/glad.h>

ComponentSkybox::ComponentSkybox(GameObject* owner) : Component(owner, ComponentType::SKYBOX)
{
    SetupCubeMesh();
}

ComponentSkybox::~ComponentSkybox()
{
    CleanUp();
}

void ComponentSkybox::Enable()
{
    active = true;
}

void ComponentSkybox::Disable()
{
    active = false;
}

void ComponentSkybox::SetFaceTexture(SkyboxFace face, ResourceTexture* texture)
{
    faces[(int)face] = texture;

    // Comprobamos si ya tenemos las 6 texturas asignadas para compilar el cubemap
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

ResourceTexture* ComponentSkybox::GetFaceTexture(SkyboxFace face) const
{
    return faces[(int)face];
}

void ComponentSkybox::BuildCubemapFromResources()
{
    if (cubemapID != 0) glDeleteTextures(1, &cubemapID);

    glGenTextures(1, &cubemapID);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);

    // Asumimos que todas las texturas del skybox miden lo mismo (p.ej. 2048x2048)
    int width = faces[0]->GetWidth(); // Ajusta esto si tus getters se llaman diferente
    int height = faces[0]->GetHeight();

    // 1. Reservamos la memoria en la VRAM para el Cubemap (NULL como datos)
    for (unsigned int i = 0; i < 6; i++) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    }

    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

    // 2. MAGIA DE GPU: Copiamos los píxeles de los ResourceTexture 2D al Cubemap
    GLuint tempFBO;
    glGenFramebuffers(1, &tempFBO);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, tempFBO);

    for (unsigned int i = 0; i < 6; i++)
    {
        // Enganchamos tu ResourceTexture 2D al FBO de lectura
        glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, faces[i]->GetGPU_ID(), 0);

        // Copiamos internamente en la GPU desde el FBO a la cara del Cubemap
        glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);
        glCopyTexSubImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, 0, 0, 0, 0, width, height);
    }

    // Limpiamos
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
    if (skyboxVAO != 0) glDeleteVertexArrays(1, &skyboxVAO);
    if (skyboxVBO != 0) glDeleteBuffers(1, &skyboxVBO);
    if (cubemapID != 0) glDeleteTextures(1, &cubemapID);
}