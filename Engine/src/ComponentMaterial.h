#pragma once
#include "Component.h"
#include "ModuleResources.h"  
#include <string>
#include <glm/glm.hpp> 

enum class MaterialType {
    STANDARD,
    WATER
};

class ComponentMaterial : public Component {
public:
    ComponentMaterial(GameObject* owner);
    ~ComponentMaterial();

    void Update() override;
    void OnEditor() override;

    // Serialization
    void Serialize(nlohmann::json& componentObj) const override;
    void Deserialize(const nlohmann::json& componentObj) override;

    bool IsType(ComponentType type) override { return type == ComponentType::MATERIAL; };
    bool IsIncompatible(ComponentType type) override { return type == ComponentType::MATERIAL; };

    bool LoadTextureByUID(UID uid);
    bool LoadTexture(const std::string& path);

    bool LoadShaderByUID(UID uid);
    bool LoadShader(const std::string& path);

    void CreateCheckerboardTexture();
    void RestoreOriginalTexture();

    void Use();
    void Unbind();

    bool HasTexture() const { return textureUID != 0 || useCheckerboard; }
    bool HasOriginalTexture() const { return originalTextureUID != 0; }
    bool IsUsingCheckerboard() const { return useCheckerboard; }

    UID GetTextureUID() const { return textureUID; }
    UID GetOriginalTextureUID() const { return originalTextureUID; }

    const std::string& GetTexturePath() const { return texturePath; }
    const std::string& GetOriginalTexturePath() const { return originalTexturePath; }

    UID GetShaderUID() const { return shaderUID; }
    const std::string& GetShaderPath() const { return shaderPath; }

    int GetTextureWidth() const;
    int GetTextureHeight() const;

    // Embedded material properties
    void SetDiffuseColor(const glm::vec4& color) { diffuseColor = color; hasMaterialProperties = true; }
    void SetSpecularColor(const glm::vec4& color) { specularColor = color; hasMaterialProperties = true; }
    void SetAmbientColor(const glm::vec4& color) { ambientColor = color; hasMaterialProperties = true; }
    void SetEmissiveColor(const glm::vec4& color) { emissiveColor = color; hasMaterialProperties = true; }
    void SetShininess(float value) { shininess = value; hasMaterialProperties = true; }
    void SetOpacity(float value) { opacity = value; hasMaterialProperties = true; }
    void SetMetallic(float value) { metallic = value; hasMaterialProperties = true; }
    void SetRoughness(float value) { roughness = value; hasMaterialProperties = true; }

    // Getters
    glm::vec4 GetDiffuseColor() const { return diffuseColor; }
    glm::vec4 GetSpecularColor() const { return specularColor; }
    glm::vec4 GetAmbientColor() const { return ambientColor; }
    glm::vec4 GetEmissiveColor() const { return emissiveColor; }
    float GetShininess() const { return shininess; }
    float GetOpacity() const { return opacity; }
    float GetMetallic() const { return metallic; }
    float GetRoughness() const { return roughness; }

    // Water parameters (Speed, Amplitude, Frequency)
    void SetWaveSpeed(float speed) { waveSpeed = speed; }
    void SetWaveAmplitude(float amplitude) { waveAmplitude = amplitude; }
    void SetWaveFrequency(float frequency) { waveFrequency = frequency; }
    
    float GetWaveSpeed() const { return waveSpeed; }
    float GetWaveAmplitude() const { return waveAmplitude; }
    float GetWaveFrequency() const { return waveFrequency; }

    MaterialType GetMaterialType() const { return materialType; }
    void SetMaterialType(MaterialType type) { materialType = type; }

    int GetLightingMode() const { return lightingMode; }

    bool HasMaterialProperties() const { return hasMaterialProperties; }

    void ReloadTexture();

private:
    void ReleaseCurrentTexture();
    void ReleaseCurrentShader();

private:
    UID textureUID;
    UID shaderUID = 0;
    UID originalTextureUID;
    bool useCheckerboard = true;

    std::string texturePath;
    std::string originalTexturePath;
    std::string shaderPath;

    //  Material properties
    glm::vec4 diffuseColor = glm::vec4(1.0f);
    glm::vec4 specularColor = glm::vec4(1.0f);
    glm::vec4 ambientColor = glm::vec4(0.2f, 0.2f, 0.2f, 1.0f);
    glm::vec4 emissiveColor = glm::vec4(0.0f);

    float shininess = 32.0f;
    float opacity = 1.0f;
    float metallic = 0.0f;
    float roughness = 0.5f;

    // Water specific properties
    float waveSpeed = 0.4f;
    float waveAmplitude = 1.1f;
    float waveFrequency = 8.2f;
    int lightingMode = 1; // 0 = Per-Vertex, 1 = Per-Pixel

    MaterialType materialType = MaterialType::STANDARD;

    bool hasMaterialProperties = false;
};