#include "Renderer.h"
#include "Application.h"
#include "GameObject.h"
#include "Transform.h"
#include "ComponentMesh.h"
#include "ComponentCanvas.h"
#include "ComponentSkinnedMesh.h"
#include "ComponentMaterial.h"
#include "ModuleEditor.h"
#include "ResourceShader.h"
#include "ComponentParticleSystem.h"
#include "ComponentCamera.h"
#include "CameraLens.h"
#include "ComponentPostProcessing.h"
#include "Texture.h"
#include "Material.h"
#include "MaterialStandard.h"

#include "Shader.h"
#include "ShaderDepthVisualization.h"
#include "ShaderLines.h"
#include "ShaderMesh.h"
#include "ShaderNormal.h"
#include "ShaderNoTexture.h"
#include "ShaderPicking.h"
#include "ShaderSimpleColor.h"
#include "ShaderSingleColor.h"
#include "ShaderStandard.h"
#include "ShaderUiOverlay.h"
#include "ShaderWater.h"
#include "ShaderPostPorcessing.h"

#include "LightManager.h"
#include "ComponentLight.h"

#include <glad/glad.h>
#include <glm/gtc/type_ptr.hpp>
#include <stack>
#include <algorithm>

Renderer::Renderer()
{
    LOG_DEBUG("Renderer Constructor");
}

Renderer::~Renderer()
{

}

bool Renderer::Start()
{
    LOG_DEBUG("=== Initializing Renderer Module ===");
    LOG_CONSOLE("Initializing renderer and shaders...");

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_STENCIL_TEST);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
    glEnable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    defaultShader = make_unique<ShaderNoTexture>();
    if (!defaultShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create default shader");
        LOG_CONSOLE("ERROR: Failed to compile shaders");
        return false;
    }
    
    standardShader = make_unique<ShaderStandard>();
    if (!standardShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create standard shader");
        LOG_CONSOLE("ERROR: Failed to compile shaders");
        return false;
    }

    lineShader = make_unique<ShaderLines>();
    if (!lineShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create line shader");
        LOG_CONSOLE("ERROR: Failed to compile line shader");
        return false;
    }

    outlineShader = make_unique<ShaderSingleColor>();
    if (!outlineShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create outline shader");
        LOG_CONSOLE("ERROR: Failed to compile outline shader");
        return false;
    }

    waterShader = make_unique<ShaderWater>();
    if (!waterShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create water shader");
        LOG_CONSOLE("ERROR: Failed to compile water shader");
        return false;
    }

    normalsShader = make_unique<ShaderNormal>();
    if (!normalsShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create normals shader");
        LOG_CONSOLE("ERROR: Failed to compile normals shader");
        return false;
    }

    meshShader = make_unique<ShaderMesh>();
    if (!meshShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create mesh shader");
        LOG_CONSOLE("ERROR: Failed to compile mesh shader");
        return false;
    }

    depthShader = make_unique<ShaderDepthVisualization>();
    if (!depthShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create depth visualization shader");
        LOG_CONSOLE("ERROR: Failed to compile depth shader");
        return false;
    }

    pickingShader = make_unique<ShaderPicking>();
    if (!pickingShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create picking shader");
        LOG_CONSOLE("ERROR: Failed to compile picking shader");
    }
    // UI overlay shader
    uiShader = make_unique<ShaderUiOverlay>();
    if (!uiShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create UI overlay shader");
        LOG_CONSOLE("ERROR: Failed to compile UI overlay shader");
        return false;
    }
    
    postProcessShader = make_unique<ShaderPostPorcessing>();
    if (!postProcessShader->CreateShader())
    {
        LOG_DEBUG("ERROR: Failed to create post processing shader");
        LOG_CONSOLE("ERROR: Failed to compile post processing shader");
        return false;
    }

    lightManager = std::make_unique<LightManager>();

    // Fullscreen quad VAO for UI overlay
    float quadVerts[] = {
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f,
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
    };
    glGenVertexArrays(1, &quadVAO);
    glGenBuffers(1, &quadVBO);
    glBindVertexArray(quadVAO);
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVerts), quadVerts, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glBindVertexArray(0);

    glGenBuffers(1, &ssboBones);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboBones);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 0, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssboBones);

    glGenBuffers(1, &uboMatrices);
    glBindBuffer(GL_UNIFORM_BUFFER, uboMatrices);
    glBufferData(GL_UNIFORM_BUFFER, 2 * sizeof(glm::mat4), NULL, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, uboMatrices);

    defaultTexture = make_unique<Texture>();
    defaultTexture->CreateCheckerboard();
    LOG_DEBUG("Default checkerboard texture created");

    defaultUniforms.projection = glGetUniformLocation(defaultShader->GetProgramID(), "projection");
    defaultUniforms.view = glGetUniformLocation(defaultShader->GetProgramID(), "view");
    defaultUniforms.model = glGetUniformLocation(defaultShader->GetProgramID(), "model");
    defaultUniforms.texture1 = glGetUniformLocation(defaultShader->GetProgramID(), "texture1");

    outlineUniforms.projection = glGetUniformLocation(outlineShader->GetProgramID(), "projection");
    outlineUniforms.view = glGetUniformLocation(outlineShader->GetProgramID(), "view");
    outlineUniforms.model = glGetUniformLocation(outlineShader->GetProgramID(), "model");

    LOG_DEBUG("Renderer initialized successfully");
    LOG_CONSOLE("Renderer ready");

    return true;
}

bool Renderer::PreUpdate()
{
    bool ret = true;

    stencilList.clear();
    linesList.clear();
    normalsList.clear();
    meshLinesList.clear();

    return ret;
}

