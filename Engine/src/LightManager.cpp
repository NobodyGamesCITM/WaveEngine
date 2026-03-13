#include "LightManager.h"
#include "ComponentLight.h"
#include "Shader.h"

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <algorithm>
#include <cmath>
#include <string>

LightManager::LightManager()
{
    InitSSBOs();
}

LightManager::~LightManager()
{
    if (ssboDir)   glDeleteBuffers(1, &ssboDir);
    if (ssboPoint) glDeleteBuffers(1, &ssboPoint);
    if (ssboSpot)  glDeleteBuffers(1, &ssboSpot);
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

    //Separate active lights by type 
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