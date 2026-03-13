#pragma once

#include "Module.h"
#include "Frustum.h"
#include "Primitives.h"
#include "glad/glad.h"
#include <memory>
#include <map>
#include <vector>

class GameObject;
class ComponentMesh;
class ComponentParticleSystem;
class CameraLens;
class ComponentCanvas;
class ComponentCamara;
class ComponentPostProcessing;
class Shader;
class Texture;
class ComponentLight;
class LightManager;

class Renderer : public Module
{
    struct RenderObject
    {
        ComponentMesh* mesh;
        glm::mat4 globalModelMatrix;
    };
   
    struct ParticleObject
    {
        ComponentParticleSystem* system;
        glm::mat4 modelMatrix;
    };

    struct CanvasObject
    {
        ComponentCanvas* canvas;
    };

    struct RenderLine {
        glm::vec3 start;
        glm::vec3 end;
        glm::vec4 color;
    };

public:
    Renderer();
    ~Renderer();

    bool Start() override;
    bool PreUpdate() override;
    bool PostUpdate() override;
    bool CleanUp() override;

    Texture* GetDefaultTexture() const { return defaultTexture.get(); }

    // Mesh management
    void LoadMesh(Mesh& mesh);
    void UnloadMesh(Mesh& mesh);
    
    void AddMesh(ComponentMesh* mesh);
    void RemoveMesh(ComponentMesh* mesh);
    void DrawMesh(const ComponentMesh* meshComp);
    
    // Particles management
    void AddParticle(ComponentParticleSystem* particle);
    void RemoveParticle(ComponentParticleSystem* particle);

    // Camera management
    void AddCamera(CameraLens* camera);
    void RemoveCamera(CameraLens* camera);
    
    // Canvas management
    void AddCanvas(ComponentCanvas* canvas);
    void RemoveCanvas(ComponentCanvas* canvas);

    // PostProcessing management
    void AddPostProcessing(ComponentPostProcessing* component);
    void RemovePostProcessing(ComponentPostProcessing* component);

    // Scene Rendering
    bool RenderScene(CameraLens* renderCamera);

    void CreateSkinningSSBOs(unsigned int& ssboGlobal, unsigned int& ssboOffset, const std::vector<glm::mat4>& offsets);
    void UploadGlobalMatricesToGPU(unsigned int ssbo, const std::vector<glm::mat4>& globalMatrices);
    void DeleteSSBO(unsigned int& ssbo);

    // Shader access
    Shader* GetDefaultShader() const { return defaultShader.get(); }
    Shader* GetWaterShader() const { return waterShader.get(); }
    Shader* GetOutlineShader() const { return outlineShader.get(); }
    Shader* GetLineShader() const { return lineShader.get(); }

    // Render configuration
    bool IsDepthTestEnabled() const { return depthTestEnabled; }
    void SetDepthTest(bool enabled);

    bool IsFaceCullingEnabled() const { return faceCullingEnabled; }
    void SetFaceCulling(bool enabled);

    bool IsWireframeMode() const { return wireframeMode; }
    void SetWireframeMode(bool enabled);

    void GetClearColor(float& r, float& g, float& b) const { r = clearColorR; g = clearColorG; b = clearColorB; }
    void SetClearColor(float r, float g, float b);

    int GetCullFaceMode() const { return cullFaceMode; }
    void SetCullFaceMode(int mode); // 0=Back, 1=Front, 2=Both

    void SetLightDir(const glm::vec3& dir) { lightDir = dir; }
    glm::vec3 GetLightDir() const { return lightDir; }

    void SetMSAA(bool enabled);
    bool IsMSAAEnabled() const { return msaaEnabled; }

    // zBuffer visualization
    bool IsShowingZBuffer() const { return showZBuffer; }
    void SetShowZBuffer(bool show) { showZBuffer = show; }

    // Draw forms
    void DrawLine(const glm::vec3& start, const glm::vec3& end, const glm::vec4& color);
    void DrawArc(glm::vec3 center, glm::quat rotation, float r, int segments, glm::vec4 col, glm::vec3 axisA, glm::vec3 axisB);
    void DrawCircle(glm::vec3 center, glm::quat rotation, float r, int segments, glm::vec4 col, glm::vec3 axisA, glm::vec3 axisB);
    void DrawSphere(const glm::vec3& center, float radius, const glm::vec4& color, int segments = 16);
    void DrawFullscreenTexture(unsigned int textureID);