void Renderer::LoadMesh(Mesh& mesh)
{
    // Create and configure VAO
    glGenVertexArrays(1, &mesh.VAO);
    glBindVertexArray(mesh.VAO);

    // Upload vertex data to GPU
    glGenBuffers(1, &mesh.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, mesh.VBO);
    glBufferData(GL_ARRAY_BUFFER, mesh.vertices.size() * sizeof(Vertex), &mesh.vertices[0], GL_STATIC_DRAW);

    // Configure vertex attributes
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, normal));

    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, texCoords));

    glEnableVertexAttribArray(3);
    glVertexAttribIPointer(3, 4, GL_INT, sizeof(Vertex), (void*)offsetof(Vertex, boneIDs));

    glEnableVertexAttribArray(4);
    glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, weights));

    glEnableVertexAttribArray(5);
    glVertexAttribPointer(5, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, tangent));

    // Upload index data
    glGenBuffers(1, &mesh.EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, mesh.indices.size() * sizeof(unsigned int), &mesh.indices[0], GL_STATIC_DRAW);

    glBindVertexArray(0);

    LOG_DEBUG("Mesh loaded - VAO: %d, Vertices: %d, Indices: %d", mesh.VAO, mesh.vertices.size(), mesh.indices.size());
}

void Renderer::UnloadMesh(Mesh& mesh)
{
    if (mesh.VAO != 0)
    {
        glDeleteVertexArrays(1, &mesh.VAO);
        mesh.VAO = 0;
    }

    if (mesh.VBO != 0)
    {
        glDeleteBuffers(1, &mesh.VBO);
        mesh.VBO = 0;
    }

    if (mesh.EBO != 0)
    {
        glDeleteBuffers(1, &mesh.EBO);
        mesh.EBO = 0;
    }
}

void Renderer::DrawMesh(const ComponentMesh* meshComp)
{
    if (meshComp->GetMesh().VAO == 0) return;

    GLint currentProgram;
    glGetIntegerv(GL_CURRENT_PROGRAM, &currentProgram);

    if (meshComp->HasSkinning())
    {
        ComponentSkinnedMesh* skinnedComp = (ComponentSkinnedMesh*)meshComp;

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, skinnedComp->GetSSBOGlobal());
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, skinnedComp->GetSSBOOffset());

        glUniform1i(glGetUniformLocation(currentProgram, "hasBones"), true);

        glUniformMatrix4fv(glGetUniformLocation(currentProgram, "meshInverse"), 1, GL_FALSE,
            glm::value_ptr(skinnedComp->GetMeshInverse()));
    }
    else
    {
        glUniform1i(glGetUniformLocation(currentProgram, "hasBones"), false);
    }

    glBindVertexArray(meshComp->GetMesh().VAO);
    glDrawElements(GL_TRIANGLES, (GLsizei)meshComp->GetNumIndices(), GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);

    if (meshComp->HasSkinning())
    {
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, 0);
        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, 0);
    }
}

// Renderer.cpp

void Renderer::AddMesh(ComponentMesh* mesh) {
    if (mesh->IsType(ComponentType::SKINNED_MESH)) {
        skinnedMeshes.push_back(static_cast<ComponentSkinnedMesh*>(mesh));
    }
    else {
        meshes.push_back(mesh);
    }
    if (lightManager) lightManager->MarkShadowsDirty();
}

void Renderer::RemoveMesh(ComponentMesh* mesh) {
    if (mesh->HasSkinning()) {
        auto* skinned = static_cast<ComponentSkinnedMesh*>(mesh);
        auto it = std::find(skinnedMeshes.begin(), skinnedMeshes.end(), skinned);
        if (it != skinnedMeshes.end()) {
            *it = skinnedMeshes.back();
            skinnedMeshes.pop_back();
        }
    }
    else {
        auto it = std::find(meshes.begin(), meshes.end(), mesh);
        if (it != meshes.end()) {
            *it = meshes.back();
            meshes.pop_back();
        }
    }
    if (lightManager) lightManager->MarkShadowsDirty();
}
void Renderer::AddParticle(ComponentParticleSystem* particle) {
    particles.push_back(particle);
}

void Renderer::AddSkinnedMesh(ComponentSkinnedMesh* mesh) {
    skinnedMeshes.push_back(mesh);
    if (lightManager) lightManager->MarkShadowsDirty();
}

void Renderer::RemoveSkinnedMesh(ComponentSkinnedMesh* mesh) {
    auto it = std::find(skinnedMeshes.begin(), skinnedMeshes.end(), mesh);
    if (it != skinnedMeshes.end()) {
        *it = skinnedMeshes.back();
        skinnedMeshes.pop_back();
    }
    if (lightManager) lightManager->MarkShadowsDirty();
}

void Renderer::RemoveParticle(ComponentParticleSystem* particle) {
    auto it = std::find(particles.begin(), particles.end(), particle);
    if (it != particles.end()) {
        *it = particles.back();
        particles.pop_back();
    }
}

void Renderer::AddCamera(CameraLens* camera)
{
    auto it = std::find(activeCameras.begin(), activeCameras.end(), camera);

    if (it == activeCameras.end())
    {
        activeCameras.push_back(camera);
    }
}

void Renderer::RemoveCamera(CameraLens* camera)
{
    auto it = std::find(activeCameras.begin(), activeCameras.end(), camera);
    if (it != activeCameras.end())
    {
        activeCameras.erase(it);
    }
}

void Renderer::AddCanvas(ComponentCanvas* canvas)
{
    auto it = std::find(activeCanvas.begin(), activeCanvas.end(), canvas);

    if (it == activeCanvas.end())
    {
        activeCanvas.push_back(canvas);
    }
}

void Renderer::RemoveCanvas(ComponentCanvas* canvas)
{
    auto it = std::find(activeCanvas.begin(), activeCanvas.end(), canvas);
    if (it != activeCanvas.end())
    {
        activeCanvas.erase(it);
    }
}

void Renderer::AddPostProcessing(ComponentPostProcessing* component)
{
    postProcessingComponents.push_back(component);
}

void Renderer::RemovePostProcessing(ComponentPostProcessing* component)
{
    auto it = std::find(postProcessingComponents.begin(), postProcessingComponents.end(), component);
    if (it != postProcessingComponents.end()) {
        postProcessingComponents.erase(it);
    }
}

bool Renderer::PostUpdate()
{
    bool ret = true;

    int width = 0, height = 0;
    Application::GetInstance().window->GetWindowSize(width, height);

    for (CameraLens* camera : activeCameras)
    {
        RenderScene(camera);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, width, height);
    
    glDisable(GL_SCISSOR_TEST);
    glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    return ret;
}

