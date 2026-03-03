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
#include "CameraLens.h"
#include "ModulePhysics.h"
#include <glad/glad.h>
#include <glm/gtc/type_ptr.hpp>
#include <stack>

#include "tracy/Tracy.hpp"

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

    defaultShader = make_unique<Shader>();
    if (!defaultShader->CreateNoTexture())
    {
        LOG_DEBUG("ERROR: Failed to create default shader");
        LOG_CONSOLE("ERROR: Failed to compile shaders");
        return false;
    }
    else
    {
        LOG_DEBUG("Shader created successfully - Program ID: %d", defaultShader->GetProgramID());
        LOG_CONSOLE("OpenGL shaders compiled successfully");
    }

    lineShader = make_unique<Shader>();
    if (!lineShader->CreateLinesShader())
    {
        LOG_DEBUG("ERROR: Failed to create line shader");
        LOG_CONSOLE("ERROR: Failed to compile line shader");
        return false;
    }
    else
    {
        LOG_DEBUG("Line shader created successfully - Program ID: %d", lineShader->GetProgramID());
        LOG_CONSOLE("Line shader compiled successfully");
    }

    outlineShader = make_unique<Shader>();
    if (!outlineShader->CreateSingleColor())
    {
        LOG_DEBUG("ERROR: Failed to create outline shader");
        LOG_CONSOLE("ERROR: Failed to compile outline shader");
        return false;
    }
    else
    {
        LOG_DEBUG("Outline shader created successfully - Program ID: %d", outlineShader->GetProgramID());
        LOG_CONSOLE("Outline shader compiled successfully");
    }

    waterShader = make_unique<Shader>();
    if (!waterShader->CreateWater())
    {
        LOG_DEBUG("ERROR: Failed to create water shader");
        LOG_CONSOLE("ERROR: Failed to compile water shader");
        return false;
    }
    else
    {
        LOG_DEBUG("Water shader created successfully - Program ID: %d", waterShader->GetProgramID());
        LOG_CONSOLE("Water shader compiled successfully");
    }

    normalsShader = make_unique<Shader>();
    if (!normalsShader->CreateNormalShader())
    {
        LOG_DEBUG("ERROR: Failed to create normals shader");
        LOG_CONSOLE("ERROR: Failed to compile normals shader");
        return false;
    }
    else
    {
        LOG_DEBUG("normals shader created successfully - Program ID: %d", normalsShader->GetProgramID());
        LOG_CONSOLE("normals shader compiled successfully");
    }

    meshShader = make_unique<Shader>();
    if (!meshShader->CreateMeshShader())
    {
        LOG_DEBUG("ERROR: Failed to create mesh shader");
        LOG_CONSOLE("ERROR: Failed to compile mesh shader");
        return false;
    }
    else
    {
        LOG_DEBUG("mesh shader created successfully - Program ID: %d", meshShader->GetProgramID());
        LOG_CONSOLE("mesh shader compiled successfully");
    }

    depthShader = make_unique<Shader>();
    if (!depthShader->CreateDepthVisualization())
    {
        LOG_DEBUG("ERROR: Failed to create depth visualization shader");
        LOG_CONSOLE("ERROR: Failed to compile depth shader");
        return false;
    }
    else
    {
        LOG_DEBUG("depth shader created successfully - Program ID: %d", depthShader->GetProgramID());
        LOG_CONSOLE("depth shader compiled successfully");
    }

    pickingShader = make_unique<Shader>();
    if (!pickingShader->CreatePickingShader())
    {
        LOG_DEBUG("ERROR: Failed to create picking shader");
        LOG_CONSOLE("ERROR: Failed to compile picking shader");
    }
    else
    {
        LOG_DEBUG("picking shader created successfully - Program ID: %d", pickingShader->GetProgramID());
        LOG_CONSOLE("picking shader compiled successfully");
    }

    // UI overlay shader
    uiShader = make_unique<Shader>();
    if (!uiShader->CreateUIOverlay())
    {
        LOG_DEBUG("ERROR: Failed to create UI overlay shader");
        LOG_CONSOLE("ERROR: Failed to compile UI overlay shader");
        return false;
    }
    else
    {
        LOG_DEBUG("UI overlay shader created successfully - Program ID: %d", uiShader->GetProgramID());
        LOG_CONSOLE("UI overlay shader compiled successfully");
    }

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

void Renderer::AddMesh(ComponentMesh* mesh) {
    meshes.push_back(mesh);
}

void Renderer::RemoveMesh(ComponentMesh* mesh) {
    auto it = std::find(meshes.begin(), meshes.end(), mesh);
    if (it != meshes.end()) {
        *it = meshes.back();
        meshes.pop_back();
    }
}

