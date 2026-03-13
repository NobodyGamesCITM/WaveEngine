#include "ShaderLines.h"

bool ShaderLines::CreateShader()
{
    std::string vert = std::string(shaderHeader) +
        "layout(location = 0) in vec3 aPos;\n"
        "layout(location = 1) in vec4 aColor;\n"
        "out vec4 ourColor;\n"
        "uniform mat4 model;\n"
        "void main() {\n"
        "    gl_Position = projection * view * model * vec4(aPos, 1.0);\n"
        "    ourColor = aColor;\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 FragColor;\n"
        "in vec4 ourColor;\n"
        "void main() {\n"
        "    FragColor = ourColor;\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}