bool Renderer::RenderScene(CameraLens* camera)
{
    if (!camera) return false;

    int width = 0, height = 0;
    if (camera->fboID == 0)
        Application::GetInstance().window->GetWindowSize(width, height);
    else {
        width  = camera->textureWidth;
        height = camera->textureHeight;
    }

    bool usingMSAA = msaaEnabled && camera->msaaFBO != 0;

    if (usingMSAA) {
        glBindFramebuffer(GL_FRAMEBUFFER, camera->msaaFBO);
        glEnable(GL_MULTISAMPLE);
    }
    else {
        glBindFramebuffer(GL_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
        glDisable(GL_MULTISAMPLE);
    }

    glViewport(0, 0, width, height);

    //Clear buffers
    glDisable(GL_SCISSOR_TEST);
    glClearColor(clearColorR, clearColorG, clearColorB, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glClearStencil(0);

    //Camera Matrices
    UpdateViewMatrix(camera->GetViewMatrix());
    UpdateProjectionMatrix(camera->GetProjectionMatrix());
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, uboMatrices);

    // Primero actualizar las matrices de skinning
    for (ComponentMesh* mesh : meshes)
        mesh->UpdateSkinningMatrices();

    for (ComponentSkinnedMesh* mesh : skinnedMeshes)
        mesh->UpdateSkinningMatrices();

    // Ahora el shadow pass tiene los SSBOs actualizados
    if (lightManager)
        lightManager->BuildShadowMap(meshes, skinnedMeshes);

    //Build Render List
    opaqueList.clear();
    transparentList.clear();
    particlesList.clear();
    canvasList.clear();
    BuildRenderLists(camera);

    if (showZBuffer) {
        depthShader->Use();
        depthShader->SetFloat("nearPlane", camera->GetNearPlane());
        depthShader->SetFloat("farPlane",  camera->GetFarPlane());
    }
    else {
        defaultShader->Use();
    }

    glEnable(GL_STENCIL_TEST);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);

    glEnable(GL_DEPTH_TEST);
    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glEnable(GL_CULL_FACE);
    DrawRenderList(opaqueList, camera);

    glEnable(GL_BLEND);
    glDepthMask(GL_FALSE);
    DrawRenderList(transparentList, camera);
    DrawParticlesList(camera);

    if (camera->GetDebugCamera()) {
        Application::GetInstance().physics->DrawDebug();
        DrawStencilList(camera);
        DrawNormalsList(camera);
        DrawMeshLinesList(camera);
        DrawLinesList(camera);
    }

    glDisable(GL_STENCIL_TEST);
    glStencilMask(0xFF);
    glStencilFunc(GL_ALWAYS, 0, 0xFF);
    glEnable(GL_DEPTH_TEST);
    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glEnable(GL_CULL_FACE);
    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);


    if (usingMSAA) {
        GLuint targetFBO = (camera->fboID != 0) ? camera->fboID : 0;
        glBindFramebuffer(GL_READ_FRAMEBUFFER, camera->msaaFBO);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, targetFBO);
        glBlitFramebuffer(0, 0, width, height, 0, 0, width, height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glDisable(GL_MULTISAMPLE);
    }

    DrawPostProcessing(camera);
    DrawCanvasList(camera);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return true;
}

void Renderer::BuildRenderLists(const CameraLens* camera)
{
    for (ComponentMesh* mesh : meshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->transform) continue;
        if (!mesh->owner->IsActive()) continue;

        const Mesh& resMesh = mesh->GetMesh();
        if (!resMesh.IsValid()) continue;

        glm::mat4 globalModelMatrix = mesh->owner->transform->GetGlobalMatrix();

        const AABB& globalAABB = mesh->GetGlobalAABB();

        if (camera->GetFrustum()->InFrustum(mesh->GetGlobalAABB()))
        {
            //mesh->UpdateSkinningMatrices();

            RenderObject renderObject = { mesh, globalModelMatrix };

            glm::vec3 aabbCenter = (globalAABB.min + globalAABB.max) * 0.5f;
            float distanceToCamera = glm::distance(aabbCenter, camera->position);

            if (mesh->GetAttachedMaterial() && mesh->GetAttachedMaterial()->IsActive() && mesh->GetAttachedMaterial()->GetOpacity() != 1.0f)
            {
                transparentList.emplace(distanceToCamera, renderObject);
            }
            else
            {
                opaqueList.push_back(renderObject);
            }
        }
    }

    // Al final de BuildRenderLists, después del loop de meshes:
    for (ComponentSkinnedMesh* mesh : skinnedMeshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->transform) continue;
        if (!mesh->owner->IsActive()) continue;

        const Mesh& resMesh = mesh->GetMesh();
        if (!resMesh.IsValid()) continue;

        glm::mat4 globalModelMatrix = mesh->owner->transform->GetGlobalMatrix();
        const AABB& globalAABB = mesh->GetGlobalAABB();

        if (camera->GetFrustum()->InFrustum(globalAABB))
        {
            RenderObject renderObject = { mesh, globalModelMatrix };

            glm::vec3 aabbCenter = (globalAABB.min + globalAABB.max) * 0.5f;
            float distanceToCamera = glm::distance(aabbCenter, camera->position);

            if (mesh->GetAttachedMaterial() && mesh->GetAttachedMaterial()->IsActive()
                && mesh->GetAttachedMaterial()->GetOpacity() != 1.0f)
                transparentList.emplace(distanceToCamera, renderObject);
            else
                opaqueList.push_back(renderObject);
        }
    }

    for (ComponentParticleSystem* ps : particles)
    {
        if (!ps || !ps->owner || !ps->owner->transform) continue;
        if (!ps->IsActive() || !ps->GetEmitter()) continue;

        ParticleObject pObj;
        pObj.system = ps;

        if (ps->GetEmitter()->simulationSpace == SimulationSpace::LOCAL) {
            pObj.modelMatrix = ps->owner->transform->GetGlobalMatrix();
        }
        else {
            pObj.modelMatrix = glm::mat4(1.0f);
        }

        glm::vec3 pos = ps->owner->transform->GetGlobalPosition();
        float distanceToCamera = glm::distance(pos, camera->position);

        particlesList.emplace(distanceToCamera, pObj);
    }

    for (ComponentCanvas* canvas : activeCanvas)
    {
        if (!canvas->IsActive() || !canvas->GetOwner()->IsActive()) continue;
        if (canvas->GetUILayer() != camera->GetUiCullingMask()) continue;

        CanvasObject canvasObject;
        canvasObject.canvas = canvas;

        canvasList.push_back(canvasObject);
    }
    std::sort(opaqueList.begin(), opaqueList.end(), [](const RenderObject& a, const RenderObject& b) {
        auto* matA = a.mesh->GetAttachedMaterial() ? a.mesh->GetAttachedMaterial()->GetMaterial() : nullptr;
        auto* matB = b.mesh->GetAttachedMaterial() ? b.mesh->GetAttachedMaterial()->GetMaterial() : nullptr;
        return matA < matB;
        });
}

