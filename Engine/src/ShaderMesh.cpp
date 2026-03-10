#include "ShaderMesh.h"

bool ShaderMesh::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout (location = 0) in vec3 position;\n"
        "layout (location = 3) in ivec4 boneIDs;\n"
        "layout (location = 4) in vec4 weights;\n"
        "\n"
        "void main()\n"
        "{\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(position, 1.0f);\n"
        "\n"
        "    gl_Position = projection * view * model * skinnedPos;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "uniform vec4 lineColor;\n"
        "void main() {\n"
        "    FragColor = lineColor;\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}