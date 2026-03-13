#include "ShaderSimpleColor.h"

bool ShaderSimpleColor::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec3 aNormal;\n"
        "layout(location = 2) in vec2 aTexCoords;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4 weights;\n"
        "out vec2 TexCoords;\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(aPos, 1.0);\n"
        "    gl_Position = projection * view * model * skinnedPos;\n"
        "    TexCoords = aTexCoords;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "in vec2 TexCoords;\n"
        "uniform sampler2D texture1;\n"
        "uniform vec3 tintColor;\n"
        "void main() {\n"
        "    vec4 texColor = texture(texture1, TexCoords);\n"
        "    FragColor = vec4(texColor.rgb * tintColor, texColor.a);\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}