void Renderer::DrawPostProcessing(const CameraLens* camera)
{
    if (!camera->IsUsingPostProcessing()) return;

    ComponentPostProcessing* activePP = nullptr;
    for (auto* pp : postProcessingComponents) {
        if (pp->IsActive() && pp->owner && pp->owner->IsActive()) {
            activePP = pp; break;
        }
    }

    if (!activePP) return;

    ResizePostProcessingBuffer(camera->textureWidth, camera->textureHeight);

    glBindFramebuffer(GL_READ_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, postProcessFBO);
    glBlitFramebuffer(0, 0, camera->textureWidth, camera->textureHeight,
        0, 0, camera->textureWidth, camera->textureHeight,
        GL_COLOR_BUFFER_BIT, GL_NEAREST);

    glBindFramebuffer(GL_FRAMEBUFFER, camera->fboID);

    postProcessShader->Use();

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, postProcessTexture);
    postProcessShader->SetInt("sceneTexture", 0);

    // Color Grading
    postProcessShader->SetBool("gradingEnabled", activePP->colorGrading.enabled);
    postProcessShader->SetFloat("exposure", activePP->colorGrading.exposure);
    postProcessShader->SetFloat("contrast", activePP->colorGrading.contrast);
    postProcessShader->SetFloat("saturation", activePP->colorGrading.saturation);
    postProcessShader->SetInt("toneMapper", activePP->colorGrading.toneMapper);
    postProcessShader->SetFloat("gamma", activePP->colorGrading.gamma);
    postProcessShader->SetFloat("temperature", activePP->colorGrading.temperature);
    postProcessShader->SetFloat("tint", activePP->colorGrading.tint);
    postProcessShader->SetVec3("colorFilter", activePP->colorGrading.colorFilter);

    // Bloom
    postProcessShader->SetBool("bloomEnabled", activePP->bloom.enabled);
    postProcessShader->SetFloat("bloomIntensity", activePP->bloom.intensity);
    postProcessShader->SetFloat("bloomThreshold", activePP->bloom.threshold);
    postProcessShader->SetFloat("bloomSoftKnee", activePP->bloom.softKnee);
    postProcessShader->SetVec3("bloomTint", activePP->bloom.tint);

    // Chromatic Aberration
    postProcessShader->SetBool("caEnabled", activePP->lens.chromaticAberrationEnabled);
    postProcessShader->SetFloat("caIntensity", activePP->lens.chromaticAberrationIntensity);

    // Vignette
    postProcessShader->SetBool("vignetteEnabled", activePP->lens.vignetteEnabled);
    postProcessShader->SetFloat("vignetteIntensity", activePP->lens.vignetteIntensity);
    postProcessShader->SetFloat("vignetteSmoothness", activePP->lens.vignetteSmoothness);
    postProcessShader->SetFloat("vignetteRoundness", activePP->lens.vignetteRoundness);
    postProcessShader->SetVec4("vignetteColor", activePP->lens.vignetteColor);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glBindVertexArray(quadVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
    glUseProgram(0);
}

void Renderer::DrawRenderList(const std::vector<RenderObject>& list, const CameraLens* camera)
{
    // Upload luces al standardShader
    if (lightManager && standardShader)
    {
        standardShader->Use();
        lightManager->UploadToShader(standardShader.get());
        standardShader->SetMat4("lightSpaceMatrix", lightManager->GetLightSpaceMatrix());
        standardShader->SetInt("uShadowMap", 5);
    }

    Shader* lastShader = nullptr;
    Material* lastMaterial = nullptr;

    for (const RenderObject& renderObject : list)
    {
        ComponentMesh* meshComp = renderObject.mesh;
        ComponentMaterial* materialComp = meshComp->GetAttachedMaterial();

        if (meshComp->GetDrawNormals()) normalsList.push_back(renderObject);
        if (meshComp->GetDrawMesh()) meshLinesList.push_back(renderObject);
        if (meshComp->owner->IsSelected()) {
            stencilList.push_back(renderObject);
            glStencilFunc(GL_ALWAYS, 1, 0xFF);
            glStencilMask(0xFF);
        }
        else {
            glStencilFunc(GL_ALWAYS, 0, 0xFF);
            glStencilMask(0x00);
        }

        Shader* currentShader = defaultShader.get();
        Material* currentMaterial = nullptr;

        if (materialComp) {
            currentMaterial = materialComp->GetMaterial();
            if (currentMaterial && currentMaterial->GetType() == MaterialType::STANDARD)
                currentShader = standardShader.get();
        }

        if (currentShader != lastShader) {
            currentShader->Use();
            lastShader = currentShader;

            currentShader->SetVec3("viewPos", camera->position);
            currentShader->SetVec3("lightDir", lightDir);

            if (currentShader == standardShader.get()) {
                glActiveTexture(GL_TEXTURE7);
                glBindTexture(GL_TEXTURE_2D, lightManager->GetShadowMapID());
                currentShader->SetInt("uShadowMap", 7);
                currentShader->SetMat4("lightSpaceMatrix", lightManager->GetLightSpaceMatrix());
            }
        }

        currentShader->SetMat4("model", renderObject.globalModelMatrix);

        if (currentMaterial != lastMaterial) {
            if (currentMaterial)
                currentMaterial->Bind(currentShader);
            else {
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, defaultTexture->GetID());
            }
            lastMaterial = currentMaterial;
        }

        DrawMesh(meshComp);
    }
}

