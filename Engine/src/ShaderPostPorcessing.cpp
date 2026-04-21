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
        uniform sampler2D depthTexture;
        uniform sampler2D blurredTexture;
        uniform vec2 uTexelSize;
        uniform int uPass; // 0: Final, 1: H-Blur, 2: V-Blur

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

        // Depth of Field
        uniform bool  dofEnabled;
        uniform float dofDistance;
        uniform float dofRange;
        uniform float dofStrength;
        uniform bool  dofTiltShift;
        uniform vec3  dofTint;
        uniform float dofTintIntensity;
        uniform float nearPlane;
        uniform float farPlane;

        // Distortion
        uniform bool  distortionEnabled;
        uniform float distortionIntensity;

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

        // Radial Blur
        uniform bool  radialBlurEnabled;
        uniform float radialBlurIntensity;
        uniform vec2  radialBlurCenter;

        vec3 ACESFilm(vec3 x) {
            const float a=2.51, b=0.03, c=2.43, d=0.59, e=0.14;
            return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
        }

        float LinearizeDepth(float depth) {
            float z = depth * 2.0 - 1.0;
            return (2.0 * nearPlane * farPlane) / (farPlane + nearPlane - z * (farPlane - nearPlane));
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

            // --- Gaussian Blur Passes ---
            if (uPass == 1 || uPass == 2) {
                float weight[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
                vec3 result = texture(sceneTexture, uv).rgb * weight[0];
                if (uPass == 1) { // Horizontal
                    for(int i = 1; i < 5; ++i) {
                        result += texture(sceneTexture, uv + vec2(uTexelSize.x * i, 0.0)).rgb * weight[i];
                        result += texture(sceneTexture, uv - vec2(uTexelSize.x * i, 0.0)).rgb * weight[i];
                    }
                } else { // Vertical
                    for(int i = 1; i < 5; ++i) {
                        result += texture(sceneTexture, uv + vec2(0.0, uTexelSize.y * i)).rgb * weight[i];
                        result += texture(sceneTexture, uv - vec2(0.0, uTexelSize.y * i)).rgb * weight[i];
                    }
                }
                FragColor = vec4(result, 1.0);
                return;
            }

            // --- Distortion ---
            if (distortionEnabled) {
                vec2 centeredUV = uv - 0.5;
                float r = length(centeredUV);
                float distortionFactor = 1.0 + distortionIntensity * r * r; // Distorsión radial cuadrática
                uv = centeredUV * distortionFactor + 0.5;
            }

            // --- Chromatic Aberration ---
            vec3 color;
            if (caEnabled) {
                vec2 offset = (uv - 0.5) * (caIntensity * 0.02);
                color.r = texture(sceneTexture, uv + offset).r;
                color.g = texture(sceneTexture, uv).g;
                color.b = texture(sceneTexture, uv - offset).b;
            } else {
                color = texture(sceneTexture, uv).rgb;
            }

            // --- Sharpen ---
            if (sharpenEnabled) {
                vec2 texel = uTexelSize;
                vec3 center = color;
                vec3 left   = texture(sceneTexture, uv - vec2(texel.x, 0.0)).rgb;
                vec3 right  = texture(sceneTexture, uv + vec2(texel.x, 0.0)).rgb;
                vec3 up     = texture(sceneTexture, uv + vec2(0.0, texel.y)).rgb;
                vec3 down   = texture(sceneTexture, uv - vec2(0.0, texel.y)).rgb;
                
                color = center + (center * 4.0 - left - right - up - down) * sharpenIntensity;
            }

            // --- Radial Blur ---
            if (radialBlurEnabled) {
                vec2 dir = uv - radialBlurCenter;
                vec3 blurAccum = color;
                const int samples = 10;
                for (int i = 1; i < samples; i++) {
                    float f = float(i) / float(samples - 1);
                    blurAccum += texture(sceneTexture, uv - dir * f * radialBlurIntensity * 0.1).rgb;
                }
                color = blurAccum / float(samples);
            }

            // --- Depth of Field ---
            if (dofEnabled) {
                float blurFactor = 0.0;
                if (dofTiltShift) {
                    // Modo Tilt-Shift: desenfoque basado en la distancia vertical al centro
                    float center = clamp(dofDistance / 1000.0, 0.0, 1.0); 
                    float dist = abs(uv.y - center); 
                    blurFactor = smoothstep(0.0, dofRange * 0.1, dist);
                } else {
                    // Modo Estándar: desenfoque basado en profundidad real
                    float depth = LinearizeDepth(texture(depthTexture, uv).r);
                    // Transición suave: 0 en el foco, sube según la distancia
                    blurFactor = smoothstep(0.0, max(dofRange, 1.0), abs(depth - dofDistance));
                }

                vec3 blurredColor = texture(blurredTexture, uv).rgb;
                // Mezclamos el desenfoque con el tinte (negro) para ese efecto "agujero"
                vec3 dofFinal = mix(blurredColor, dofTint, blurFactor * dofTintIntensity);
                
                color = mix(color, dofFinal, blurFactor * dofStrength);
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
                float radius  = 1.5 - vignetteIntensity;
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