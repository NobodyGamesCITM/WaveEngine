#include "LightManager.h"
#include "ComponentLight.h"
#include "Shader.h"

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <algorithm>
#include <cmath>
#include <string>

#include "ShaderShadowDepth.h"
#include "ComponentMesh.h"
#include "GameObject.h"
#include "Transform.h"
#include <glm/gtc/matrix_transform.hpp>
#include <memory>

LightManager::LightManager()
{
    InitSSBOs();
    InitShadowMap();
}

LightManager::~LightManager()
{
    if (ssboDir)          glDeleteBuffers(1, &ssboDir);
    if (ssboPoint)        glDeleteBuffers(1, &ssboPoint);
    if (ssboSpot)         glDeleteBuffers(1, &ssboSpot);
    if (shadowMapFBO)     glDeleteFramebuffers(1, &shadowMapFBO);
    if (shadowMapTexture) glDeleteTextures(1, &shadowMapTexture);
}

void LightManager::InitSSBOs()
{
    glGenBuffers(1, &ssboDir);
    glGenBuffers(1, &ssboPoint);
    glGenBuffers(1, &ssboSpot);

    // Allocate empty buffers so the binding points exist from the start
    auto emptyAlloc = [](unsigned int ssbo, int binding) {
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
        glBufferData(GL_SHADER_STORAGE_BUFFER, 0, nullptr, GL_DYNAMIC_DRAW);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, ssbo);
        };

    emptyAlloc(ssboDir, 2);
    emptyAlloc(ssboPoint, 3);
    emptyAlloc(ssboSpot, 4);

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void LightManager::RegisterLight(ComponentLight* light)
{
    if (!light) return;
    if (std::find(lights.begin(), lights.end(), light) == lights.end())
        lights.push_back(light);
}

void LightManager::UnregisterLight(ComponentLight* light)
{
    auto it = std::find(lights.begin(), lights.end(), light);
    if (it != lights.end())
        lights.erase(it);
}

void LightManager::UploadBuffer(unsigned int ssbo, const void* data, size_t bytes)
{
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, (GLsizeiptr)bytes, data, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void LightManager::UploadToShader(Shader* shader)
{
    if (!shader) return;

    for (ComponentLight* l : lights)
    {
        if (l && l->IsActive())
            l->UpdateTransformData();
    }

    std::vector<GPUDirLight>   dirPacked;
    std::vector<GPUPointLight> pointPacked;
    std::vector<GPUSpotLight>  spotPacked;

    for (const ComponentLight* l : lights)
    {
        if (!l || !l->IsActive()) continue;

        switch (l->GetLightType())
        {
        case LightType::DIRECTIONAL:
        {
            const DirectionalLightData& d = l->GetDirectionalData();
            GPUDirLight g{};
            g.direction = glm::normalize(d.direction);
            g.ambient = d.ambient;
            g.diffuse = d.diffuse;
            g.specular = d.specular;
            dirPacked.push_back(g);
            break;
        }
        case LightType::POINT:
        {
            const PointLightData& p = l->GetPointData();
            GPUPointLight g{};
            g.position = p.position;
            g.ambient = p.ambient;
            g.diffuse = p.diffuse;
            g.specular = p.specular;
            g.constant = p.constant;
            g.linear = p.linear;
            g.quadratic = p.quadratic;
            pointPacked.push_back(g);
            break;
        }
        case LightType::SPOT:
        {
            const SpotLightData& s = l->GetSpotData();
            GPUSpotLight g{};
            g.position = s.position;
            g.direction = glm::normalize(s.direction);
            g.ambient = s.ambient;
            g.diffuse = s.diffuse;
            g.specular = s.specular;
            g.cutOff = std::cos(glm::radians(s.cutOff));
            g.outerCutOff = std::cos(glm::radians(s.outerCutOff));
            g.constant = s.constant;
            g.linear = s.linear;
            g.quadratic = s.quadratic;
            spotPacked.push_back(g);
            break;
        }
        }
    }

    // Upload SSBOs and rebind to correct binding points
    auto upload = [](unsigned int ssbo, int binding, const void* data, size_t bytes) {
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
        glBufferData(GL_SHADER_STORAGE_BUFFER, (GLsizeiptr)bytes, bytes > 0 ? data : nullptr, GL_DYNAMIC_DRAW);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, ssbo);
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
        };

    upload(ssboDir, 2, dirPacked.data(), dirPacked.size() * sizeof(GPUDirLight));
    upload(ssboPoint, 3, pointPacked.data(), pointPacked.size() * sizeof(GPUPointLight));
    upload(ssboSpot, 4, spotPacked.data(), spotPacked.size() * sizeof(GPUSpotLight));

    //Tell the shader how many lights of each type are active
    shader->SetInt("numDirLights", (int)dirPacked.size());
    shader->SetInt("numPointLights", (int)pointPacked.size());
    shader->SetInt("numSpotLights", (int)spotPacked.size());
}