void Renderer::DrawRenderList(const std::multimap<float, RenderObject>& map, const CameraLens* camera)
{
    // Upload luces al standardShader
    if (lightManager && standardShader)
    {
        standardShader->Use();
        lightManager->UploadToShader(standardShader.get());
        standardShader->SetMat4("lightSpaceMatrix", lightManager->GetLightSpaceMatrix());
        standardShader->SetInt("uShadowMap", 5);
    }

    Shader* lastShader = nullptr;
    Material* lastMaterial = nullptr;
    UID lastMaterialUID = 0;

    for (auto pair = map.rbegin(); pair != map.rend(); ++pair)
    {
        const RenderObject& renderObject = pair->second;
        ComponentMesh* meshComp = renderObject.mesh;
        ComponentMaterial* materialComp = meshComp->GetAttachedMaterial();

        if (meshComp->GetDrawNormals()) normalsList.push_back(renderObject);
        if (meshComp->GetDrawMesh()) meshLinesList.push_back(renderObject);
        if (meshComp->owner->IsSelected()) {
            stencilList.push_back(renderObject);
            glStencilFunc(GL_ALWAYS, 1, 0xFF);
            glStencilMask(0xFF);
        }
        else {
            glStencilFunc(GL_ALWAYS, 0, 0xFF);
            glStencilMask(0x00);
        }

        Shader* currentShader = defaultShader.get();
        Material* currentMaterial = nullptr;

        if (materialComp) {
            currentMaterial = materialComp->GetMaterial();
            if (currentMaterial && currentMaterial->GetType() == MaterialType::STANDARD)
                currentShader = standardShader.get();
        }

        if (currentShader != lastShader) {
            currentShader->Use();
            lastShader = currentShader;

            currentShader->SetVec3("viewPos", camera->position);
            currentShader->SetVec3("lightDir", lightDir);

            // Re-bindear shadow map cada vez que se activa standardShader
            if (currentShader == standardShader.get()) {
                glActiveTexture(GL_TEXTURE7);
                glBindTexture(GL_TEXTURE_2D, lightManager->GetShadowMapID());
                currentShader->SetInt("uShadowMap", 7);
                currentShader->SetMat4("lightSpaceMatrix", lightManager->GetLightSpaceMatrix());
            }
        }

        currentShader->SetMat4("model", renderObject.globalModelMatrix);

        UID currentUID = currentMaterial
            ? static_cast<MaterialStandard*>(currentMaterial)->GetAlbedoMapUID()
            : 0;

        if (currentUID != lastMaterialUID || currentUID == 0) {
            if (currentMaterial)
                currentMaterial->Bind(currentShader);
            else {
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, defaultTexture->GetID());
            }
            lastMaterial = currentMaterial;
            lastMaterialUID = currentUID;
        }

        DrawMesh(meshComp);
    }
}
void Renderer::DrawParticlesList(const CameraLens* camera)
{
    if (particlesList.empty()) return;

    glUseProgram(0);

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadMatrixf(glm::value_ptr(camera->GetProjectionMatrix()));

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadMatrixf(glm::value_ptr(camera->GetViewMatrix()));

    ComponentCamera* mainCam = Application::GetInstance().camera->GetMainCamera();
    glm::vec3 billboardPos = (mainCam && mainCam->GetLens())
        ? mainCam->GetLens()->position
        : camera->position;

    for (const auto& pair : particlesList)
    {
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glMultMatrixf(glm::value_ptr(pair.second.modelMatrix));

        pair.second.system->GetEmitter()->Draw(billboardPos);

        glPopMatrix();
    }

    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
}

void Renderer::DrawCanvasList(const CameraLens* camera)
{
    if (canvasList.empty()) return;

    // Asegurarse de renderizar en el FBO correcto
    glBindFramebuffer(GL_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
    glViewport(0, 0, camera->textureWidth, camera->textureHeight);

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    uiShader->Use();
    glBindVertexArray(quadVAO);

    for (CanvasObject& canvasObject : canvasList)
    {
        ComponentCanvas* c = canvasObject.canvas;
        c->Resize(camera->textureWidth, camera->textureHeight);
        c->Update();
        c->RenderToTexture();

        glBindFramebuffer(GL_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
        glViewport(0, 0, camera->textureWidth, camera->textureHeight);

        // Restaurar TODO el estado que Noesis rompe
        glUseProgram(0);
        glBindVertexArray(0);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        uiShader->Use();
        glBindVertexArray(quadVAO);  // ? Re-bindear despu�s de limpiar

        glBindTexture(GL_TEXTURE_2D, c->GetTextureID());
        uiShader->SetInt("uTexture", 0);
        uiShader->SetFloat("uOpacity", c->GetOpacity());

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glBindVertexArray(0);
    glUseProgram(0);
}
void Renderer::DrawStencilList(const CameraLens* camera)
{
    if (stencilList.empty()) return;

    GLboolean depthWriteEnabled;
    glGetBooleanv(GL_DEPTH_WRITEMASK, &depthWriteEnabled);

    glEnable(GL_STENCIL_TEST);
    glDisable(GL_CULL_FACE);

    for (RenderObject renderObject : stencilList)
    {
        ComponentMesh* meshComp = renderObject.mesh;

        glClear(GL_STENCIL_BUFFER_BIT);


        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);

        glDisable(GL_DEPTH_TEST);
        glDepthMask(GL_FALSE);

        defaultShader->Use();
        glUniformMatrix4fv(glGetUniformLocation(defaultShader->GetProgramID(), "model"), 1, GL_FALSE, glm::value_ptr(renderObject.globalModelMatrix));
        DrawMesh(meshComp);

        glStencilFunc(GL_NOTEQUAL, 1, 0xFF);
        glStencilMask(0x00);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

        glDisable(GL_DEPTH_TEST);

        outlineShader->Use();
        glUniformMatrix4fv(outlineUniforms.projection, 1, GL_FALSE, glm::value_ptr(camera->GetProjectionMatrix()));
        glUniformMatrix4fv(outlineUniforms.view, 1, GL_FALSE, glm::value_ptr(camera->GetViewMatrix()));
        glUniformMatrix4fv(outlineUniforms.model, 1, GL_FALSE, glm::value_ptr(renderObject.globalModelMatrix));

        outlineShader->SetVec3("outlineColor", glm::vec3(1.0f, 0.41f, 0.71f));
        outlineShader->SetFloat("outlineThickness", 0.04f);

        DrawMesh(meshComp);
    }

    glDepthMask(depthWriteEnabled);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glDisable(GL_STENCIL_TEST);
}

void Renderer::DrawNormalsList(const CameraLens* camera)
{
    if (normalsList.empty()) return;

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);

    normalsShader->Use();
    normalsShader->SetVec4("lineColor", glm::vec4(0.0f, 1.0f, 1.0f, 1.0f));

    for (RenderObject renderObject : normalsList)
    {
        ComponentMesh* meshComp = renderObject.mesh;

        glUniformMatrix4fv(glGetUniformLocation(normalsShader->GetProgramID(), "model"),
            1, GL_FALSE, glm::value_ptr(renderObject.globalModelMatrix));

        if (meshComp->HasSkinning())
        {
            ComponentSkinnedMesh* skinned = (ComponentSkinnedMesh*)meshComp;
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, skinned->GetSSBOGlobal());
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, skinned->GetSSBOOffset());
            normalsShader->SetBool("hasBones", true);
            normalsShader->SetMat4("meshInverse", skinned->GetMeshInverse());
        }
        else
        {
            normalsShader->SetBool("hasBones", false);
        }

        glBindVertexArray(meshComp->GetMesh().VAO);
        glDrawArrays(GL_POINTS, 0, (GLsizei)meshComp->GetMesh().vertices.size());

        glBindVertexArray(0);
    }
}

