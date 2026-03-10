#include "ShaderNoTexture.h"

bool ShaderNoTexture::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec3 aNormal;\n"
        "layout(location = 2) in vec2 aTexCoord;\n"
        "layout(location = 3) in ivec4 boneIDs;\n"
        "layout(location = 4) in vec4 weights;\n"
        "out vec3 FragPos;\n"
        "out vec3 Normal;\n"
        "out vec2 TexCoord;\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(aPos, 1.0);\n"
        "    vec3 skinnedNormal = mat3(skinMat) * aNormal;\n"
        "    FragPos = vec3(model * skinnedPos);\n"
        "    Normal = mat3(transpose(inverse(model))) * skinnedNormal;\n"
        "    TexCoord = aTexCoord;\n"
        "    gl_Position = projection * view * vec4(FragPos, 1.0);\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "in vec3 FragPos;\n"
        "in vec3 Normal;\n"
        "in vec2 TexCoord;\n"
        "uniform sampler2D texture1;\n"
        "uniform int hasTexture;\n"
        "uniform vec3 tintColor;\n"
        "uniform vec3 lightDir;\n"
        "uniform vec3 materialDiffuse;\n"
        "uniform float opacity;\n"
        "void main() {\n"
        "    vec3 baseColor;\n"
        "    float alpha = 1.0;\n"
        "    if (hasTexture == 1) {\n"
        "        vec4 texColor = texture(texture1, TexCoord);\n"
        "        if (texColor.a < 0.01) discard;\n"
        "        baseColor = texColor.rgb;\n"
        "        alpha = texColor.a;\n"
        "    } else {\n"
        "        baseColor = materialDiffuse;\n"
        "    }\n"
        "    vec3 norm = normalize(Normal);\n"
        "    vec3 light = normalize(-lightDir);\n"
        "    float diff = max(dot(norm, light), 0.0);\n"
        "    vec3 ambient = 0.3 * baseColor;\n"
        "    vec3 diffuse = diff * baseColor;\n"
        "    FragColor = vec4(ambient + diffuse, alpha * opacity);\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}