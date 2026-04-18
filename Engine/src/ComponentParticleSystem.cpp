#include "ComponentParticleSystem.h"
#include "GameObject.h"
#include "Application.h"
#include "ModuleCamera.h"
#include "ComponentCamera.h"
#include "Transform.h"
#include "ModuleResources.h" 
#include "ResourceTexture.h"
#include "LibraryManager.h"
#include "Time.h" 
#include "FileSystem.h"
#include "ModuleScene.h"
#include "AssetsWindow.h"
#include <fstream>
#include <iomanip> 
#include <imgui.h>
#include <glad/glad.h> 
#include <glm/gtc/type_ptr.hpp>
#include <filesystem>

ComponentParticleSystem::ComponentParticleSystem(GameObject* owner)
    : Component(owner, ComponentType::PARTICLE)
{
    name = "Particle System";
    emitter = new EmitterInstance();
    emitter->Init(); // Initialize default modules
    Application::GetInstance().renderer.get()->AddParticle(this);
}

ComponentParticleSystem::~ComponentParticleSystem() {
    Application::GetInstance().renderer.get()->RemoveParticle(this);
    // Release texture resource reference
    if (textureResourceUID != 0) {
        Application::GetInstance().resources->ReleaseResource(textureResourceUID);
    }
    // CleanUp memory
    if (emitter) {
        delete emitter;
        emitter = nullptr;
    }
}

void ComponentParticleSystem::Update() {
    // Update feedback message timer
    if (feedbackTimer > 0.0f) {
        feedbackTimer -= Application::GetInstance().time->GetRealDeltaTime();
    }

    // Connection with transform and prewarm
    Transform* trans = dynamic_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
    if (trans) {
        const glm::mat4& globalMatrix = trans->GetGlobalMatrix();
        glm::vec3 globalPos = glm::vec3(globalMatrix[3]); // Extract translation

        // Pass global position to the emitter, used for RateOverDistance and World Space
        emitter->ownerPosition = globalPos;

        // Update Spawner module position (Legacy sync)
        for (auto mod : emitter->modules) {
            if (mod->type == ParticleModuleType::SPAWNER) {
                static_cast<ModuleEmitterSpawn*>(mod)->spawnPosition = globalPos;
            }
        }
    }

    // Only update simulation on PLAY mode
    if (Application::GetInstance().GetPlayState() != Application::PlayState::PLAYING) return;
    // Proximity activation
    if (emitter->proximityActivation) {
        UpdateProximityActivation();
    }

    // Prewarm logic, instant simulation at start
    if (emitter->prewarm && emitter->systemTime == 0.0f) {
        float simStep = 0.1f;
        float simTime = 2.0f; // Simulate 2 seconds instantly
        for (float t = 0; t < simTime; t += simStep) {
            emitter->Update(simStep);
        }
    }

    float dt = Application::GetInstance().time->GetDeltaTime();
    emitter->Update(dt);
}

void ComponentParticleSystem::UpdateProximityActivation() {
    // If it's the first time it searches the target and saves it cached
    if (!proximityTargetSearched) {
        proximityTargetSearched = true;
        proximityTargetCache = Application::GetInstance().scene->FindObject(emitter->proximityTarget);
    }

    if (!proximityTargetCache || proximityTargetCache->IsMarkedForDeletion()) {
        // Target disappeared or not found
        proximityTargetSearched = false;
        proximityTargetCache = nullptr;
        return;
    }

    Transform* targetTrans = static_cast<Transform*>(
        proximityTargetCache->GetComponent(ComponentType::TRANSFORM));
    if (!targetTrans) return;

    float dist = glm::distance(emitter->ownerPosition,
        glm::vec3(targetTrans->GetGlobalMatrix()[3]));

    bool shouldBeActive = (dist <= emitter->activationRadius);

    if (shouldBeActive && !emitter->active) {
        // Player in the radius
        emitter->Play();
    }
    else if (!shouldBeActive && emitter->active) {
        // Player left the radius
        emitter->Stop();
    }
}

