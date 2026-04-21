#include "ComponentCinematicCamera.h"
#include "ComponentCameraZone.h"
#include "ComponentCamera.h"
#include "GameObject.h"
#include "Application.h"
#include "Time.h"
#include "Transform.h"
#include "CameraLens.h"
#include "ModuleCamera.h"
#include <imgui.h>

ComponentCinematicCamera::ComponentCinematicCamera(GameObject* owner) : Component(owner, ComponentType::CINEMATIC_CAMERA) {
    currentPos = owner->transform->GetGlobalPosition();
    currentRot = owner->transform->GetGlobalRotationQuat();
    currentFov = defaultFov;
}

ComponentCinematicCamera::~ComponentCinematicCamera() {
}

void ComponentCinematicCamera::AddTarget(UID uid, float weight) {
    if (uid == 0) return;
    for (auto& t : targets) {
        if (t.uid == uid) {
            t.weight = weight;
            return;
        }
    }
    targets.push_back({ uid, weight });
}

void ComponentCinematicCamera::RemoveTarget(UID uid) {
    if (uid == 0) return;
    targets.erase(std::remove_if(targets.begin(), targets.end(),
        [uid](const CameraTarget& t) { return t.uid == uid; }), targets.end());
}

void ComponentCinematicCamera::ClearTargets() {
    targets.clear();
}

void ComponentCinematicCamera::TriggerShake(float duration, float magnitude, float frequency) {
    shakeTimer = duration;
    shakeMagnitude = magnitude;
    shakeFreq = frequency;
}

void ComponentCinematicCamera::Update() {
    float dt = Application::GetInstance().time->GetRealDeltaTime();
    if (dt <= 0.0f) return;

    glm::vec3 focusPoint(0.0f);
    if (!CalculateWeightedTarget(focusPoint)) return;

    EvaluateZones(focusPoint);

    // Check mode of the zone
    if (currentZone) {
        // Manual vs visual check
        glm::vec3 basePos;
        glm::quat baseRot;
        glm::vec3 baseEuler; // save the safe angles

        if (currentZone->cameraLocationObj) {
            basePos = currentZone->cameraLocationObj->transform->GetGlobalPosition();
            baseRot = currentZone->cameraLocationObj->transform->GetGlobalRotationQuat();
            // Obtain inspector data
            baseEuler = glm::radians(currentZone->cameraLocationObj->transform->GetRotation());
        }
        else {
            basePos = currentZone->owner->transform->GetGlobalPosition() + currentZone->cameraOffset;
            baseEuler = glm::radians(currentZone->cameraEulerAngles);
            baseRot = glm::quat(baseEuler);
        }

        // Apply mode
        if (currentZone->mode == ComponentCameraZone::CameraMode::OFFSET_TRACKING) {
            // Keep distance if follows player
            targetPos = focusPoint + (basePos - currentZone->owner->transform->GetGlobalPosition());
            targetRot = baseRot;
        }
        else if (currentZone->mode == ComponentCameraZone::CameraMode::FIXED_POS_LOOKAT) {
            // PAN with tripod
            targetPos = basePos;

            // Get only the horizontal turning, yaw
            glm::vec3 flatFocus = focusPoint;
            flatFocus.y = targetPos.y;

            if (glm::distance(targetPos, flatFocus) > 0.001f) {
                glm::mat4 lookAtMat = glm::lookAt(targetPos, flatFocus, glm::vec3(0.0f, 1.0f, 0.0f));
                glm::quat panYawOnly = glm::quat_cast(glm::inverse(lookAtMat));

                glm::quat originalTilt = glm::quat(glm::vec3(baseEuler.x, 0.0f, baseEuler.z));

                targetRot = panYawOnly * originalTilt;
            }
            else {
                targetRot = baseRot;
            }
        }
        else if (currentZone->mode == ComponentCameraZone::CameraMode::FIXED_POS_FIXED_ROT) {
            // Fixed pos and rotation
            targetPos = basePos;
            targetRot = baseRot;
        }
        targetFov = currentZone->fov;
    }
    else {
        // DEFAULT no zone
        targetPos = focusPoint + defaultOffset;
        targetRot = glm::quat(glm::radians(defaultEuler));
        targetFov = defaultFov;
    }

    // Lerp
    ApplySmoothing(dt);

    // Shake
    glm::vec3 finalPos = currentPos;
    ApplyShake(dt, finalPos);

    // Apply transform
    owner->transform->SetGlobalPosition(finalPos);
    owner->transform->SetGlobalRotationQuat(currentRot);

    // Sync lens
    ComponentCamera* camComp = (ComponentCamera*)owner->GetComponent(ComponentType::CAMERA);
    if (camComp && camComp->GetLens()) {
        camComp->GetLens()->SetFov(currentFov);
    }
}