void Renderer::DrawMeshLinesList(const CameraLens* camera)
{
    if (meshLinesList.empty()) return;

    meshShader->Use();
    meshShader->SetVec4("lineColor", glm::vec4(1.0f, 1.0f, 1.0f, 1.0f));

    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glEnable(GL_POLYGON_OFFSET_LINE);
    glPolygonOffset(-1.0f, -1.0f);

    for (RenderObject renderObject : meshLinesList)
    {
        ComponentMesh* meshComp = renderObject.mesh;

        meshShader->SetMat4("model", renderObject.globalModelMatrix);

        if (meshComp->HasSkinning()) {
            ComponentSkinnedMesh* skinned = (ComponentSkinnedMesh*)meshComp;
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, skinned->GetSSBOGlobal());
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, skinned->GetSSBOOffset());
            meshShader->SetBool("hasBones", true);
            meshShader->SetMat4("meshInverse", skinned->GetMeshInverse());
        }
        else {
            meshShader->SetBool("hasBones", false);
        }

        glBindVertexArray(meshComp->GetMesh().VAO);
        glDrawElements(GL_TRIANGLES, (GLsizei)meshComp->GetNumIndices(), GL_UNSIGNED_INT, 0);
    }

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glDisable(GL_POLYGON_OFFSET_LINE);
    glBindVertexArray(0);
}



bool Renderer::CleanUp()
{
    LOG_DEBUG("Cleaning up Renderer");

    UnloadMesh(sphere);
    UnloadMesh(cylinder);
    UnloadMesh(pyramid);

    if (defaultShader)  defaultShader->Delete();
    if (lineShader)     lineShader->Delete();
    if (outlineShader)  outlineShader->Delete();
    if (depthShader)    depthShader->Delete();
    if (waterShader)    waterShader->Delete();
    if (uiShader)       uiShader->Delete();

    if (quadVAO != 0)
    {
        glDeleteVertexArrays(1, &quadVAO);
        glDeleteBuffers(1, &quadVBO);
        quadVAO = 0;
        quadVBO = 0;
    }

    if (normalLinesVAO != 0)
    {
        glDeleteVertexArrays(1, &normalLinesVAO);
        glDeleteBuffers(1, &normalLinesVBO);
    }

    if (postProcessFBO != 0) {
        glDeleteFramebuffers(1, &postProcessFBO);
        glDeleteTextures(1, &postProcessTexture);
        glDeleteRenderbuffers(1, &postProcessRBO);
        postProcessFBO = 0;
        postProcessTexture = 0;
        postProcessRBO = 0;
        postProcessCurrentW = 0;  
        postProcessCurrentH = 0;
    }
    if (postProcessShader) postProcessShader->Delete();

    meshes.clear();
    skinnedMeshes.clear();
    activeCameras.clear();
    postProcessingComponents.clear();
    opaqueList.clear();
    transparentList.clear();
    stencilList.clear();
    normalsList.clear();
    meshLinesList.clear();
    linesList.clear();

    LOG_DEBUG("Renderer cleaned up successfully");
    LOG_CONSOLE("Renderer shutdown complete");

    return true;
}

