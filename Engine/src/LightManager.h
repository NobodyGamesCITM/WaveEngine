#pragma once
#include "LightData.h"
#include <vector>

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

private:
    void InitSSBOs();
    void UploadBuffer(unsigned int ssbo, const void* data, size_t bytes);

    std::vector<ComponentLight*> lights;

    // One SSBO per light type
    unsigned int ssboDir = 0;
    unsigned int ssboPoint = 0;
    unsigned int ssboSpot = 0;
};