void ComponentParticleSystem::Draw(ComponentCamera* camera) {
    if (!active || !emitter) return;

    // Don't draw because there are no particles and every emitter is stopped
    if (emitter->particles.empty() && !emitter->active) return;

    glUseProgram(0);
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    // Setup Legacy Matrices
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(glm::value_ptr(camera->GetProjectionMatrix()));

    glMatrixMode(GL_MODELVIEW);
    glm::mat4 viewMatrix = camera->GetViewMatrix();
    glLoadMatrixf(glm::value_ptr(viewMatrix));

    // Simulation space logic in render
    if (emitter->simulationSpace == SimulationSpace::LOCAL) {
        // In LOCAL, we apply the object's matrix. Particles move with it
        Transform* trans = dynamic_cast<Transform*>(owner->GetComponent(ComponentType::TRANSFORM));
        if (trans) {
            glm::mat4 globalMat = trans->GetGlobalMatrix();
            glMultMatrixf(glm::value_ptr(globalMat));
            glm::mat4 invGlobal = glm::inverse(globalMat);
            glm::vec3 camWorld = camera->owner->transform->GetGlobalPosition();
            glm::vec3 camLocal = glm::vec3(invGlobal * glm::vec4(camWorld, 1.0f));
            emitter->Draw(camLocal);
            return;
        }
    }
    // WORLD space: camera and particle positions are both world-space, pass directly
    emitter->Draw(camera->owner->transform->GetGlobalPosition());
}

// Scripting
void ComponentParticleSystem::Play() {
    if (!emitter) return;
    emitter->Play();
    active = true;
}

void ComponentParticleSystem::Stop() {
    if (!emitter) return;
    emitter->Stop();
}

void ComponentParticleSystem::ScriptBurst(int count) {
    if (!emitter) return;
    // Burst called from script forces particles even if the emitter was stopped
    bool wasActive = emitter->active;
    emitter->active = true;
    emitter->Burst(count);
    emitter->active = wasActive;
}

void ComponentParticleSystem::SetEmissionRate(float rate) {
    if (!emitter) return;
    emitter->emissionRate = rate;
}

bool ComponentParticleSystem::IsPlaying() const {
    return emitter && emitter->active && !emitter->stopEmittingFlag;
}

bool ComponentParticleSystem::IsAlive() const {
    return emitter && emitter->IsAlive();
}

void ComponentParticleSystem::SetLooping(bool looping) {
    if (!emitter) return;
    emitter->looping = looping;
    if (looping) emitter->stopEmittingFlag = false;
}

void ComponentParticleSystem::SetDuration(float seconds) {
    if (!emitter) return;
    emitter->duration = seconds;
}

void ComponentParticleSystem::SetOneShotMode(bool enabled, int count) {
    if (!emitter) return;
    emitter->oneShot = enabled;
    emitter->oneShotCount = count;
    emitter->oneShotFired = false;
}

