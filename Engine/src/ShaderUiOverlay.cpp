#include "ShaderUiOverlay.h"

bool ShaderUiOverlay::CreateShader()
{
    std::string vert =
        "#version 460 core\n"
        "layout(location = 0) in vec2 aPos;\n"
        "layout(location = 1) in vec2 aUV;\n"
        "out vec2 vUV;\n"
        "void main() {\n"
        "    vUV = aUV;\n"
        "    gl_Position = vec4(aPos, 0.0, 1.0);\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "in vec2 vUV;\n"
        "out vec4 FragColor;\n"
        "uniform sampler2D uTexture;\n"
        "uniform float uOpacity;\n"
        "void main() {\n"
        "    vec4 col = texture(uTexture, vUV);\n"
        "    col.a *= uOpacity;\n"
        "    FragColor = col;\n"
        "}\n";

    return LoadFromSource(vert.c_str(), frag.c_str());
}