void Renderer::ResizePostProcessingBuffer(int width, int height)
{
    if (postProcessFBO == 0) {
        glGenFramebuffers(1, &postProcessFBO);
        glGenTextures(1, &postProcessTexture);
        glGenRenderbuffers(1, &postProcessRBO);
        postProcessCurrentW = 0;
        postProcessCurrentH = 0;
    }

    if (postProcessCurrentW != width || postProcessCurrentH != height) {
        glBindFramebuffer(GL_FRAMEBUFFER, postProcessFBO);

        glBindTexture(GL_TEXTURE_2D, postProcessTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, width, height, 0, GL_RGBA, GL_FLOAT, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, postProcessTexture, 0);

        glBindRenderbuffer(GL_RENDERBUFFER, postProcessRBO);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, postProcessRBO);

        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE)
            LOG_DEBUG("ERROR: postProcessFBO incomplete: 0x%x", status);

        postProcessCurrentW = width;
        postProcessCurrentH = height;
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void Renderer::CreateSkinningSSBOs(unsigned int& ssboGlobal, unsigned int& ssboOffset, const std::vector<glm::mat4>& offsets)
{
    size_t numBones = offsets.size();

    if (ssboOffset == 0) glGenBuffers(1, &ssboOffset);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOffset);
    glBufferData(GL_SHADER_STORAGE_BUFFER, numBones * sizeof(glm::mat4), offsets.data(), GL_STATIC_DRAW);

    if (ssboGlobal == 0) glGenBuffers(1, &ssboGlobal);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboGlobal);

    glBufferData(GL_SHADER_STORAGE_BUFFER, numBones * sizeof(glm::mat4), nullptr, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void Renderer::UploadGlobalMatricesToGPU(unsigned int ssbo, const std::vector<glm::mat4>& globalMatrices)
{
    if (ssbo == 0) return;

    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, globalMatrices.size() * sizeof(glm::mat4), globalMatrices.data());
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void Renderer::DeleteSSBO(unsigned int& ssbo)
{
    if (ssbo != 0)
    {
        glDeleteBuffers(1, &ssbo);
        ssbo = 0;
    }
}



void Renderer::DrawLinesList(const CameraLens* camera)
{
    if (linesList.empty() || !camera) return;

    GLuint lineVAO, lineVBO;
    glGenVertexArrays(1, &lineVAO);
    glGenBuffers(1, &lineVBO);

    glBindVertexArray(lineVAO);
    glBindBuffer(GL_ARRAY_BUFFER, lineVBO);

    std::vector<float> vertexData;
    vertexData.reserve(linesList.size() * 2 * 7);

    for (const auto& line : linesList)
    {
        // Punto A
        vertexData.push_back(line.start.x); vertexData.push_back(line.start.y); vertexData.push_back(line.start.z);
        vertexData.push_back(line.color.r); vertexData.push_back(line.color.g); vertexData.push_back(line.color.b); vertexData.push_back(line.color.a);

        // Punto B
        vertexData.push_back(line.end.x); vertexData.push_back(line.end.y); vertexData.push_back(line.end.z);
        vertexData.push_back(line.color.r); vertexData.push_back(line.color.g); vertexData.push_back(line.color.b); vertexData.push_back(line.color.a);
    }

    glEnable(GL_DEPTH_TEST);
    glDepthMask(GL_TRUE);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    lineShader->Use();
    GLuint shaderProgram = lineShader->GetProgramID();

    glBindVertexArray(lineVAO);
    glBindBuffer(GL_ARRAY_BUFFER, lineVBO);
    glBufferData(GL_ARRAY_BUFFER, vertexData.size() * sizeof(float), vertexData.data(), GL_STREAM_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 7 * sizeof(float), (void*)0);

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 7 * sizeof(float), (void*)(3 * sizeof(float)));

    glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "projection"), 1, GL_FALSE, glm::value_ptr(camera->GetProjectionMatrix()));
    glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "view"), 1, GL_FALSE, glm::value_ptr(camera->GetViewMatrix()));
    glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "model"), 1, GL_FALSE, glm::value_ptr(glm::mat4(1.0f)));

    glDrawArrays(GL_LINES, 0, (GLsizei)linesList.size() * 2);

    glBindVertexArray(0);
    glUseProgram(0);
}


void Renderer::SetDepthTest(bool enabled)
{
    depthTestEnabled = enabled;
    if (enabled)
        glEnable(GL_DEPTH_TEST);
    else
        glDisable(GL_DEPTH_TEST);

    LOG_DEBUG("Depth test %s", enabled ? "enabled" : "disabled");
}

void Renderer::SetFaceCulling(bool enabled)
{
    faceCullingEnabled = enabled;
    if (enabled)
        glEnable(GL_CULL_FACE);
    else
        glDisable(GL_CULL_FACE);

    LOG_DEBUG("Face culling %s", enabled ? "enabled" : "disabled");
}

void Renderer::SetWireframeMode(bool enabled)
{
    wireframeMode = enabled;
    if (enabled)
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    else
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    LOG_DEBUG("Wireframe mode %s", enabled ? "enabled" : "disabled");
}

void Renderer::SetClearColor(float r, float g, float b)
{
    clearColorR = r;
    clearColorG = g;
    clearColorB = b;
    LOG_DEBUG("Clear color set to (%.2f, %.2f, %.2f)", r, g, b);
}

void Renderer::SetCullFaceMode(int mode)
{
    cullFaceMode = mode;

    switch (mode)
    {
    case 0: glCullFace(GL_BACK); break;
    case 1: glCullFace(GL_FRONT); break;
    case 2: glCullFace(GL_FRONT_AND_BACK); break;
    default: glCullFace(GL_BACK); break;
    }

    const char* modeStr[] = { "Back", "Front", "Front and Back" };
    LOG_DEBUG("Cull face mode set to: %s", modeStr[mode]);
}

void Renderer::ApplyRenderSettings()
{
    SetDepthTest(depthTestEnabled);
    SetFaceCulling(faceCullingEnabled);
    SetWireframeMode(wireframeMode);
    SetCullFaceMode(cullFaceMode);
}

void Renderer::DrawLine(const glm::vec3& start, const glm::vec3& end, const glm::vec4& color)
{
    linesList.push_back({ start, end, color });
}

void Renderer::DrawSphere(const glm::vec3& center, float radius, const glm::vec4& color, int segments)
{
    float step = 2.0f * glm::pi<float>() / (float)segments;

    for (int i = 0; i < segments; ++i)
    {
        float a1 = i * step;
        float a2 = (i + 1) * step;

        DrawLine(center + glm::vec3(radius * cos(a1), radius * sin(a1), 0),
            center + glm::vec3(radius * cos(a2), radius * sin(a2), 0), color);
        DrawLine(center + glm::vec3(radius * cos(a1), 0, radius * sin(a1)),
            center + glm::vec3(radius * cos(a2), 0, radius * sin(a2)), color);
        DrawLine(center + glm::vec3(0, radius * cos(a1), radius * sin(a1)),
            center + glm::vec3(0, radius * cos(a2), radius * sin(a2)), color);
    }
}

