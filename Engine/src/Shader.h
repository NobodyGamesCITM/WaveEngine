#pragma once

#include <string>
#include <glm/glm.hpp>
#include <unordered_map>

class Shader
{
public:
    Shader();
    ~Shader();

    virtual bool CreateShader() = 0;

    bool LoadFromSource(const char* vSource, const char* fSource, const char* gSource = nullptr);

    void Use() const;
    void Delete();

    unsigned int GetProgramID() const { return shaderProgram; }

    void SetVec3(const std::string& name, const glm::vec3& value);
    void SetFloat(const std::string& name, float value) ;
    void SetMat4(const std::string& name, const glm::mat4& mat) ;
    void SetInt(const std::string& name, int value);

    void SetVec4(const std::string& name, const glm::vec4& value);
    void SetVec2(const std::string& name, const glm::vec2& value);
    void SetBool(const std::string& name, bool value);

    int GetUniformLocation(const std::string&);
protected:

    std::unordered_map<std::string, int> m_UniformLocationCache;

    unsigned int CompileShader(unsigned int type, const char* source);

    unsigned int shaderProgram;

    const char* shaderHeader;
    const char* skinningDeclarations;
    const char* skinningFunction;
};