void Renderer::AddParticle(ComponentParticleSystem* particle) {
    particles.push_back(particle);
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
    activeCameras.push_back(camera);
}

void Renderer::RemoveCamera(CameraLens* camera)
{
    auto it = std::remove(activeCameras.begin(), activeCameras.end(), camera);
    activeCameras.erase(it, activeCameras.end());
}

bool Renderer::PostUpdate()
{
    bool ret = true;

#ifndef WAVE_GAME
    for (CameraLens* camera : activeCameras)
    {
        RenderScene(camera);
    }

    int width = 0, height = 0;
    Application::GetInstance().window->GetWindowSize(width, height);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, width, height);
    glDisable(GL_SCISSOR_TEST);
    glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
#else
    auto* cameraModule = Application::GetInstance().camera.get();
    if (cameraModule)
    {
        ComponentCamera* mainCam = cameraModule->GetMainCamera();
        if (mainCam)
        {
            CameraLens* mainLens = mainCam->GetLens();
            if (mainLens)
            {
                GLuint savedFBO = mainLens->fboID;
                mainLens->fboID = 0;
                RenderScene(mainLens);
                mainLens->fboID = savedFBO;
            }
        }
    }

    int winWidth = 0, winHeight = 0;
    Application::GetInstance().window->GetWindowSize(winWidth, winHeight);
    // Update y render de todos los canvas a sus texturas
    auto& canvasList = Application::GetInstance().ui->GetCanvas();
    for (ComponentCanvas* c : canvasList)
    {
        c->Resize(winWidth, winHeight);
        if (!c->IsActive() || !c->GetOwner()->IsActive()) continue;
        c->Update();
        c->RenderToTexture();
    }

    // Dibujar canvas como overlay encima del framebuffer 0
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    uiShader->Use();
    glBindVertexArray(quadVAO);

    for (ComponentCanvas* c : canvasList)
    {
        if (!c->IsActive() || !c->GetOwner()->IsActive()) continue;
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, c->GetTextureID());
        uiShader->SetInt("uTexture", 0);
        uiShader->SetFloat("uOpacity", c->GetOpacity());
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    glBindVertexArray(0);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glUseProgram(0);
#endif

    return ret;
}
bool Renderer::RenderScene(CameraLens* camera)
{
    if (!camera) return false;

    int width = 0;
    int height = 0;

    //VIEWPORT SIZE
    if (camera->fboID == 0)
    {
        Application::GetInstance().window->GetWindowSize(width, height);
    }
    else
    {
        width = camera->textureWidth;
        height = camera->textureHeight;
    }
    glViewport(0, 0, width, height);

    //BIND FRAMEBUFFER
    bool usingMSAA = msaaEnabled && camera->msaaFBO != 0;
    if (usingMSAA) {
        glBindFramebuffer(GL_FRAMEBUFFER, camera->msaaFBO);
        glEnable(GL_MULTISAMPLE);
    }
    else {
        glBindFramebuffer(GL_FRAMEBUFFER, (camera->fboID != 0) ? camera->fboID : 0);
        glDisable(GL_MULTISAMPLE);
    }

    //CLEAN BUFFERS
    glDisable(GL_SCISSOR_TEST);
    glEnable(GL_MULTISAMPLE);
    glClearColor(clearColorR, clearColorG, clearColorB, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glClearStencil(0);

    //UPDATE CAM MATRIX 
    UpdateViewMatrix(camera->GetViewMatrix());
    UpdateProjectionMatrix(camera->GetProjectionMatrix());

    glBindBufferBase(GL_UNIFORM_BUFFER, 0, uboMatrices);

    //CLEAN LIST AND BUILD NEWS
    opaqueList.clear();
    transparentList.clear();
    particlesList.clear();

    BuildRenderLists(camera);

    if (showZBuffer)
    {
        depthShader->Use();
        depthShader->SetFloat("nearPlane", camera->GetNearPlane());
        depthShader->SetFloat("farPlane", camera->GetFarPlane());
    }
    else
    {
        defaultShader->Use();
    }

    //CONFIG OPENGL
    glEnable(GL_STENCIL_TEST);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);

    //RENDER OPAQUES
    glEnable(GL_DEPTH_TEST);
    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glEnable(GL_CULL_FACE);
    DrawRenderList(opaqueList, camera);

    //RENDER TRANSPARENT
    glEnable(GL_BLEND);
    glDepthMask(GL_FALSE);
    DrawRenderList(transparentList, camera);

    DrawParticlesList(camera);

    //RENDER DEBUG
    if (camera->GetDebugCamera())
    {
        Application::GetInstance().physics->DrawDebug();
        DrawStencilList(camera);
        DrawNormalsList(camera);
        DrawMeshLinesList(camera);
        DrawLinesList(camera);
    }

    //RESET STATES
    glDisable(GL_STENCIL_TEST);
    glStencilMask(0xFF);
    glStencilFunc(GL_ALWAYS, 0, 0xFF);
    glEnable(GL_DEPTH_TEST);
    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glEnable(GL_CULL_FACE);

    if (msaaEnabled && camera->msaaFBO != 0)
    {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, camera->msaaFBO);
        GLuint targetFBO = (camera->fboID != 0) ? camera->fboID : 0;
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, targetFBO);
        glBlitFramebuffer(0, 0, camera->textureWidth, camera->textureHeight, 0, 0, width, height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glUseProgram(0);

    return true;
}

