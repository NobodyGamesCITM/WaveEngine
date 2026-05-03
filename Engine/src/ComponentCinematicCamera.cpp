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
    bool hasTarget = CalculateWeightedTarget(focusPoint);

    if (hasTarget) {
        if (combatLockActive) {
            // Calculate the max distance between the mid point, focusPoint, to the objectives
            float maxDistFromCenter = 0.0f;
            for (auto& t : targets) {
                GameObject* obj = Application::GetInstance().scene->FindObject(t.uid);
                if (obj && obj->IsActive()) {
                    float d = glm::distance(obj->transform->GetGlobalPosition(), focusPoint);
                    if (d > maxDistFromCenter) maxDistFromCenter = d;
                }
            }

            // Offset and max distance
            glm::vec3 dirOffset = glm::normalize(combatOffset);

            // Base distance is the lenght of the original offset 
            // Add the separation of the targets multiplied by the zoom factor, 1.8f.
            float dynamicDistance = glm::length(combatOffset) + (maxDistFromCenter * 1.8f);

            // Apply position and rotation, ignore camera zones
            targetPos = focusPoint + (dirOffset * dynamicDistance);
            targetRot = glm::quat(glm::radians(combatEuler));
            targetFov = defaultFov;
            currentZone = nullptr;
        }
        else {
            EvaluateZones(focusPoint);

            // Check mode of the zone
            if (currentZone) {
                glm::vec3 basePos;
                glm::quat baseRot;
                glm::vec3 baseEuler; // save the safe angles

                if (currentZone->cameraLocationObj) {
                    basePos = currentZone->cameraLocationObj->transform->GetGlobalPosition();
                    baseRot = currentZone->cameraLocationObj->transform->GetGlobalRotationQuat();
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
                targetPos = focusPoint + defaultOffset;
                targetRot = glm::quat(glm::radians(defaultEuler));
                targetFov = defaultFov;
            }
        }
    }
    else {
        // DEFAULT no zone
        targetPos = focusPoint + defaultOffset;
        targetRot = glm::quat(glm::radians(defaultEuler));
        targetFov = defaultFov;
    }

    // Camera state machine
    if (camState == CameraState::PLAYING_CINEMATIC) {
        cinematicTimer += dt;

        // Shake
        int p1_idx = 0;
        for (size_t i = 0; i < cinematicTrack.size() - 1; ++i) {
            if (cinematicTimer >= cinematicTrack[i].time && cinematicTimer < cinematicTrack[i + 1].time) {
                p1_idx = i;
                break;
            }
        }

        if (cinematicTimer >= cinematicTrack.back().time) {
            cinematicEndPos = cinematicTrack.back().position;
            cinematicEndRot = cinematicTrack.back().rotation;
            camState = CameraState::BLENDING_BACK;
            blendBackTimer = 0.0f;
        }
        else {
            int p0_idx = std::max(0, p1_idx - 1);
            int p2_idx = p1_idx + 1;
            int p3_idx = std::min((int)cinematicTrack.size() - 1, p2_idx + 1);

            float t0 = cinematicTrack[p1_idx].time;
            float t1 = cinematicTrack[p2_idx].time;
            float localT = (cinematicTimer - t0) / (t1 - t0);

            currentPos = EvaluateCatmullRom(
                cinematicTrack[p0_idx].position, cinematicTrack[p1_idx].position,
                cinematicTrack[p2_idx].position, cinematicTrack[p3_idx].position, localT
            );

            currentRot = glm::slerp(cinematicTrack[p1_idx].rotation, cinematicTrack[p2_idx].rotation, localT);
        }
    }
    else if (camState == CameraState::BLENDING_BACK) {
        blendBackTimer += dt;
        float t = glm::clamp(blendBackTimer / blendBackDuration, 0.0f, 1.0f);

        float smoothT = t * t * (3.0f - 2.0f * t);

        currentPos = glm::mix(cinematicEndPos, targetPos, smoothT);
        currentRot = glm::slerp(cinematicEndRot, targetRot, smoothT);

        if (t >= 1.0f) {
            camState = CameraState::NORMAL;
        }
    }
    else {
        // Lerp
        ApplySmoothing(dt);
    }

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

void ComponentCinematicCamera::PlayCinematic(const std::vector<CameraKeyframe>& track, float blendBackTime) {
    if (track.empty()) return;

    cinematicTrack = track;

    std::sort(cinematicTrack.begin(), cinematicTrack.end(), [](const CameraKeyframe& a, const CameraKeyframe& b) {
        return a.time < b.time;
        });

    blendBackDuration = blendBackTime;
    cinematicTimer = 0.0f;
    camState = CameraState::PLAYING_CINEMATIC;

    LOG_CONSOLE("[CinematicCamera] Started cinematic with %d keyframes.", track.size());
}

glm::vec3 ComponentCinematicCamera::EvaluateCatmullRom(const glm::vec3& p0, const glm::vec3& p1, const glm::vec3& p2, const glm::vec3& p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;

    return 0.5f * (
        (2.0f * p1) +
        (-p0 + p2) * t +
        (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3) * t2 +
        (-p0 + 3.0f * p1 - 3.0f * p2 + p3) * t3
        );
}
