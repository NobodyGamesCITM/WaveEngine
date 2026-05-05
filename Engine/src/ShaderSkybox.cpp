#include "ShaderSkybox.h"

bool ShaderSkybox::CreateShader()
{
    std::string vert =
        "#version 460 core\n"
        "layout (location = 0) in vec3 aPos;\n"
        "out vec3 TexCoords;\n"
        "uniform mat4 projection;\n"
        "uniform mat4 view;\n"
        "void main()\n"
        "{\n"
        "    TexCoords = aPos;\n"
        "    vec4 pos = projection * view * vec4(aPos, 1.0);\n"
        "    gl_Position = pos.xyww;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "in vec3 TexCoords;\n"
        "uniform samplerCube skybox;\n"
        "void main()\n"
        "{\n"
        "    FragColor = texture(skybox, TexCoords);\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}