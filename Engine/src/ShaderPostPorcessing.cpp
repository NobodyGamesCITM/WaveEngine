#include "ShaderPostPorcessing.h"

bool ShaderPostPorcessing::CreateShader()
{
    const char* ppVertex = R"(
        #version 330 core
        layout (location = 0) in vec2 aPos;
        layout (location = 1) in vec2 aTexCoords;
        out vec2 TexCoords;
        void main() {
            gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
            TexCoords = aTexCoords;
        }
    )";
    const char* ppFragment = R"(
        #version 330 core
        out vec4 FragColor;
        in vec2 TexCoords;
        uniform sampler2D sceneTexture;
        uniform vec2 uTexelSize;

        // Color grading
        uniform bool  gradingEnabled;
        uniform float exposure;
        uniform float contrast;
        uniform float saturation;
        uniform int   toneMapper;
        uniform float gamma;
        uniform vec3  whiteBalance;
        uniform vec3  colorFilter;

        // Vignette
        uniform bool  vignetteEnabled;
        uniform float vignetteIntensity;
        uniform float vignetteSmoothness;
        uniform float vignetteRoundness;
        uniform vec3  vignetteColor;

        // Chromatic aberration
        uniform bool  caEnabled;
        uniform float caIntensity;

        // Bloom
        uniform bool  bloomEnabled;
        uniform float bloomIntensity;
        uniform float bloomThreshold;
        uniform float bloomSoftKnee;
        uniform vec3  bloomTint;

        // Grain
        uniform bool  grainEnabled;
        uniform float grainIntensity;
        uniform float grainScale;
        uniform float uTime;

        // Sharpen
        uniform bool  sharpenEnabled;
        uniform float sharpenIntensity;
        uniform vec2  uResolution;

        vec3 ACESFilm(vec3 x) {
            const float a=2.51, b=0.03, c=2.43, d=0.59, e=0.14;
            return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
        }

        float random(vec2 st) {
            return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
        }

        float bloomWeight(float brightness, float knee) {
            float soft  = brightness - bloomThreshold + knee;
            soft = clamp(soft, 0.0, 2.0 * knee);
            soft = (soft * soft) / (4.0 * knee + 0.00001);
            return max(soft, brightness - bloomThreshold);
        }

        void main() {
            vec2 uv = TexCoords;

            // --- Chromatic Aberration ---
            vec3 color;
            if (caEnabled) {
                vec2 offset = (uv - 0.5) * (caIntensity * 0.01);
                color.r = texture(sceneTexture, uv - offset).r;
                color.g = texture(sceneTexture, uv).g;
                color.b = texture(sceneTexture, uv + offset).b;
            } else {
                color = texture(sceneTexture, uv).rgb;
            }

            // --- Sharpen ---
            if (sharpenEnabled) {
                vec2 texel = uTexelSize;
                vec3 center = color;
                vec3 left   = texture(sceneTexture, uv + vec2(-texel.x, 0.0)).rgb;
                vec3 right  = texture(sceneTexture, uv + vec2(texel.x, 0.0)).rgb;
                vec3 up     = texture(sceneTexture, uv + vec2(0.0, texel.y)).rgb;
                vec3 down   = texture(sceneTexture, uv + vec2(0.0, -texel.y)).rgb;
                
                color = center + (center * 4.0 - left - right - up - down) * sharpenIntensity;
            }

            // --- Bloom (box-blur with soft-knee + tint) ---
            if (bloomEnabled) {
                vec2 texel = uTexelSize;
                vec3 bloomAccum = vec3(0.0);
                float knee = bloomThreshold * bloomSoftKnee;
                const int range = 3;
                for (int x = -range; x <= range; ++x) {
                    for (int y = -range; y <= range; ++y) {
                        vec3  s   = texture(sceneTexture, uv + vec2(x, y) * texel * 2.5).rgb;
                        float lum = dot(s, vec3(0.2126, 0.7152, 0.0722));
                        bloomAccum += s * bloomWeight(lum, knee);
                    }
                }
                bloomAccum /= float((range*2+1) * (range*2+1));
                color += bloomAccum * bloomIntensity * bloomTint;
            }

            // --- Vignette ---
            if (vignetteEnabled) {
                vec2  d       = abs(uv - 0.5) * 2.0;
                float boxDist = max(d.x, d.y);
                float cirDist = length(d);
                float dist    = mix(boxDist, cirDist, vignetteRoundness);
                float radius  = 1.0 - vignetteIntensity;
                float soft    = vignetteSmoothness + 0.05;
                float vig     = smoothstep(radius, radius - soft, dist);
                color = mix(vignetteColor, color, vig);
            }

            // --- Grain ---
            if (grainEnabled) {
                float noise = random(floor(uv * (uResolution / (grainScale + 0.001))) + uTime);
                color += (noise - 0.5) * grainIntensity;
            }

            // --- Color Grading ---
            if (gradingEnabled) {
                color *= whiteBalance;
                // Color filter, exposure, contrast, saturation
                color *= (colorFilter * exposure);
                color  = (color - 0.5) * contrast + 0.5;
                color  = mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, saturation);

                // Tonemapping
                if      (toneMapper == 0) color = ACESFilm(color);
                else if (toneMapper == 1) color = color / (color + vec3(1.0));
                // toneMapper == 2 -> None

                // Gamma AFTER tonemapping (correct order)
                if (gamma > 0.001) color = pow(max(color, vec3(0.0)), vec3(1.0 / gamma));
            }

            FragColor = vec4(color, 1.0);
        }
    )";
    
    return LoadFromSource(ppVertex, ppFragment);
}