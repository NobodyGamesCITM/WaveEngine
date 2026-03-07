#pragma once

#include <string>
#include "nlohmann/json.hpp"

class Texture;
class Shader;

class Cubemap
{
public:
	Cubemap(const std::vector<Texture>& faceTextures) {}
	virtual ~Cubemap() = default;

	virtual void Bind(Shader* shader) = 0;

	virtual void SaveCustomData(std::ofstream& file) const = 0;
	virtual void LoadCustomData(std::ifstream& file) = 0;

	virtual void SaveToJson(nlohmann::json& j) const = 0;
	virtual void LoadFromJson(const nlohmann::json& j) = 0;

private:
	std::string name;
	std::vector<Texture> faceTextures;
};