void Renderer::DrawArc(glm::vec3 center, glm::quat rotation, float r, int segments, glm::vec4 col, glm::vec3 axisA, glm::vec3 axisB)
{
    float angleStep = 3.14159f / segments;

    for (int i = 0; i < segments; ++i)
    {
        float a1 = i * angleStep;
        float a2 = (i + 1) * angleStep;

        glm::vec3 p1 = center + (rotation * ((axisA * cos(a1) + axisB * sin(a1)) * r));
        glm::vec3 p2 = center + (rotation * ((axisA * cos(a2) + axisB * sin(a2)) * r));

        DrawLine(p1, p2, col);
    }
}

void Renderer::DrawCircle(glm::vec3 center, glm::quat rotation, float r, int segments, glm::vec4 col, glm::vec3 axisA, glm::vec3 axisB)
{
    float angleStep = (2.0f * 3.14159f) / segments;

    for (int i = 0; i < segments; ++i)
    {
        float angle1 = i * angleStep;
        float angle2 = (i + 1) * angleStep;

        glm::vec3 p1_local = (axisA * cos(angle1) + axisB * sin(angle1)) * r;
        glm::vec3 p2_local = (axisA * cos(angle2) + axisB * sin(angle2)) * r;

        glm::vec3 p1_world = center + (rotation * p1_local);
        glm::vec3 p2_world = center + (rotation * p2_local);

        DrawLine(p1_world, p2_world, col);
    }
}

void Renderer::UpdateProjectionMatrix(glm::mat4 pm) {
    glBindBuffer(GL_UNIFORM_BUFFER, uboMatrices);
    glBufferSubData(GL_UNIFORM_BUFFER, sizeof(glm::mat4), sizeof(glm::mat4), glm::value_ptr(pm));
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
}

void Renderer::UpdateViewMatrix(glm::mat4 vm) {
    glBindBuffer(GL_UNIFORM_BUFFER, uboMatrices);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(glm::mat4), glm::value_ptr(vm));
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
}

UID Renderer::GetObjectInPixel(const CameraLens* camera, int x, int y)
{
    if (!camera) return 0;

    GLint last_viewport[4]; glGetIntegerv(GL_VIEWPORT, last_viewport);
    GLint last_fbo; glGetIntegerv(GL_FRAMEBUFFER_BINDING, &last_fbo);

    glBindFramebuffer(GL_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
    glViewport(0, 0, camera->textureWidth, camera->textureHeight);

    UpdateViewMatrix(camera->GetViewMatrix());
    UpdateProjectionMatrix(camera->GetProjectionMatrix());

    glBindBufferBase(GL_UNIFORM_BUFFER, 0, uboMatrices);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);

    pickingShader->Use();
    std::map<uint32_t, UID> pickingMap;
    uint32_t nextID = 1;

    for (ComponentMesh* meshComponent : meshes)
    {
        if (!meshComponent || !meshComponent->owner->IsActive()) continue;

        Mesh& mesh = meshComponent->GetMesh();
        if (mesh.VAO == 0) continue;

        if (!camera->GetFrustum()->InFrustum(meshComponent->GetGlobalAABB())) continue;

        UID realUID = meshComponent->owner->GetUID();
        uint32_t currentPickingID = nextID++;
        pickingMap[currentPickingID] = realUID;

        glm::vec4 pickingColor = {
            ((currentPickingID & 0x000000FF) >> 0) / 255.0f,
            ((currentPickingID & 0x0000FF00) >> 8) / 255.0f,
            ((currentPickingID & 0x00FF0000) >> 16) / 255.0f,
            ((currentPickingID & 0xFF000000) >> 24) / 255.0f
        };

        pickingShader->SetVec4("pickingColor", pickingColor);

        glm::mat4 model = meshComponent->owner->transform->GetGlobalMatrix();
        pickingShader->SetMat4("model", model);


        if (meshComponent->HasSkinning())
        {
            ComponentSkinnedMesh* skinned = (ComponentSkinnedMesh*)meshComponent;
            pickingShader->SetMat4("meshInverse", skinned->GetMeshInverse());
            pickingShader->SetBool("hasBones", true);

            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, skinned->GetSSBOGlobal());
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, skinned->GetSSBOOffset());
        }
        else
        {
            pickingShader->SetBool("hasBones", false);

        }

        glBindVertexArray(mesh.VAO);
        glDrawElements(GL_TRIANGLES, (GLsizei)mesh.indices.size(), GL_UNSIGNED_INT, 0);
    }

    int readX = x;
    int readY = camera->textureHeight - y;

    unsigned char pixel[4];
    glReadPixels(readX, readY, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);

    uint32_t idFound = (uint32_t)pixel[0] |
        ((uint32_t)pixel[1] << 8) |
        ((uint32_t)pixel[2] << 16) |
        ((uint32_t)pixel[3] << 24);

    UID finalUID = 0;
    if (idFound > 0 && pickingMap.find(idFound) != pickingMap.end()) {
        finalUID = pickingMap[idFound];
    }

    glBindFramebuffer(GL_FRAMEBUFFER, last_fbo);
    glViewport(last_viewport[0], last_viewport[1], last_viewport[2], last_viewport[3]);
    glEnable(GL_BLEND);
    glUseProgram(0);
    glBindVertexArray(0);

    return finalUID;
}


void Renderer::SetMSAA(bool enabled) {
    msaaEnabled = enabled;
    if (msaaEnabled)
        glEnable(GL_MULTISAMPLE);
    else
        glDisable(GL_MULTISAMPLE);
}

void Renderer::DrawFullscreenTexture(unsigned int textureID)
{
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    uiShader->Use();

    uiShader->SetFloat("uOpacity", 1.0f);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureID);
    uiShader->SetInt("uTexture", 0);

    glBindVertexArray(quadVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    glBindVertexArray(0);
    glUseProgram(0);
    glEnable(GL_DEPTH_TEST);
}

void Renderer::AddLight(ComponentLight* light)
{
    if (lightManager) lightManager->RegisterLight(light);
}

void Renderer::RemoveLight(ComponentLight* light)
{
    if (lightManager) lightManager->UnregisterLight(light);
}