void ComponentParticleSystem::OnEditor() {

#ifndef WAVE_GAME
    // Control buttons
    ImGui::Checkbox("Active", &active);
    ImGui::SameLine();
    if (ImGui::Button("Reset Simulation")) emitter->Reset();
    ImGui::SameLine();
    if (ImGui::Button("Reset Values")) emitter->ResetValues();

    // Selector Texture
    ImGui::Separator();
    ImGui::Text("Texture & Animation");

    std::string currentTexName = emitter->texturePath.empty() ? "None (Drop Texture Here)" : emitter->texturePath;
    size_t lastSlash = currentTexName.find_last_of("/\\");
    if (lastSlash != std::string::npos) currentTexName = currentTexName.substr(lastSlash + 1);

    // Clear texture button
    if (ImGui::Button("X##ClearTex")) {
        SetTexture("");
    }
    ImGui::SameLine();

    // Drop button zone
    ImGui::Button(currentTexName.c_str(), ImVec2(ImGui::GetContentRegionAvail().x, 20));

    if (ImGui::BeginDragDropTarget()) {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("ASSET_ITEM")) {
            DragDropPayload* dropData = (DragDropPayload*)payload->Data;
            if (dropData->assetType == DragDropAssetType::TEXTURE) {
                SetTexture(dropData->assetPath);
            }
        }
        ImGui::EndDragDropTarget();
    }

    // Animation Settings
    ImGui::DragInt("Rows", &emitter->textureRows, 0.1f, 1, 16);
    ImGui::DragInt("Columns", &emitter->textureCols, 0.1f, 1, 16);
    ImGui::DragFloat("Animation Speed", &emitter->animationSpeed, 0.05f, 0.0f, 10.0f, "%.2fx");
    ImGui::Checkbox("Loop Animation", &emitter->animLoop);

    // Global Settings
    ImGui::Separator();
    ImGui::Text("System Settings");

    const char* spaceItems[] = { "Local", "World" };
    int currentSpace = (int)emitter->simulationSpace;
    if (ImGui::Combo("Simulation Space", &currentSpace, spaceItems, IM_ARRAYSIZE(spaceItems))) {
        emitter->simulationSpace = (SimulationSpace)currentSpace;
    }

    ImGui::Checkbox("Prewarm", &emitter->prewarm);
    ImGui::DragInt("Max Particles", &emitter->maxParticles, 1, 0, 10000);
    ImGui::DragFloat("Emission Rate (Time)", &emitter->emissionRate, 0.1f, 0.0f, 1000.0f);
    ImGui::DragFloat("Emission Rate (Dist)", &emitter->emissionRateDistance, 0.1f, 0.0f, 100.0f);

    // Duration and Looping
    ImGui::Separator();
    ImGui::Text("Duration & Playback");

    ImGui::Checkbox("Looping", &emitter->looping);
    if (!emitter->looping) {
        ImGui::DragFloat("Duration (s)", &emitter->duration, 0.05f, 0.05f, 60.0f, "%.2f s");
    }

    // oneShot mode
    ImGui::Checkbox("One Shot", &emitter->oneShot);
    if (emitter->oneShot) {
        ImGui::DragInt("One Shot Count", &emitter->oneShotCount, 1, 1, 1000);
        ImGui::TextColored(ImVec4(1, 1, 0, 1),
            "One-shot: %d particles on Play()", emitter->oneShotCount);
    }

    // Proximity Activation
    ImGui::Separator();
    ImGui::Text("Proximity Activation");

    ImGui::Checkbox("Enable Proximity Activation", &emitter->proximityActivation);
    if (emitter->proximityActivation) {
        static char proxBuf[64];
        // Init buffer from current value
        strncpy_s(proxBuf, emitter->proximityTarget.c_str(), sizeof(proxBuf) - 1);
        if (ImGui::InputText("Target Name", proxBuf, sizeof(proxBuf))) {
            emitter->proximityTarget = proxBuf;
            // Reset cache so the new target is searched next frame
            proximityTargetCache = nullptr;
            proximityTargetSearched = false;
        }
        ImGui::DragFloat("Activation Radius", &emitter->activationRadius,
            0.5f, 0.5f, 200.0f, "%.1f u");
        ImGui::TextColored(ImVec4(0.5f, 1.0f, 0.5f, 1.0f),
            "Auto on/off when '%s' is within %.1f units",
            emitter->proximityTarget.c_str(), emitter->activationRadius);
    }

    // Bursts UI
    if (ImGui::TreeNode("Bursts Configuration")) {
        if (ImGui::Button("+ Add Burst")) {
            emitter->bursts.push_back(Burst());
        }

        for (int i = 0; i < (int)emitter->bursts.size(); ++i) {
            ImGui::PushID(i);
            ImGui::Text("Burst %d", i);
            ImGui::SameLine();
            if (ImGui::Button("X")) {
                emitter->bursts.erase(emitter->bursts.begin() + i);
                ImGui::PopID();
                continue;
            }

            ImGui::DragFloat("Time", &emitter->bursts[i].time, 0.1f, 0.0f, 10.0f);
            ImGui::DragInt("Count", &emitter->bursts[i].count, 1, 1, 1000);
            ImGui::DragInt("Cycles", &emitter->bursts[i].cycles, 1, 0, 100);
            ImGui::DragFloat("Interval", &emitter->bursts[i].repeatInterval, 0.1f, 0.0f, 10.0f);
            ImGui::Separator();
            ImGui::PopID();
        }
        ImGui::TreePop();
    }

    ImGui::Checkbox("Additive Blending (Glow)", &emitter->additiveBlending);
    ImGui::SameLine();
    ImGui::Checkbox("Luminance Blending (Black&White texture)", &emitter->luminanceBlending);

    // Module settings
    ModuleEmitterSpawn* spawner = nullptr;
    ModuleEmitterNoise* noise = nullptr;

    for (auto m : emitter->modules) {
        if (m->type == ParticleModuleType::SPAWNER) spawner = (ModuleEmitterSpawn*)m;
        if (m->type == ParticleModuleType::NOISE)   noise = (ModuleEmitterNoise*)m;
    }

    // Spawner UI
    if (spawner && ImGui::CollapsingHeader("Spawner Module", ImGuiTreeNodeFlags_DefaultOpen)) {
        const char* shapeItems[] = { "Box", "Sphere", "Cone", "Circle" };
        int currentShape = (int)spawner->shape;
        if (ImGui::Combo("Emitter Shape", &currentShape, shapeItems, IM_ARRAYSIZE(shapeItems))) {
            spawner->shape = (EmitterShape)currentShape;
        }

        // Dynamic parameters based on shape
        if (spawner->shape == EmitterShape::BOX) {
            ImGui::DragFloat3("Box Area", &spawner->emissionArea.x, 0.1f, 0.0f, 10.0f);
        }
        else if (spawner->shape == EmitterShape::SPHERE) {
            ImGui::DragFloat("Radius", &spawner->emissionRadius, 0.1f, 0.0f, 10.0f);
            ImGui::Checkbox("Emit From Shell", &spawner->emitFromShell);
        }
        else if (spawner->shape == EmitterShape::CONE) {
            ImGui::DragFloat("Base Radius", &spawner->coneRadius, 0.1f);
            ImGui::SliderFloat("Cone Angle", &spawner->coneAngle, 0.0f, 90.0f);
            ImGui::Checkbox("Emit From Shell", &spawner->emitFromShell);
        }
        else if (spawner->shape == EmitterShape::CIRCLE) {
            ImGui::DragFloat("Circle Radius", &spawner->circleRadius, 0.1f);
            ImGui::Checkbox("Emit From Edge", &spawner->emitFromShell);
        }

        ImGui::Separator();
        ImGui::Text("Lifecycle & Physics");
        ImGui::DragFloat2("Lifetime (Min/Max)", &spawner->lifetimeMin, 0.1f, 0.1f, 10.0f);
        ImGui::DragFloat2("Speed (Min/Max)", &spawner->speedMin, 0.1f, 0.0f, 50.0f);
        ImGui::DragFloat("Size Start", &spawner->sizeStart, 0.01f, 0.0f, 10.0f);
        ImGui::DragFloat("Size End", &spawner->sizeEnd, 0.01f, 0.0f, 10.0f);
        ImGui::DragFloat2("Spin Speed (Min/Max)", &spawner->rotationSpeedMin, 1.0f, -360.0f, 360.0f);

        // The size curve settings overrides Start/End when is not empty
        if (ImGui::TreeNode("Size Curve Editor")) {
            if (!spawner->sizeCurve.empty())
                ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "[ACTIVE] Overrides Start/End values");
            else
                ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "[INACTIVE] Using linear Start -> End");

            if (ImGui::Button("+ Add Key")) {
                SizeKey key;
                key.time = spawner->sizeCurve.empty() ? 0.5f
                    : glm::clamp(spawner->sizeCurve.back().time + 0.2f, 0.0f, 1.0f);
                key.size = spawner->sizeStart > 0.0f ? spawner->sizeStart : 0.5f;
                spawner->sizeCurve.push_back(key);
                std::sort(spawner->sizeCurve.begin(), spawner->sizeCurve.end(),
                    [](const SizeKey& a, const SizeKey& b) { return a.time < b.time; });
            }
            ImGui::SameLine();
            if (ImGui::Button("Clear Curve"))
                spawner->sizeCurve.clear();
            ImGui::SameLine();
            if (ImGui::Button("Preset: 0 - 1 - 0 Size")) {
                spawner->sizeCurve.clear();
                float peak = spawner->sizeStart > 0.0f ? spawner->sizeStart : 0.5f;
                spawner->sizeCurve.push_back({ 0.0f,  0.0f });
                spawner->sizeCurve.push_back({ 0.35f, peak });
                spawner->sizeCurve.push_back({ 1.0f,  0.0f });
            }

            bool curveChanged = false;
            for (int i = 0; i < (int)spawner->sizeCurve.size(); ++i) {
                ImGui::PushID(i + 200);
                ImGui::SetNextItemWidth(120.0f);
                if (ImGui::SliderFloat("t", &spawner->sizeCurve[i].time, 0.0f, 1.0f))
                    curveChanged = true;
                ImGui::SameLine();
                ImGui::SetNextItemWidth(100.0f);
                ImGui::DragFloat("size", &spawner->sizeCurve[i].size, 0.01f, 0.0f, 20.0f);
                ImGui::SameLine();
                if (ImGui::Button("X")) {
                    spawner->sizeCurve.erase(spawner->sizeCurve.begin() + i);
                    ImGui::PopID();
                    continue;
                }
                ImGui::PopID();
            }
            if (curveChanged) {
                std::sort(spawner->sizeCurve.begin(), spawner->sizeCurve.end(),
                    [](const SizeKey& a, const SizeKey& b) { return a.time < b.time; });
            }
            ImGui::TreePop();
        }

        ImGui::Separator();
        ImGui::Text("Color over Lifetime");

        ImGui::ColorEdit3("Start Color", &spawner->colorStart.r);
        ImGui::DragFloat("Start Alpha", &spawner->colorStart.a, 0.01f, 0.0f, 1.0f);

        ImGui::Spacing();

        ImGui::ColorEdit3("End Color", &spawner->colorEnd.r);
        ImGui::DragFloat("End Alpha", &spawner->colorEnd.a, 0.01f, 0.0f, 1.0f);

        if (ImGui::TreeNode("Advanced Gradient Editor")) {
            if (ImGui::Button("Add Color Key")) {
                ColorKey key;
                key.time = 0.5f;
                key.color = glm::vec4(1.0f);
                spawner->colorGradient.push_back(key);

                std::sort(spawner->colorGradient.begin(), spawner->colorGradient.end(),
                    [](const ColorKey& a, const ColorKey& b) { return a.time < b.time; });
            }

            bool gradientChanged = false;

            for (int i = 0; i < (int)spawner->colorGradient.size(); i++) {
                ImGui::PushID(i + 100);

                ImGui::BeginGroup();

                if (ImGui::SliderFloat("Time", &spawner->colorGradient[i].time, 0.0f, 1.0f))
                    gradientChanged = true;

                ImGui::ColorEdit3("Color", &spawner->colorGradient[i].color.r);
                ImGui::DragFloat("Alpha", &spawner->colorGradient[i].color.a, 0.01f, 0.0f, 1.0f);

                if (ImGui::Button("Remove Key", ImVec2(120, 0))) {
                    spawner->colorGradient.erase(spawner->colorGradient.begin() + i);
                    ImGui::EndGroup();
                    ImGui::PopID();
                    continue;
                }

                ImGui::EndGroup();
                ImGui::Separator();

                ImGui::PopID();
            }

            if (gradientChanged) {
                std::sort(spawner->colorGradient.begin(), spawner->colorGradient.end(),
                    [](const ColorKey& a, const ColorKey& b) { return a.time < b.time; });
            }
            ImGui::TreePop();
        }
    }

    // Noise module UI
    if (noise && ImGui::CollapsingHeader("Noise Module")) {
        ImGui::Checkbox("Enable Noise Turbulence", &noise->active);
        if (noise->active) {
            ImGui::DragFloat("Noise Strength", &noise->strength, 0.1f, 0.0f, 50.0f);
            ImGui::DragFloat("Noise Frequency", &noise->frequency, 0.01f, 0.0f, 10.0f);
        }
    }

    // Movement module UI
    if (ImGui::CollapsingHeader("Movement Module")) {
        ModuleEmitterMovement* mov = nullptr;
        for (auto m : emitter->modules)
            if (m->type == ParticleModuleType::MOVEMENT) mov = (ModuleEmitterMovement*)m;
        if (mov) ImGui::DragFloat3("Gravity Vector", &mov->gravity.x, 0.1f);
    }

    // Presets
    ImGui::Separator();
    ImGui::Text("Presets (.particle)");
    static char buf[64] = "new_effect";
    ImGui::InputText("Filename", buf, 64);

    std::string assetsRoot = FileSystem::GetAssetsRoot();
    if (assetsRoot.back() != '/' && assetsRoot.back() != '\\') assetsRoot += "/";
    std::string particleFolder = assetsRoot + "Particles/";

    if (ImGui::Button("Save Preset")) {
        std::string path = particleFolder + std::string(buf) + ".particle";
        SaveParticleFile(path);
    }
    ImGui::SameLine();
    if (ImGui::Button("Load Preset")) {
        std::string path = particleFolder + std::string(buf) + ".particle";
        LoadParticleFile(path);
    }

    // Feedback
    if (feedbackTimer > 0.0f) {
        ImGui::Separator();
        ImVec4 color = feedbackIsError ? ImVec4(1.0f, 0.3f, 0.3f, 1.0f) : ImVec4(0.3f, 1.0f, 0.3f, 1.0f);
        ImGui::TextColored(color, "%s", feedbackMessage.c_str());
    }

    ImGui::Separator();
    // Runtime status display
    ImGui::TextColored(ImVec4(0, 1, 1, 1), "Particles Alive: %d", (int)emitter->particles.size());
    ImGui::SameLine();
    if (emitter->active && !emitter->stopEmittingFlag)
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "[EMITTING]");
    else if (emitter->IsAlive())
        ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.0f, 1.0f), "[COOLING DOWN]");
    else
        ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "[STOPPED]");
