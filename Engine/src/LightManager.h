#pragma once
#include "LightData.h"
#include "ShaderShadowDepth.h"
#include <vector>
#include <memory>
#include "ComponentMesh.h"
#include "ComponentSkinnedMesh.h"
#include "GameObject.h"
#include "Transform.h"
#include <glm/gtc/matrix_transform.hpp>

class Shader;
class ComponentLight;

// Collects all active ComponentLights and uploads them to the GPU via SSBOs.
// The Renderer owns one instance. ComponentLight registers/unregisters itself.

//   binding 2 -> directional lights
//   binding 3 -> point lights
//   binding 4 -> spot lights

class LightManager
{
public:
    LightManager();
    ~LightManager();

    void RegisterLight(ComponentLight* light);
    void UnregisterLight(ComponentLight* light);

    // Pack active lights into GPU structs and upload via SSBOs.
    // Call once per frame before drawing lit meshes, then bind the shader.
    // Also sets numDirLights / numPointLights / numSpotLights uniforms.
    void UploadToShader(Shader* shader);

    void BuildShadowMap(const std::vector<ComponentMesh*>& meshes,
        const std::vector<ComponentSkinnedMesh*>& skinnedMeshes);    
    //void BuildShadowMapSkinned(const std::vector<ComponentSkinnedMesh*>& skinnedMeshes);

    unsigned int GetShadowMapID()      const { return shadowMapTexture; }
    glm::mat4    GetLightSpaceMatrix() const { return lightSpaceMatrix; }

    bool shadowsEnabled = true;

    void MarkShadowsDirty() { shadowsDirty = true; }

private:
    void InitSSBOs();
    void InitShadowMap();
    void UploadBuffer(unsigned int ssbo, const void* data, size_t bytes);

    std::vector<ComponentLight*> lights;

    // One SSBO per light type
    unsigned int ssboDir = 0;
    unsigned int ssboPoint = 0;
    unsigned int ssboSpot = 0;

    // Shadow map
    unsigned int shadowMapFBO = 0;
    unsigned int shadowMapTexture = 0;
    glm::mat4    lightSpaceMatrix = glm::mat4(1.0f);

    std::unique_ptr<ShaderShadowDepth> shadowDepthShader;

    static constexpr int SHADOW_WIDTH = 8192;
    static constexpr int SHADOW_HEIGHT = 8192;

    bool shadowsDirty = true;
    glm::mat4 cachedLightDir = glm::mat4(0.0f);

    //ComponentSkinnedMesh* skinnedMesh;
};