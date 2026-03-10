#pragma once

#include "Material.h"
#include "Globals.h"
#include "glm/glm.hpp"


class ResourceTexture;

class MaterialStandard : public Material
{
public:
    
    MaterialStandard(MaterialType type = STANDARD);
    ~MaterialStandard() override;

    void Bind(Shader* shader) override;

    void SetAlbedoMap(UID uid);
    void SetMetallicMap(UID uid);
    void SetNormalMap(UID uid);
    void SetHeightMap(UID uid);
    void SetOcclusionMap(UID uid);

    const glm::vec4& GetColor() { return color; }
    const float GetMetallic() { return metallic; }
    const float GetRoughness() { return roughness; }
    const float GetHeightScale() { return heightScale; }
    const glm::vec2& GetTiling() { return tiling; }
    const glm::vec2& GetOffset() { return offset; }

    void SetColor(glm::vec4 _color) { color = _color; }
    void SetMetallic(float _metallic) { metallic = _metallic; }
    void SetRoughness(float _roughness) { roughness = _roughness; }
    void SetHeightScale(float _heightScale) { heightScale = _heightScale; }
    void SetTiling(glm::vec2  _tiling) { tiling = _tiling; }
    void SetOffset(glm::vec2  _offset) { offset = _offset; }

    const UID GetAlbedoMapUID() { return albedoMapUID; }
    const UID GetMetallicMapUID() { return metallicMapUID; }
    const UID GetNormalMapUID() { return normalMapUID; }
    const UID GetHeightMapUID() { return heightMapUID; }
    const UID GetOcclusioMapUID() { return occlusionMapUID; }

    void LoadCustomData(std::ifstream& file) override;
    void SaveCustomData(std::ofstream& file) const override;

    void SaveToJson(nlohmann::json& j) const override;
    void LoadFromJson(const nlohmann::json& j) override;

private:
    
    UID albedoMapUID = 0;
    UID metallicMapUID = 0;
    UID normalMapUID = 0;
    UID heightMapUID = 0;
    UID occlusionMapUID = 0;

    ResourceTexture* albedoMap = nullptr;
    ResourceTexture* metallicMap = nullptr;
    ResourceTexture* normalMap = nullptr;
    ResourceTexture* heightMap = nullptr;
    ResourceTexture* occlusionMap = nullptr;

    glm::vec4 color = { 1.0f, 1.0f, 1.0f , 1.0f};
    float metallic = 0.0f;
    float roughness = 0.5f;
    float heightScale = 0.05f;
    glm::vec2 tiling = { 1.0f, 1.0f };
    glm::vec2 offset = { 0.0f, 0.0f };

};