#endif 
}

void ComponentParticleSystem::SetTexture(const std::string& path) {
    if (!emitter) return;

    // Release previous resource
    if (textureResourceUID != 0) {
        Application::GetInstance().resources->ReleaseResource(textureResourceUID);
        textureResourceUID = 0;
        emitter->textureID = 0;
    }
    emitter->texturePath = path;
    if (path.empty()) return;

    const auto& allResources = Application::GetInstance().resources->GetAllResources();
    for (const auto& pair : allResources) {
        Resource* res = pair.second;
        if (res->GetType() == Resource::TEXTURE && res->GetAssetFile() == path) {
            Resource* loadedRes = Application::GetInstance().resources->RequestResource(res->GetUID());
            if (loadedRes) {
                const ResourceTexture* texRes = static_cast<const ResourceTexture*>(loadedRes);
                emitter->textureID = texRes->GetGPU_ID();
                textureResourceUID = res->GetUID();
            }
            return;
        }
    }
}

// Json
void ComponentParticleSystem::Serialize(nlohmann::json& componentObj) const {
    componentObj["type"] = static_cast<int>(ComponentType::PARTICLE);
    componentObj["active"] = active;
    componentObj["maxParticles"] = emitter->maxParticles;
    componentObj["emissionRate"] = emitter->emissionRate;
    componentObj["emissionRateDist"] = emitter->emissionRateDistance;
    componentObj["simulationSpace"] = (int)emitter->simulationSpace;
    componentObj["prewarm"] = emitter->prewarm;
    componentObj["texturePath"] = emitter->texturePath;
    if (textureResourceUID != 0) componentObj["textureUID"] = textureResourceUID;
    componentObj["additive"] = emitter->additiveBlending;
    componentObj["luminance"] = emitter->luminanceBlending;
    componentObj["textureRows"] = emitter->textureRows;
    componentObj["textureCols"] = emitter->textureCols;
    componentObj["animSpeed"] = emitter->animationSpeed;
    componentObj["animLoop"] = emitter->animLoop;

    // Duration / looping / oneShot
    componentObj["looping"] = emitter->looping;
    componentObj["duration"] = emitter->duration;
    componentObj["oneShot"] = emitter->oneShot;
    componentObj["oneShotCount"] = emitter->oneShotCount;

    // Proximity activation
    componentObj["proximityActivation"] = emitter->proximityActivation;
    componentObj["activationRadius"] = emitter->activationRadius;
    componentObj["proximityTarget"] = emitter->proximityTarget;

    // Serialize Bursts
    nlohmann::json burstsJson = nlohmann::json::array();
    for (const auto& b : emitter->bursts) {
        burstsJson.push_back({
            {"time", b.time}, {"count", b.count}, {"cycles", b.cycles}, {"interval", b.repeatInterval}
            });
    }
    componentObj["bursts"] = burstsJson;

    for (auto mod : emitter->modules) {
        if (mod->type == ParticleModuleType::SPAWNER) {
            ModuleEmitterSpawn* s = static_cast<ModuleEmitterSpawn*>(mod);
            componentObj["shape"] = static_cast<int>(s->shape);
            componentObj["emissionArea"] = { s->emissionArea.x, s->emissionArea.y, s->emissionArea.z };
            componentObj["emissionRadius"] = s->emissionRadius;
            componentObj["coneRadius"] = s->coneRadius;
            componentObj["coneAngle"] = s->coneAngle;
            componentObj["circleRadius"] = s->circleRadius;
            componentObj["emitFromShell"] = s->emitFromShell;

            componentObj["colorStart"] = { s->colorStart.r, s->colorStart.g, s->colorStart.b, s->colorStart.a };
            componentObj["colorEnd"] = { s->colorEnd.r, s->colorEnd.g, s->colorEnd.b, s->colorEnd.a };

            nlohmann::json gradJson = nlohmann::json::array();
            for (const auto& k : s->colorGradient) {
                gradJson.push_back({
                    {"time", k.time},
                    {"color", {k.color.r, k.color.g, k.color.b, k.color.a}}
                    });
            }
            componentObj["colorGradient"] = gradJson;

            nlohmann::json sizeJson = nlohmann::json::array();
            for (const auto& k : s->sizeCurve)
                sizeJson.push_back({ {"time", k.time}, {"size", k.size} });
            componentObj["sizeCurve"] = sizeJson;

            componentObj["sizeStart"] = s->sizeStart;
            componentObj["sizeEnd"] = s->sizeEnd;
            componentObj["rotSpeedMin"] = s->rotationSpeedMin;
            componentObj["rotSpeedMax"] = s->rotationSpeedMax;
            componentObj["lifetimeMin"] = s->lifetimeMin;
            componentObj["lifetimeMax"] = s->lifetimeMax;
            componentObj["speedMin"] = s->speedMin;
            componentObj["speedMax"] = s->speedMax;
        }
        else if (mod->type == ParticleModuleType::MOVEMENT) {
            ModuleEmitterMovement* m = static_cast<ModuleEmitterMovement*>(mod);
            componentObj["gravity"] = { m->gravity.x, m->gravity.y, m->gravity.z };
        }
        else if (mod->type == ParticleModuleType::NOISE) {
            ModuleEmitterNoise* n = static_cast<ModuleEmitterNoise*>(mod);
            componentObj["noiseActive"] = n->active;
            componentObj["noiseStrength"] = n->strength;
            componentObj["noiseFreq"] = n->frequency;
        }
    }
}