bool ComponentCinematicCamera::CalculateWeightedTarget(glm::vec3& outPos) {
    if (targets.empty()) return false;

    glm::vec3 center(0.0f);
    float totalWeight = 0.0f;

    for (auto it = targets.begin(); it != targets.end(); ) {
        GameObject* obj = Application::GetInstance().scene->FindObject(it->uid);

        if (!obj || obj->IsMarkedForDeletion()) {
            it = targets.erase(it);
            continue;
        }

        if (!obj->IsActive()) {
            ++it;
            continue;
        }

        center += obj->transform->GetGlobalPosition() * it->weight;
        totalWeight += it->weight;
        ++it;
    }

    if (totalWeight > 0.0f) {
        outPos = center / totalWeight;
        return true;
    }
    return false;
}

void ComponentCinematicCamera::EvaluateZones(const glm::vec3& targetPos) {
    ComponentCameraZone* bestZone = nullptr;

    for (auto* zone : ComponentCameraZone::activeZones) {
        if (!zone->IsActive() || !zone->owner->IsActive()) continue;

        // Use OBB
        if (zone->Contains(targetPos)) {
            if (!bestZone || zone->priority > bestZone->priority) {
                bestZone = zone;
            }
        }
    }

    currentZone = bestZone;
}

void ComponentCinematicCamera::ApplySmoothing(float dt) {
    float t = 1.0f - glm::exp(-smoothSpeed * dt);

    currentPos = glm::mix(currentPos, targetPos, t);
    currentRot = glm::slerp(currentRot, targetRot, t);
    currentFov = glm::mix(currentFov, targetFov, t);
}

void ComponentCinematicCamera::ApplyShake(float dt, glm::vec3& outPos) {
    if (shakeTimer <= 0.0f) return;

    shakeTimer -= dt;
    float progress = shakeTimer / (shakeTimer + dt);
    float amplitude = shakeMagnitude * progress;

    float time = Application::GetInstance().time->GetTotalTime();
    float offsetX = amplitude * glm::sin(time * shakeFreq);
    float offsetZ = amplitude * glm::cos(time * shakeFreq * 1.3f);

    glm::vec3 right = currentRot * glm::vec3(1, 0, 0);
    glm::vec3 up = currentRot * glm::vec3(0, 1, 0);

    outPos += (right * offsetX) + (up * offsetZ);
}

void ComponentCinematicCamera::OnEditor() {
#ifndef WAVE_GAME
    ImGui::DragFloat3("Default Offset", &defaultOffset.x, 0.1f);
    ImGui::DragFloat3("Default Rotation", &defaultEuler.x, 1.0f);
    ImGui::DragFloat("Default FOV", &defaultFov, 0.5f, 10.0f, 120.0f);
    ImGui::DragFloat("Smooth Speed", &smoothSpeed, 0.1f, 0.1f, 20.0f);

    ImGui::Separator();
    ImGui::Text("Active Targets: %d", (int)targets.size());
    if (currentZone) {
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "Current Zone: %s", currentZone->owner->GetName().c_str());
    }
    else {
        ImGui::TextColored(ImVec4(1, 1, 0, 1), "Current Zone: NONE (Default)");
    }
#endif
}

void ComponentCinematicCamera::Serialize(nlohmann::json& obj) const {
    obj["defaultOffset"] = { defaultOffset.x, defaultOffset.y, defaultOffset.z };
    obj["defaultEuler"] = { defaultEuler.x, defaultEuler.y, defaultEuler.z };
    obj["defaultFov"] = defaultFov;
    obj["smoothSpeed"] = smoothSpeed;
}

void ComponentCinematicCamera::Deserialize(const nlohmann::json& obj) {
    if (obj.contains("defaultOffset")) { auto& o = obj["defaultOffset"]; defaultOffset = glm::vec3(o[0], o[1], o[2]); }
    if (obj.contains("defaultEuler")) { auto& e = obj["defaultEuler"]; defaultEuler = glm::vec3(e[0], e[1], e[2]); }
    defaultFov = obj.value("defaultFov", 45.0f);
    smoothSpeed = obj.value("smoothSpeed", 5.0f);
}