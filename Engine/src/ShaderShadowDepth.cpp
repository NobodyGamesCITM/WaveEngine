#include "ShaderShadowDepth.h"
#include "Log.h"

bool ShaderShadowDepth::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4  weights;\n"
        "\n"
        "uniform mat4 lightSpaceMatrix;\n"
        "\n"
        "layout(std430, binding = 5) readonly buffer ModelMatrices { mat4 gModels[]; };\n"
        "\n"
        "void main() {\n"
        "    mat4 m = hasBones ? model : gModels[gl_BaseInstance];\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    gl_Position = lightSpaceMatrix * m * skinMat * vec4(aPos, 1.0);\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "void main() {}\n";

    bool result = LoadFromSource(vert.c_str(), frag.c_str());
    if (!result)
        LOG_DEBUG("ERROR: ShaderShadowDepth failed to compile");
    return result;
}