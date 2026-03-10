#include "ShaderSingleColor.h"

bool ShaderSingleColor::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec3 aNormal;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4 weights;\n"
        "uniform float outlineThickness;\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(aPos, 1.0);\n"
        "    vec3 skinnedNormal = normalize(mat3(skinMat) * aNormal);\n"
        "    vec3 scale = vec3(length(model[0].xyz), length(model[1].xyz), length(model[2].xyz));\n"
        "    mat4 modelNoScale = model;\n"
        "    modelNoScale[0].xyz /= scale.x;\n"
        "    modelNoScale[1].xyz /= scale.y;\n"
        "    modelNoScale[2].xyz /= scale.z;\n"
        "    vec3 worldNormal = normalize(mat3(modelNoScale) * skinnedNormal);\n"
        "    vec4 worldPos = model * skinnedPos;\n"
        "    vec4 viewPos = view * worldPos;\n"
        "    float distance = length(viewPos.xyz);\n"
        "    float dynamicThickness = outlineThickness * (distance * 0.1);\n"
        "    worldPos.xyz += worldNormal * dynamicThickness;\n"
        "    gl_Position = projection * view * worldPos;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "uniform vec3 outlineColor;\n"
        "void main() {\n"
        "    FragColor = vec4(outlineColor, 1.0);\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}