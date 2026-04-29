#type vertex
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoords;

out vec3 FragPos;
out vec3 Normal;
out vec2 TexCoords;
out vec3 vLightingColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

// Lighting uniforms
uniform vec3 lightDir;
uniform vec3 viewPos;
uniform vec3 materialDiffuse;
uniform int lightingMode; // 0 = Per-Vertex, 1 = Per-Pixel

void main()
{
    FragPos = vec3(model * vec4(aPos, 1.0));
    Normal = mat3(transpose(inverse(model))) * aNormal;  
    TexCoords = aTexCoords;
    gl_Position = projection * view * vec4(FragPos, 1.0);

    // Per-Vertex Lighting (calculated only if lightingMode == 0)
    if (lightingMode == 0)
    {
        vec3 norm = normalize(Normal);
        vec3 lightDirection = normalize(-lightDir);
        vec3 viewDir = normalize(viewPos - FragPos);
        vec3 halfwayDir = normalize(lightDirection + viewDir);

        float ambientStrength = 0.1;
        vec3 ambient = ambientStrength * vec3(1.0);

        float diff = max(dot(norm, lightDirection), 0.0);
        vec3 diffuse = diff * vec3(1.0);

        float spec = pow(max(dot(norm, halfwayDir), 0.0), 32.0);
        vec3 specular = 0.5 * spec * vec3(1.0);

        vLightingColor = (ambient + diffuse + specular) * materialDiffuse;
    }
    else
    {
        vLightingColor = vec3(0.0);
    }
}

#type fragment
#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoords;
in vec3 vLightingColor;

uniform sampler2D texture1;
uniform int hasTexture;
uniform vec3 materialDiffuse;
uniform vec3 lightDir;
uniform vec3 viewPos;
uniform int lightingMode;
uniform float opacity;

void main()
{
    vec3 finalLighting;

    if (lightingMode == 0)
    {
        // Use color calculated in Vertex Shader
        finalLighting = vLightingColor;
    }
    else
    {
        // Per-Pixel Calculation
        vec3 norm = normalize(Normal);
        vec3 lightDirection = normalize(-lightDir);
        vec3 viewDir = normalize(viewPos - FragPos);
        vec3 halfwayDir = normalize(lightDirection + viewDir);

        float ambientStrength = 0.1;
        vec3 ambient = ambientStrength * vec3(1.0);

        float diff = max(dot(norm, lightDirection), 0.0);
        vec3 diffuse = diff * vec3(1.0);

        float spec = pow(max(dot(norm, halfwayDir), 0.0), 32.0);
        vec3 specular = 0.5 * spec * vec3(1.0);

        finalLighting = (ambient + diffuse + specular) * materialDiffuse;
    }

    vec4 texColor = vec4(1.0);
    if (hasTexture == 1)
        texColor = texture(texture1, TexCoords);
        
    FragColor = vec4(finalLighting, 1.0) * texColor;
    FragColor.a *= opacity; // Apply material opacity
}