void LightManager::InitShadowMap()
{
    shadowDepthShader = std::make_unique<ShaderShadowDepth>();
    shadowDepthShader->CreateShader();

    glGenFramebuffers(1, &shadowMapFBO);

    glGenTextures(1, &shadowMapTexture);
    glBindTexture(GL_TEXTURE_2D, shadowMapTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT,
        SHADOW_WIDTH, SHADOW_HEIGHT, 0,
        GL_DEPTH_COMPONENT, GL_FLOAT, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    float borderColor[] = { 1.0f, 1.0f, 1.0f, 1.0f };
    glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, borderColor);

    glBindFramebuffer(GL_FRAMEBUFFER, shadowMapFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
        GL_TEXTURE_2D, shadowMapTexture, 0);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    glBindFramebuffer(GL_FRAMEBUFFER, shadowMapFBO);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
        LOG_DEBUG("ERROR: shadowMapFBO incompleto: 0x%x", status);
    else
        LOG_DEBUG("shadowMapFBO OK");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void LightManager::BuildShadowMap(const std::vector<ComponentMesh*>& meshes)
{
    // Buscar la primera luz direccional activa
    ComponentLight* dirLight = nullptr;
    for (ComponentLight* l : lights)
    {
        if (l && l->IsActive() && l->GetLightType() == LightType::DIRECTIONAL)
        {
            dirLight = l;
            break;
        }
    }
    if (!dirLight) return;

    // Guardar estado GL actual
    GLint prevViewport[4];
    glGetIntegerv(GL_VIEWPORT, prevViewport);
    GLint prevFBO;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);

    // Construir lightSpaceMatrix
    glm::vec3 lightDir = glm::normalize(dirLight->GetDirectionalData().direction);

    // Evitar up vector degenerado cuando la luz es casi vertical (paralela a Y)
    glm::vec3 upVector = (glm::abs(glm::dot(lightDir, glm::vec3(0.0f, 1.0f, 0.0f))) > 0.99f)
        ? glm::vec3(0.0f, 0.0f, 1.0f)
        : glm::vec3(0.0f, 1.0f, 0.0f);

    glm::vec3 lightPos = -lightDir * 200.0f;
    glm::mat4 lightView = glm::lookAt(lightPos, glm::vec3(0.0f), upVector);
    glm::mat4 lightProj = glm::ortho(-300.0f, 300.0f, -300.0f, 300.0f, 1.0f, 600.0f);
    lightSpaceMatrix = lightProj * lightView;

    // Validar que la matriz no sea NaN/Inf (direccion de luz degenerada)
    if (std::isnan(lightSpaceMatrix[0][0]) || std::isinf(lightSpaceMatrix[0][0]))
    {
        LOG_DEBUG("WARNING: lightSpaceMatrix degenerada, shadow pass abortado");
        return;
    }

    // Shadow pass
    glViewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT);
    glBindFramebuffer(GL_FRAMEBUFFER, shadowMapFBO);
    glClear(GL_DEPTH_BUFFER_BIT);
    glCullFace(GL_FRONT);

    shadowDepthShader->Use();
    shadowDepthShader->SetMat4("lightSpaceMatrix", lightSpaceMatrix);

    for (ComponentMesh* mesh : meshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->IsActive()) continue;
        if (!mesh->GetMesh().IsValid()) continue;

        shadowDepthShader->SetMat4("model", mesh->owner->transform->GetGlobalMatrix());
        glBindVertexArray(mesh->GetMesh().VAO);
        glDrawElements(GL_TRIANGLES, (GLsizei)mesh->GetNumIndices(), GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }

    glCullFace(GL_BACK);
    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);

    // Restaurar viewport
    glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);
}