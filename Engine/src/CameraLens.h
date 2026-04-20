#pragma once
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

class Frustum;

class CameraLens
{
public:
    CameraLens();
    ~CameraLens();

    void SetRenderTarget(int width, int height);
    void SetPerspective(float fovDegrees, float aspectRatio, float nearPlane, float farPlane);
    void UpdatePerspective();
    
    void SetFov(float fovDegress);
    void SetAspectRatio(float aspectRatio);
    void SetNearPlane(float nearPlane);
    void SetFarPlane(float farPlane);    
    float GetFov() { return fov; }
    float GetAspectRatio() { return aspectRatio; }
    float GetNearPlane() { return zNear; }
    float GetFarPlane() { return zFar; }

    void SetUsesPostProcessing(bool uses) { usesPostProcessing = uses; }
    bool IsUsingPostProcessing() const { return usesPostProcessing; }

    void SetUICullingMask(int mask) { uiCullingMask = mask; }
    int GetUiCullingMask() const { return uiCullingMask; }

    void SetProjectionMatrix(glm::mat4 projectionMatrix);
    void SetViewMatrix(glm::mat4 viewMatrix);
    void LookAt(const glm::vec3& eye, const glm::vec3& center, const glm::vec3& up);

    const glm::mat4& GetViewMatrix() const { return viewMatrix; }
    const glm::mat4& GetProjectionMatrix() const { return projectionMatrix; }

    const Frustum* GetFrustum() const { return frustum; }
    
    bool GetActiveCamera() const { return activeCamera; }
    void SetActiveCamera(bool b);

    bool GetDebugCamera() const { return debugCamera; }
    void SetDebugCamera(bool b);

    glm::vec3 ScreenToWorldRay(int mouseX, int mouseY, int w, int h) const;

    bool CleanUp();

private:
    void UpdateFrustum();

public:
    unsigned int fboID = 0;
    unsigned int rboID = 0;
    unsigned int textureID = 0;

    unsigned int msaaFBO = 0;
    unsigned int msaaColorBuffer = 0;
    unsigned int msaaDepthRBO = 0;

    int textureWidth = 0;
    int textureHeight = 0;
    int depth;

    glm::vec4 backgroundColor;
    glm::vec3 position;
    glm::vec3 reference;
    glm::vec3 up;
    glm::vec2 WorldToScreen(const glm::vec3& worldPos, int screenWidth, int screenHeight, bool& outBehindCamera) const;
    
private:
    glm::mat4 viewMatrix;
    glm::mat4 projectionMatrix;
    Frustum* frustum = nullptr;

    float fov;
    float aspectRatio;
    float zNear;
    float zFar;

    bool usesPostProcessing = false;
    bool activeCamera;
    bool debugCamera = false;
    
    int uiCullingMask = 0;
};