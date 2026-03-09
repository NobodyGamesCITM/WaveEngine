#include "ResourceShader.h"
#include "Log.h"
#include <fstream>
#include <sstream>

ResourceShader::ResourceShader(UID uid) : Resource(uid, Resource::SHADER) {
}

ResourceShader::~ResourceShader() {
    UnloadFromMemory();
}

bool ResourceShader::LoadInMemory() {
    //if (IsLoadedToMemory()) return true;

    //// Load from Assets file (GLSL)
    //std::ifstream file(assetsFile);
    //if (!file.is_open()) {
    //    LOG_CONSOLE("ERROR: Could not open shader file %s", assetsFile.c_str());
    //    return false;
    //}

    //std::stringstream buffer;
    //buffer << file.rdbuf();
    //sourceCode = buffer.str();
    //file.close();

    //shader = new Shader();
    //if (Compile()) {
    //    
    //    return true;
    //}

    //delete shader;
    //shader = nullptr;
    return false;
}

void ResourceShader::UnloadFromMemory() {
    if (shader) {
        delete shader;
        shader = nullptr;
    }
    sourceCode.clear();
}

bool ResourceShader::Compile() {
    if (sourceCode.empty() || !shader) return false;

    std::string vertexSource, fragmentSource, geometrySource;
    std::string currentType;
    std::stringstream ss(sourceCode);
    std::string line;

    while (std::getline(ss, line)) {
        if (line.find("#type") != std::string::npos) {
            if (line.find("vertex") != std::string::npos)
                currentType = "vertex";
            else if (line.find("fragment") != std::string::npos)
                currentType = "fragment";
            else if (line.find("geometry") != std::string::npos)
                currentType = "geometry";
        } else {
            if (currentType == "vertex") vertexSource += line + "\n";
            else if (currentType == "fragment") fragmentSource += line + "\n";
            else if (currentType == "geometry") geometrySource += line + "\n";
        }
    }

    if (vertexSource.empty() || fragmentSource.empty()) {
        LOG_CONSOLE("ERROR: Shader source must contain at least vertex and fragment types");
        return false;
    }

    const char* gSrc = geometrySource.empty() ? nullptr : geometrySource.c_str();
    return shader->LoadFromSource(vertexSource.c_str(), fragmentSource.c_str(), gSrc);
}

void ResourceShader::SetSourceCode(const std::string& source) {
    sourceCode = source;
}