    // Cameras
    void UpdateProjectionMatrix(glm::mat4 projectionMatrix);
    void UpdateViewMatrix(glm::mat4 viewMatrix);

    // Perfect Pixel Picking
    UID GetObjectInPixel(const CameraLens* camera, int x, int y);

    // lights
    void AddLight(ComponentLight* light);
    void RemoveLight(ComponentLight* light);
    LightManager* GetLightManager() const { return lightManager.get(); }

private:

    void ApplyRenderSettings();

    // Draw Functions
    void DrawRenderList(const std::multimap<float, RenderObject>& map, const CameraLens* camera);
    void DrawParticlesList(const CameraLens* camera);
    void DrawLinesList(const CameraLens* camera);
    void DrawStencilList(const CameraLens* camera);
    void DrawNormalsList(const CameraLens* camera);
    void DrawMeshLinesList(const CameraLens* camera);
    void DrawCanvasList(const CameraLens* camera);
    void DrawPostProcessing(const CameraLens* camera);
    void BuildRenderLists(const CameraLens* camera);

    // Shaders
    std::unique_ptr<Shader> defaultShader;
    std::unique_ptr<Shader> postProcessShader;
    std::unique_ptr<Shader> standardShader;
    std::unique_ptr<Shader> waterShader;
    std::unique_ptr<Shader> lineShader;
    std::unique_ptr<Shader> outlineShader;
    std::unique_ptr<Shader> depthShader;
    std::unique_ptr<Shader> normalsShader;
    std::unique_ptr<Shader> meshShader;
    std::unique_ptr<Shader> pickingShader;
    std::unique_ptr<Shader> uiShader;
    
    std::unique_ptr<Shader> currentShader;

    // Default assets
    std::unique_ptr<Texture> defaultTexture;
    Mesh sphere, cube, pyramid, cylinder, plane;

    // OpenGL state
    bool depthTestEnabled = true;
    bool faceCullingEnabled = true;
    bool wireframeMode = false;
    float clearColorR = 0.2f;
    float clearColorG = 0.25f;
    float clearColorB = 0.3f;
    int cullFaceMode = 0; // GL_BACK
    glm::vec3 lightDir = glm::vec3(1.0f, -1.0f, -1.0f);

    // Normal visualization buffers (reused to avoid repeated allocations)
    GLuint normalLinesVAO = 0;
    GLuint normalLinesVBO = 0;
    size_t normalLinesCapacity = 0;

    // Cached uniform locations to avoid repeated lookups
    struct ShaderUniforms {
        GLint projection = -1;
        GLint view = -1;
        GLint model = -1;
        GLint texture1 = -1;
        GLint hasBonesLoc = -1;
        GLint meshInverseLoc = -1;
    } defaultUniforms, lineUniforms, outlineUniforms;

    // UI overlay quad
    GLuint quadVAO = 0;
    GLuint quadVBO = 0;

    // zBuffer visualization
    bool showZBuffer = false;
 
    // SHADERS
    unsigned int uboMatrices;
    unsigned int ssboBones;

    // LISTS
    std::vector<ComponentMesh*> meshes;
    std::vector<ComponentParticleSystem*> particles;
    std::vector<ComponentCanvas*> activeCanvas;
    std::vector<CameraLens*> activeCameras;
    std::vector<ComponentPostProcessing*> postProcessingComponents;

    std::multimap<float, RenderObject> opaqueList;
    std::multimap<float, RenderObject> transparentList;
    std::multimap<float, ParticleObject> particlesList;
    std::vector<RenderObject> stencilList;
    std::vector<RenderObject> normalsList;
    std::vector<RenderObject> meshLinesList;
    std::vector<RenderLine> linesList;
    std::vector<CanvasObject> canvasList;

    // Post Processing
    int postProcessCurrentW = 0;
    int postProcessCurrentH = 0;
    GLuint postProcessFBO = 0;
    GLuint postProcessTexture = 0;
    GLuint postProcessRBO = 0;

    void ResizePostProcessingBuffer(int width, int height);
    
    // ANTIALIAS
    bool msaaEnabled = true;
    unsigned int msaaFBO = 0;
    unsigned int msaaColorBuffer = 0;
    unsigned int msaaDepthStencilRBO = 0;

    //lights
    std::unique_ptr<LightManager> lightManager;

};