void Renderer::BuildRenderLists(const CameraLens* camera)
{
    for (ComponentMesh* mesh : meshes)
    {
        if (!mesh || !mesh->owner || !mesh->owner->transform) continue;
        if (!mesh->owner->IsActive()) continue;

        Mesh resMesh = mesh->GetMesh();
        if (!resMesh.IsValid()) continue;

        glm::mat4 globalModelMatrix = mesh->owner->transform->GetGlobalMatrix();

        const AABB& globalAABB = mesh->GetGlobalAABB();

        if (/*camera->GetFrustum()->InFrustum(mesh->GetGlobalAABB())*/true)
        {
            mesh->UpdateSkinningMatrices();

            RenderObject renderObject = { mesh, globalModelMatrix };

            glm::vec3 aabbCenter = (globalAABB.min + globalAABB.max) * 0.5f;
            float distanceToCamera = glm::distance(aabbCenter, camera->position);

            if (mesh->GetAttachedMaterial() && mesh->GetAttachedMaterial()->IsActive() && mesh->GetAttachedMaterial()->GetOpacity() < 1.0f)
            {
                transparentList.emplace(distanceToCamera, renderObject);
            }
            else
            {
                opaqueList.emplace(distanceToCamera, renderObject);
            }
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
}

void Renderer::DrawRenderList(const std::multimap<float, RenderObject>& map, const CameraLens* camera)
{
    for (auto pair = map.rbegin(); pair != map.rend(); ++pair)
    {
        RenderObject renderObject = pair->second;
        ComponentMesh* meshComp = renderObject.mesh;

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

        ComponentMaterial* materialComp = meshComp->GetAttachedMaterial();
        materialComp->Use();

        GLint currentProgram;
        glGetIntegerv(GL_CURRENT_PROGRAM, &currentProgram);
        glUniform3fv(glGetUniformLocation(currentProgram, "lightDir"), 1, glm::value_ptr(lightDir));
        glUniform3fv(glGetUniformLocation(currentProgram, "viewPos"), 1, glm::value_ptr(camera->position));

        glUniform1i(glGetUniformLocation(currentProgram, "texture1"), 0);
        glUniform1i(glGetUniformLocation(currentProgram, "hasTexture"), true);
        glUniformMatrix4fv(glGetUniformLocation(currentProgram, "model"), 1, GL_FALSE, glm::value_ptr(renderObject.globalModelMatrix));

        if (materialComp) {
            glUniform3fv(glGetUniformLocation(currentProgram, "materialDiffuse"), 1, glm::value_ptr(materialComp->GetDiffuseColor()));
            glUniform1f(glGetUniformLocation(currentProgram, "opacity"), materialComp->GetOpacity());
        }

        DrawMesh(meshComp);
    }
}

void Renderer::DrawParticlesList(const CameraLens* camera)
{
    if (particlesList.empty()) return;

    // 1. IMPORTANTE: Desactivar cualquier shader activo para usar el pipeline fijo
    glUseProgram(0);

    // 2. Configuraci�n de matrices legacy (necesaria para glBegin/glEnd)
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadMatrixf(glm::value_ptr(camera->GetProjectionMatrix()));

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadMatrixf(glm::value_ptr(camera->GetViewMatrix()));

    for (const auto& pair : particlesList)
    {
        // Aplicar la matriz de modelo de la entidad (si es LOCAL)
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glMultMatrixf(glm::value_ptr(pair.second.modelMatrix));

        pair.second.system->GetEmitter()->Draw(camera->position);

        glPopMatrix();
    }

    // 3. Restaurar matrices
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
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

    meshes.clear();
    activeCameras.clear();
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

        if (/*!camera->GetFrustum()->InFrustum(meshComponent->GetGlobalAABB())*/false) continue;

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
        glDrawElements(GL_TRIANGLES, mesh.indices.size(), GL_UNSIGNED_INT, 0);
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