void ComponentParticleSystem::Deserialize(const nlohmann::json& componentObj) {
    if (componentObj.contains("active")) active = componentObj["active"];
    if (componentObj.contains("maxParticles")) emitter->maxParticles = componentObj["maxParticles"];
    if (componentObj.contains("emissionRate")) emitter->emissionRate = componentObj["emissionRate"];
    if (componentObj.contains("emissionRateDist")) emitter->emissionRateDistance = componentObj["emissionRateDist"];
    if (componentObj.contains("simulationSpace")) emitter->simulationSpace = (SimulationSpace)componentObj["simulationSpace"];
    if (componentObj.contains("prewarm")) emitter->prewarm = componentObj["prewarm"];

    if (componentObj.contains("textureUID")) {
        UID uid = componentObj["textureUID"].get<UID>();
        if (uid != 0) {
            const auto& allResources = Application::GetInstance().resources->GetAllResources();
            auto it = allResources.find(uid);
            if (it != allResources.end()) SetTexture(it->second->GetAssetFile());
        }
    }
    if (emitter->textureID == 0 && componentObj.contains("texturePath"))
        SetTexture(componentObj["texturePath"]);

    if (componentObj.contains("additive")) emitter->additiveBlending = componentObj["additive"];
    if (componentObj.contains("luminance")) emitter->luminanceBlending = componentObj["luminance"];
    if (componentObj.contains("textureRows")) emitter->textureRows = componentObj["textureRows"];
    if (componentObj.contains("textureCols")) emitter->textureCols = componentObj["textureCols"];
    if (componentObj.contains("animSpeed")) emitter->animationSpeed = componentObj["animSpeed"];
    if (componentObj.contains("animLoop")) emitter->animLoop = componentObj["animLoop"];

    // Duration / looping / oneShot
    if (componentObj.contains("looping")) emitter->looping = componentObj["looping"];
    if (componentObj.contains("duration")) emitter->duration = componentObj["duration"];
    if (componentObj.contains("oneShot")) emitter->oneShot = componentObj["oneShot"];
    if (componentObj.contains("oneShotCount")) emitter->oneShotCount = componentObj["oneShotCount"];

    // Proximity activation
    if (componentObj.contains("proximityActivation"))
        emitter->proximityActivation = componentObj["proximityActivation"];
    if (componentObj.contains("activationRadius"))
        emitter->activationRadius = componentObj["activationRadius"];
    if (componentObj.contains("proximityTarget"))
        emitter->proximityTarget = componentObj["proximityTarget"].get<std::string>();

    // Deserialize Bursts
    if (componentObj.contains("bursts")) {
        emitter->bursts.clear();
        for (const auto& b : componentObj["bursts"]) {
            Burst burst;
            burst.time = b["time"]; burst.count = b["count"];
            burst.cycles = b["cycles"]; burst.repeatInterval = b["interval"];
            emitter->bursts.push_back(burst);
        }
    }

    for (auto mod : emitter->modules) {
        if (mod->type == ParticleModuleType::SPAWNER) {
            ModuleEmitterSpawn* s = static_cast<ModuleEmitterSpawn*>(mod);
            if (componentObj.contains("shape")) s->shape = static_cast<EmitterShape>(componentObj["shape"]);
            if (componentObj.contains("emissionRadius")) s->emissionRadius = componentObj["emissionRadius"];
            if (componentObj.contains("coneRadius")) s->coneRadius = componentObj["coneRadius"];
            if (componentObj.contains("coneAngle")) s->coneAngle = componentObj["coneAngle"];
            if (componentObj.contains("circleRadius")) s->circleRadius = componentObj["circleRadius"];
            if (componentObj.contains("emitFromShell")) s->emitFromShell = componentObj["emitFromShell"];

            if (componentObj.contains("colorStart")) { auto c = componentObj["colorStart"]; s->colorStart = glm::vec4(c[0], c[1], c[2], c[3]); }
            if (componentObj.contains("colorEnd")) { auto c = componentObj["colorEnd"];   s->colorEnd = glm::vec4(c[0], c[1], c[2], c[3]); }

            if (componentObj.contains("colorGradient")) {
                s->colorGradient.clear();
                for (const auto& k : componentObj["colorGradient"]) {
                    ColorKey key;
                    key.time = k["time"];
                    auto c = k["color"];
                    key.color = glm::vec4(c[0], c[1], c[2], c[3]);
                    s->colorGradient.push_back(key);
                }
            }

            if (componentObj.contains("sizeCurve")) {
                s->sizeCurve.clear();
                for (const auto& k : componentObj["sizeCurve"]) {
                    SizeKey key;
                    key.time = k["time"];
                    key.size = k["size"];
                    s->sizeCurve.push_back(key);
                }
            }

            if (componentObj.contains("sizeStart")) s->sizeStart = componentObj["sizeStart"];
            if (componentObj.contains("sizeEnd")) s->sizeEnd = componentObj["sizeEnd"];
            if (componentObj.contains("rotSpeedMin")) s->rotationSpeedMin = componentObj["rotSpeedMin"];
            if (componentObj.contains("rotSpeedMax")) s->rotationSpeedMax = componentObj["rotSpeedMax"];
            if (componentObj.contains("lifetimeMin")) s->lifetimeMin = componentObj["lifetimeMin"];
            if (componentObj.contains("lifetimeMax")) s->lifetimeMax = componentObj["lifetimeMax"];
            if (componentObj.contains("speedMin")) s->speedMin = componentObj["speedMin"];
            if (componentObj.contains("speedMax")) s->speedMax = componentObj["speedMax"];
            if (componentObj.contains("emissionArea")) {
                auto a = componentObj["emissionArea"];
                s->emissionArea = glm::vec3(a[0], a[1], a[2]);
            }
        }
        else if (mod->type == ParticleModuleType::MOVEMENT) {
            ModuleEmitterMovement* m = static_cast<ModuleEmitterMovement*>(mod);
            if (componentObj.contains("gravity")) { auto g = componentObj["gravity"]; m->gravity = glm::vec3(g[0], g[1], g[2]); }
        }
        else if (mod->type == ParticleModuleType::NOISE) {
            ModuleEmitterNoise* n = static_cast<ModuleEmitterNoise*>(mod);
            if (componentObj.contains("noiseActive")) n->active = componentObj["noiseActive"];
            if (componentObj.contains("noiseStrength")) n->strength = componentObj["noiseStrength"];
            if (componentObj.contains("noiseFreq")) n->frequency = componentObj["noiseFreq"];
        }
    }
}

