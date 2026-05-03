#pragma once

#include <string>
#include "nlohmann/json.hpp"

class Shader;

enum MaterialType
{
    STANDARD,
    UNKNOWN
};

class Material
{
public:
    
    Material(MaterialType type) : type(type) {}
    virtual ~Material() = default;

    virtual void Bind(Shader* shader) = 0;

    MaterialType GetType() const { return type; }
    const std::string& GetName() const { return name; }
    const float GetOpacity() const { return opacity; } //TODO: Fix GetOpacity
    void SetName(const std::string& newName) { name = newName; }
    void SetOpacity(const float _opacity) { opacity = _opacity; }

    virtual void SaveCustomData(std::ofstream& file) const = 0;
    virtual void LoadCustomData(std::ifstream& file) = 0;

    virtual void SaveToJson(nlohmann::json& j) const = 0;
    virtual void LoadFromJson(const nlohmann::json& j) = 0;

private:
    
    MaterialType type;
    std::string name;
    float opacity = 1.0f;
};