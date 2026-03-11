#include "ShaderDepthVisualization.h"

bool ShaderDepthVisualization::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec3 aNormal;\n"
        "layout(location = 2) in vec2 aTexCoord;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4 weights;\n"
        "out vec2 TexCoord;\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(aPos, 1.0);\n"
        "    gl_Position = projection * view * model * skinnedPos;\n"
        "    TexCoord = aTexCoord;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "uniform float nearPlane;\n"
        "uniform float farPlane;\n"
        "float LinearizeDepth(float depth) {\n"
        "    float z = depth * 2.0 - 1.0;\n"
        "    return (2.0 * nearPlane * farPlane) / (farPlane + nearPlane - z * (farPlane - nearPlane));\n"
        "}\n"
        "void main() {\n"
        "    float depth = LinearizeDepth(gl_FragCoord.z) / farPlane;\n"
        "    FragColor = vec4(vec3(depth), 1.0);\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}