void ComponentParticleSystem::SaveParticleFile(const std::string& path) {
    std::filesystem::path filepath(path);
    std::filesystem::path dir = filepath.parent_path();
    // Check directory exists
    if (!std::filesystem::exists(dir)) {
        std::filesystem::create_directories(dir);
    }

    nlohmann::json jsonFile;
    Serialize(jsonFile);
    std::ofstream file(path);
    if (file.is_open()) {
        file << std::setw(4) << jsonFile << std::endl;
        file.close();
        feedbackMessage = "Success: Saved " + filepath.filename().string();
        feedbackIsError = false;
        feedbackTimer = 3.0f;
        LOG_CONSOLE("Saved particle preset to %s", path.c_str());
    }
    else {
        feedbackMessage = "Error: Could not save file!";
        feedbackIsError = true;
        feedbackTimer = 3.0f;
        LOG_CONSOLE("ERROR: Could not save to %s", path.c_str());
    }
}

void ComponentParticleSystem::LoadParticleFile(const std::string& path) {
    std::ifstream file(path);
    if (file.is_open()) {
        nlohmann::json jsonFile;
        file >> jsonFile;
        Deserialize(jsonFile);
        file.close();
        std::filesystem::path filepath(path);
        feedbackMessage = "Success: Loaded " + filepath.filename().string();
        feedbackIsError = false;
        feedbackTimer = 3.0f;
        LOG_CONSOLE("Loaded particle preset from %s", path.c_str());
    }
    else {
        feedbackMessage = "Error: File not found!";
        feedbackIsError = true;
        feedbackTimer = 3.0f;
        LOG_CONSOLE("ERROR: Could not load %s", path.c_str());
    }
}