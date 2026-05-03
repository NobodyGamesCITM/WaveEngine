#include "ShaderSilhouette.h"

bool ShaderSilhouette::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec3 aNormal;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4 weights;\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(aPos, 1.0);\n"
        "    gl_Position = projection * view * model * skinnedPos;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "uniform vec4 silhouetteColor;\n"
        "void main() {\n"
        "    FragColor = silhouetteColor;\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}
