#include "ShaderNormal.h"

bool ShaderNormal::CreateShader()
{
    std::string vert = std::string(shaderHeader) + skinningDeclarations + skinningFunction +
        "layout (location = 0) in vec3 position;\n"
        "layout (location = 1) in vec3 aNormal;\n"
        "layout (location = 2) in vec2 aTexCoord;\n"
        "layout (location = 3) in ivec4 boneIDs;\n"
        "layout (location = 4) in vec4 weights;\n"
        "\n"
        "out VS_OUT { vec3 normal; } vs_out;\n"
        "\n"
        "void main() {\n"
        "    mat4 skinMat = GetSkinMatrix(boneIDs, weights);\n"
        "    vec4 skinnedPos = skinMat * vec4(position, 1.0f);\n"
        "    \n"
        "    // Usamos la normal transformada por el skinning\n"
        "    vs_out.normal = normalize(mat3(skinMat) * aNormal);\n"
        "    gl_Position = skinnedPos;\n"
        "}\n";

    std::string geom = std::string(shaderHeader) +
        "layout (points) in;\n"
        "layout (line_strip, max_vertices = 2) out;\n"
        "in VS_OUT { vec3 normal; } gs_in[];\n"
        "\n"
        "uniform mat4 model;\n"
        "const float LINE_LENGTH = 0.3;\n"
        "\n"
        "void main() {\n"
        "    // 1. Transformamos la normal a espacio de mundo (usando solo la rotaci�n del modelo)\n"
        "    // Evitamos inverse() para mayor estabilidad\n"
        "    vec3 worldNormal = normalize(mat3(model) * gs_in[0].normal);\n"
        "    \n"
        "    // 2. Transformamos la posici�n a espacio de mundo\n"
        "    vec4 worldPos = model * gl_in[0].gl_Position;\n"
        "\n"
        "    // Punto inicial: El v�rtice\n"
        "    gl_Position = projection * view * worldPos;\n"
        "    EmitVertex();\n"
        "\n"
        "    // Punto final: V�rtice + normal estirada\n"
        "    gl_Position = projection * view * (worldPos + vec4(worldNormal * LINE_LENGTH, 0.0));\n"
        "    EmitVertex();\n"
        "\n"
        "    EndPrimitive();\n"
        "}\n";

    std::string frag =
        "#version 460 core\n"
        "out vec4 color;\n"
        "uniform vec4 lineColor;\n"
        "void main() { color = lineColor; }\n";

    return LoadFromSource(vert.c_str(), frag.c_str(), geom.c_str());
}