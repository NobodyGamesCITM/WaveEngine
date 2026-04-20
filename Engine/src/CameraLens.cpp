#include "CameraLens.h"
#include "Application.h"
#include "ModuleScene.h"
#include "Window.h"
#include "Frustum.h"
#include "Log.h"

#include "glad/glad.h"

CameraLens::CameraLens()
{
    frustum = new Frustum();

    position = glm::vec3(0.0f, 0.0f, 5.0f);
    reference = glm::vec3(0.0f, 0.0f, 0.0f);
    up = glm::vec3(0.0f, 1.0f, 0.0f);
    backgroundColor = glm::vec4(0.1f, 0.1f, 0.1f, 1.0f);

    fov = 60.0f;
    aspectRatio = 16.0f / 9.0f;
    zNear = 0.3f;
    zFar = 1000.0f;
    depth = 0;
    activeCamera = true;
    debugCamera = false;
    usesPostProcessing = false;

    textureWidth = 500;
    textureHeight = 500;

    SetRenderTarget(textureWidth, textureHeight);
    LookAt(position, reference, up);
    SetPerspective(fov, aspectRatio, zNear, zFar);

    Application::GetInstance().renderer->AddCamera(this);
}

CameraLens::~CameraLens()
{
    
}

void CameraLens::SetPerspective(float fov, float aspect, float zNear, float zFar)
{
    this->fov = fov;
    this->aspectRatio = aspect;
    this->zNear = zNear;
    this->zFar = zFar;

    projectionMatrix = glm::perspective(glm::radians(fov), aspectRatio, zNear, zFar);

    UpdateFrustum();
}

void CameraLens::UpdatePerspective()
{
    projectionMatrix = glm::perspective(glm::radians(fov), aspectRatio, zNear, zFar);

    UpdateFrustum();
}

void CameraLens::SetFov(float fov)
{
    this->fov = fov;
    UpdatePerspective();
}

void CameraLens::SetAspectRatio(float aspectRatio)
{
    this->aspectRatio = aspectRatio;
    UpdatePerspective();
}

void CameraLens::SetFarPlane(float farPlane)
{
    this->zFar = farPlane;
    UpdatePerspective();
}

void CameraLens::SetNearPlane(float nearPlane)
{
    this->zNear = nearPlane;
    UpdatePerspective();
}

void CameraLens::LookAt(const glm::vec3& eye, const glm::vec3& center, const glm::vec3& _up)
{
    this->position = eye;
    this->reference = center;
    this->up = _up;

    viewMatrix = glm::lookAt(eye, center, up);

    UpdateFrustum();
}

void CameraLens::SetProjectionMatrix(glm::mat4 proj)
{
    projectionMatrix = proj;

    UpdateFrustum();
}

void CameraLens::SetViewMatrix(glm::mat4 view)
{
    viewMatrix = view;

    UpdateFrustum();
}

void CameraLens::UpdateFrustum()
{
    glm::mat4 viewProj = projectionMatrix * viewMatrix;
    frustum->Update(viewProj);
}

glm::vec3 CameraLens::ScreenToWorldRay(int mouseX, int mouseY, int w, int h) const
{
    float x = (2.0f * mouseX) / w - 1.0f;
    float y = 1.0f - (2.0f * mouseY) / h;

    glm::mat4 invVP = glm::inverse(projectionMatrix * viewMatrix);

    glm::vec4 rayStart = invVP * glm::vec4(x, y, -1.0f, 1.0f);
    glm::vec4 rayEnd = invVP * glm::vec4(x, y, 1.0f, 1.0f);

    rayStart /= rayStart.w;
    rayEnd /= rayEnd.w;

    return glm::normalize(glm::vec3(rayEnd - rayStart));
}

bool CameraLens::CleanUp()
{
    Application::GetInstance().renderer->RemoveCamera(this);
    delete frustum;
    return true;
}

void CameraLens::SetRenderTarget(int width, int height)
{
    if (this->textureWidth == width && this->textureHeight == height && fboID != 0 && msaaFBO != 0)
        return;

    if (fboID != 0) glDeleteFramebuffers(1, &fboID);
    if (textureID != 0) glDeleteTextures(1, &textureID);
    if (rboID != 0) glDeleteRenderbuffers(1, &rboID);

    if (msaaFBO != 0) glDeleteFramebuffers(1, &msaaFBO);
    if (msaaColorBuffer != 0) glDeleteTextures(1, &msaaColorBuffer);
    if (msaaDepthRBO != 0) glDeleteRenderbuffers(1, &msaaDepthRBO);

    this->textureWidth = width;
    this->textureHeight = height;
    int samples = 4;

    glGenFramebuffers(1, &msaaFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, msaaFBO);

    glGenTextures(1, &msaaColorBuffer);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, msaaColorBuffer);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, samples, GL_RGBA, width, height, GL_TRUE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, msaaColorBuffer, 0);

    glGenRenderbuffers(1, &msaaDepthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, msaaDepthRBO);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, samples, GL_DEPTH24_STENCIL8, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, msaaDepthRBO);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        LOG_DEBUG("ERROR: Framebuffer MSAA isn't complete");

    glGenFramebuffers(1, &fboID);
    glBindFramebuffer(GL_FRAMEBUFFER, fboID);

    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureID, 0);

    glGenRenderbuffers(1, &rboID);
    glBindRenderbuffer(GL_RENDERBUFFER, rboID);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rboID);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        LOG_DEBUG("ERROR: Framebuffer de salida no está completo.");

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}


void CameraLens::SetActiveCamera(bool b)
{
    activeCamera = b;
}

void CameraLens::SetDebugCamera(bool b)
{
    debugCamera = b;
}
glm::vec2 CameraLens::WorldToScreen(const glm::vec3& worldPos, int screenWidth, int screenHeight, bool& outBehindCamera) const
{
    // Transform to clip space
    glm::vec4 clipPos = projectionMatrix * viewMatrix * glm::vec4(worldPos, 1.0f);

    // Si w <= 0 el punto está detrás de la cámara
    if (clipPos.w <= 0.0f) {
        outBehindCamera = true;
        return glm::vec2(0.0f);
    }
    outBehindCamera = false;

    // NDC [-1, 1]
    glm::vec3 ndc = glm::vec3(clipPos) / clipPos.w;

    // Pixels to camera
    float sx = (ndc.x * 0.5f + 0.5f) * screenWidth;
    float sy = (1.0f - (ndc.y * 0.5f + 0.5f)) * screenHeight;  

    return glm::vec2(sx, sy);
}