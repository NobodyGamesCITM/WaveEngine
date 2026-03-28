#include "Shader.h"
#include <glad/glad.h>
#include <iostream>
#include <glm/gtc/type_ptr.hpp>
#include "Log.h"

Shader::Shader() : shaderProgram(0)
{
    shaderHeader =
        "#version 460 core\n"
        "layout(std140, binding = 0) uniform Matrices {\n"
        "    mat4 view;\n"
        "    mat4 projection;\n"
        "};\n";

    skinningDeclarations =
        "layout(std430, binding = 0) readonly buffer BoneMatrices { mat4 gBones[]; };\n"
        "layout(std430, binding = 1) readonly buffer OffsetMatrices { mat4 gOffsets[]; };\n"
        "uniform mat4 meshInverse;\n"
        "uniform bool hasBones;\n"
        "uniform mat4 model;\n";

    skinningFunction =
        "mat4 GetSkinMatrix(ivec4 ids, vec4 weights) {\n"
        "    if (!hasBones) return mat4(1.0);\n"
        "    mat4 skinMat = mat4(0.0);\n"
        "    float weightSum = weights.x + weights.y + weights.z + weights.w;\n"
        "    if (weightSum < 0.001) return mat4(1.0);\n"
        "    for(int i = 0; i < 4; i++) {\n"
        "        if(ids[i] == -1) continue;\n"
        "        mat4 boneTransform = meshInverse * gBones[ids[i]] * gOffsets[ids[i]];\n"
        "        skinMat += boneTransform * (weights[i] / weightSum);\n"
        "    }\n"
        "    return skinMat;\n"
        "}\n";
}

Shader::~Shader()
{
    Delete();
}

void Shader::Use() const
{
    glUseProgram(shaderProgram);
}

bool Shader::LoadFromSource(const char* vSource, const char* fSource, const char* gSource)
{
    unsigned int vertexShader = CompileShader(GL_VERTEX_SHADER, vSource);
    if (vertexShader == 0) return false;

    unsigned int fragmentShader = CompileShader(GL_FRAGMENT_SHADER, fSource);
    if (fragmentShader == 0) {
        glDeleteShader(vertexShader);
        return false;
    }

    unsigned int geometryShader = 0;
    if (gSource != nullptr) {
        geometryShader = CompileShader(GL_GEOMETRY_SHADER, gSource);
        if (geometryShader == 0) {
            glDeleteShader(vertexShader);
            glDeleteShader(fragmentShader);
            return false;
        }
    }

    unsigned int newProgram = glCreateProgram();
    glAttachShader(newProgram, vertexShader);
    glAttachShader(newProgram, fragmentShader);
    if (geometryShader != 0) glAttachShader(newProgram, geometryShader);
    glLinkProgram(newProgram);

    int success;
    char infoLog[512];
    glGetProgramiv(newProgram, GL_LINK_STATUS, &success);
    if (!success)
    {
        glGetProgramInfoLog(newProgram, 512, NULL, infoLog);
        LOG_CONSOLE("ERROR: Shader Program Linking Failed\n%s", infoLog);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        if (geometryShader != 0) glDeleteShader(geometryShader);
        glDeleteProgram(newProgram);
        return false;
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    if (geometryShader != 0) glDeleteShader(geometryShader);

    // If there was an old program, delete it
    if (shaderProgram != 0) {
        glDeleteProgram(shaderProgram);
    }

    shaderProgram = newProgram;
    return true;
}

unsigned int Shader::CompileShader(unsigned int type, const char* source)
{
    unsigned int shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    int success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        char infoLog[4096];
        glGetShaderInfoLog(shader, 4096, NULL, infoLog);
        const char* typeStr = (type == GL_VERTEX_SHADER) ? "Vertex" :
            (type == GL_FRAGMENT_SHADER ? "Fragment" : "Geometry");
        LOG_CONSOLE("ERROR: %s Shader Compilation Failed:\n%s", typeStr, infoLog);

        LOG_CONSOLE("Source:\n%s", source);

        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

int Shader::GetUniformLocation(const std::string& name)
{
    auto it = m_UniformLocationCache.find(name);
    if (it != m_UniformLocationCache.end())
        return it->second; 

    int location = glGetUniformLocation(shaderProgram, name.c_str());
    m_UniformLocationCache[name] = location;

    return location;
}

void Shader::Delete()
{
    if (shaderProgram != 0)
    {
        glDeleteProgram(shaderProgram);
        shaderProgram = 0;
    }
}

void Shader::SetVec3(const std::string& name, const glm::vec3& value)
{
    glUniform3fv(GetUniformLocation(name), 1, &value[0]);
}

void Shader::SetFloat(const std::string& name, float value)
{
    auto& cached = m_UniformCacheFloat[name];
    if (cached == value) return;
    cached = value;
    glUniform1f(GetUniformLocation(name), value);
}

void Shader::SetMat4( const std::string& name, const glm::mat4& mat) 
{
    glUniformMatrix4fv(GetUniformLocation(name), 1, GL_FALSE, &mat[0][0]);
}

void Shader::SetInt(const std::string& name, int value)
{
    auto& cached = m_UniformCacheInt[name];
    if (cached == value) return;
    cached = value;
    glUniform1i(GetUniformLocation(name), value);
}

void Shader::SetVec4(const std::string& name, const glm::vec4& value)
{
    auto& cached = m_UniformCacheVec4[name];
    if (cached == value) return;
    cached = value;
    glUniform4fv(GetUniformLocation(name), 1, &value[0]);
}

void Shader::SetVec2(const std::string& name, const glm::vec2& value)
{
    auto& cached = m_UniformCacheVec2[name];
    if (cached == value) return;
    cached = value;
    glUniform2fv(GetUniformLocation(name), 1, &value[0]);
}

void Shader::SetBool(const std::string& name, bool value)
{
    auto& cached = m_UniformCacheInt[name]; 
    int v = (int)value;
    if (cached == v) return;
    cached = v;
    glUniform1i(GetUniformLocation(name), v);
}