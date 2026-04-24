#include "LightManager.h"
#include "ComponentLight.h"
#include "Shader.h"
#include "CameraLens.h"
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

static bool IsVec3Finite(const glm::vec3& v)
{
    return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.z);
}

static bool IsAABBValid(const AABB& aabb, float maxExtent = 50000.f)
{
    if (!IsVec3Finite(aabb.min) || !IsVec3Finite(aabb.max)) return false;
    if (aabb.min.x > aabb.max.x || aabb.min.y > aabb.max.y || aabb.min.z > aabb.max.z) return false;
    if (glm::any(glm::greaterThan(glm::abs(aabb.min), glm::vec3(maxExtent)))) return false;
    if (glm::any(glm::greaterThan(glm::abs(aabb.max), glm::vec3(maxExtent)))) return false;
    return true;
}

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
    shader->SetBool("uShadowsEnabled", shadowsEnabled);
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
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


void LightManager::BuildShadowMap(
    const std::vector<ComponentMesh*>& meshes,
    const std::vector<ComponentSkinnedMesh*>& skinnedMeshes,
    const CameraLens* camera)
{
    if (!shadowsEnabled || !camera) return;

    ComponentLight* dirLight = nullptr;
    for (ComponentLight* l : lights)
        if (l && l->IsActive() && l->GetLightType() == LightType::DIRECTIONAL)
        {
            dirLight = l; break;
        }
    if (!dirLight) return;

    static int debugFrame = 0;
    ++debugFrame;
    bool shouldLog = (debugFrame % 60 == 0);

    GLint prevViewport[4]; glGetIntegerv(GL_VIEWPORT, prevViewport);
    GLint prevFBO;         glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);

    glm::vec3 lightDir = glm::normalize(dirLight->GetDirectionalData().direction);
    glm::vec3 upVector = (glm::abs(glm::dot(lightDir, glm::vec3(0, 1, 0))) > 0.99f)
        ? glm::vec3(0, 0, 1) : glm::vec3(0, 1, 0);

    static constexpr float SHADOW_DISTANCE = 150.0f;

    glm::mat4 shadowProj = glm::perspective(
        glm::radians(camera->GetFov()),
        camera->GetAspectRatio(),
        camera->GetNearPlane(),
        SHADOW_DISTANCE);

    glm::mat4 invViewProj = glm::inverse(shadowProj * camera->GetViewMatrix());

    glm::vec3 frustumCorners[8];
    int idx = 0;
    for (int x = 0; x < 2; ++x)
        for (int y = 0; y < 2; ++y)
            for (int z = 0; z < 2; ++z)
            {
                glm::vec4 pt = invViewProj * glm::vec4(
                    x ? 1.f : -1.f,
                    y ? 1.f : -1.f,
                    z ? 1.f : -1.f,
                    1.0f);
                frustumCorners[idx++] = glm::vec3(pt) / pt.w;
            }

    glm::vec3 sceneCenter(0.f);
    for (auto& c : frustumCorners) sceneCenter += c;
    sceneCenter /= 8.0f;

    glm::vec3 lightPos = sceneCenter - lightDir * 200.0f;
    glm::mat4 lightView = glm::lookAt(lightPos, sceneCenter, upVector);

    if (shouldLog)
    {
        LOG_DEBUG("  lightDir: %.4f %.4f %.4f", lightDir.x, lightDir.y, lightDir.z);
        LOG_DEBUG("  sceneCenter (frustum): %.4f %.4f %.4f", sceneCenter.x, sceneCenter.y, sceneCenter.z);
        LOG_DEBUG("  lightPos: %.4f %.4f %.4f", lightPos.x, lightPos.y, lightPos.z);
        LOG_DEBUG("  shadowDistance: %.1f", SHADOW_DISTANCE);
    }

    glm::vec3 minLS(1e9f), maxLS(-1e9f);
    for (auto& c : frustumCorners)
    {
        glm::vec3 ls = glm::vec3(lightView * glm::vec4(c, 1.0f));
        minLS = glm::min(minLS, ls);
        maxLS = glm::max(maxLS, ls);
    }

    float zNear = -maxLS.z - 200.0f;
    float zFar = -minLS.z + 50.0f;

    if (shouldLog)
    {
        LOG_DEBUG("  minLS: %.4f %.4f %.4f", minLS.x, minLS.y, minLS.z);
        LOG_DEBUG("  maxLS: %.4f %.4f %.4f", maxLS.x, maxLS.y, maxLS.z);
        LOG_DEBUG("  zNear: %.4f  zFar: %.4f", zNear, zFar);
        LOG_DEBUG("  ortho L:%.2f R:%.2f B:%.2f T:%.2f", minLS.x, maxLS.x, minLS.y, maxLS.y);
    }

    if (minLS.x >= maxLS.x || minLS.y >= maxLS.y) {
        LOG_DEBUG("  WARNING: frustum invalido (minLS >= maxLS), skip shadow map este frame.");
        glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
        glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);
        return;
    }

    if (zNear >= zFar) {
        LOG_DEBUG("  WARNING: zNear >= zFar! Resetting to defaults.");
        zNear = 0.1f;
        zFar = 500.0f;
    }

    glm::mat4 lightProj = glm::ortho(minLS.x, maxLS.x, minLS.y, maxLS.y, zNear, zFar);
    lightSpaceMatrix = lightProj * lightView;

    glViewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT);
    glBindFramebuffer(GL_FRAMEBUFFER, shadowMapFBO);
    glClear(GL_DEPTH_BUFFER_BIT);
    glCullFace(GL_FRONT);

    shadowDepthShader->Use();
    shadowDepthShader->SetMat4("lightSpaceMatrix", lightSpaceMatrix);

    // Meshes normales
    shadowDepthShader->SetBool("hasBones", false);
    for (ComponentMesh* mesh : meshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->IsActive()) continue;
        if (!mesh->GetMesh().IsValid()) continue;
        shadowDepthShader->SetMat4("model", mesh->owner->transform->GetGlobalMatrix());
        glBindVertexArray(mesh->GetMesh().VAO);
        glDrawElements(GL_TRIANGLES, (GLsizei)mesh->GetNumIndices(), GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }

    // Skinned meshes
    shadowDepthShader->SetBool("hasBones", true);
    for (ComponentSkinnedMesh* mesh : skinnedMeshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->IsActive()) continue;
        if (!mesh->GetMesh().IsValid()) continue;
        if (!mesh->HasSkinningData()) continue;

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, mesh->GetSSBOGlobal());
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, mesh->GetSSBOOffset());
        shadowDepthShader->SetMat4("meshInverse", mesh->GetMeshInverse());
        shadowDepthShader->SetMat4("model", mesh->owner->transform->GetGlobalMatrix());

        glBindVertexArray(mesh->GetMesh().VAO);
        glDrawElements(GL_TRIANGLES, (GLsizei)mesh->GetNumIndices(), GL_UNSIGNED_INT, 0);

        glBindVertexArray(0);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, 0);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, 0);
    }

    glCullFace(GL_BACK);
    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
    glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3]);
}